import Foundation
import SwiftData
import SwiftUI
import UIKit

/// P4.1 — 2-column grid of `PhotoPair` thumbnails for a single `Project`.
///
/// - 2 columns via `LazyVGrid` (the Android v1.1.3 layout).
/// - Cell shows the **Before** image (per spec: "Before 우선") with a small
///   badge in the corner indicating status (pending / complete / composited).
/// - Tap → comparison modal placeholder (P5 will replace this with the real
///   `ComparisonView`). The placeholder still conforms to the `.sheet(item:)`
///   pattern so swapping it later is a one-line change.
/// - Long-press → enter multi-select mode (P4.3).
/// - Top filter (P4.2) toggles ALL / 합성본.
/// - Bottom multi-select bar (P4.3) appears via `safeAreaInset` while a
///   selection is active.
/// - Thumbnails are decoded once via `ThumbnailCache` (P4.4), so re-mounting
///   a cell during fast scroll is a memory hit, not a JPEG re-decode.
struct PairGalleryView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var filter: GalleryFilter = .all
    @State private var selection = PairSelection()
    @State private var preview: PhotoPair?

    private let storage: PhotoStorageService

    init(project: Project, storage: PhotoStorageService = PhotoStorageService()) {
        self.project = project
        self.storage = storage
    }

    private var filteredPairs: [PhotoPair] {
        let sorted = project.pairs.sorted(by: { $0.beforeCapturedAt > $1.beforeCapturedAt })
        return filter.apply(to: sorted)
    }

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        ScrollView {
            filterPicker
                .padding(.horizontal)
                .padding(.top, 8)
                .disabled(selection.isSelectionMode)

            if filteredPairs.isEmpty {
                emptyState
                    .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(filteredPairs) { pair in
                        PairThumbnailCell(
                            pair: pair,
                            storage: storage,
                            isSelectionMode: selection.isSelectionMode,
                            isSelected: selection.contains(pair.id)
                        )
                        .contentShape(.rect)
                        .onTapGesture { handleTap(pair) }
                        .onLongPressGesture(minimumDuration: 0.4) { handleLongPress(pair) }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(project.title.isEmpty ? String(localized: "(이름 없음)") : project.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if selection.isSelectionMode {
                PairMultiSelectBar(
                    selection: selection,
                    onComposite: { /* P5.2 */ },
                    onShare: { /* P7.3 */ },
                    onDelete: deleteSelected
                )
            }
        }
        .fullScreenCover(item: $preview) { pair in
            ComparisonView(
                pairs: filteredPairs,
                startIndex: filteredPairs.firstIndex(where: { $0.id == pair.id }) ?? 0,
                storage: storage
            )
        }
    }

    private var filterPicker: some View {
        Picker("", selection: $filter) {
            ForEach(GalleryFilter.allCases) { option in
                Label(option.label, systemImage: option.systemImage)
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            filter == .all ? String(localized: "사진 없음") : String(localized: "합성본 없음"),
            systemImage: filter == .all ? "photo.on.rectangle" : "rectangle.on.rectangle",
            description: Text(filter == .all
                ? String(localized: "Before 카메라에서 첫 페어를 만드세요")
                : String(localized: "비교 화면에서 합성을 만들 수 있습니다")
            )
        )
    }

    private func handleTap(_ pair: PhotoPair) {
        if selection.isSelectionMode {
            selection.toggle(pair.id)
        } else {
            preview = pair
        }
    }

    private func handleLongPress(_ pair: PhotoPair) {
        if !selection.isSelectionMode {
            selection.enterSelection(with: pair.id)
        }
    }

    private func deleteSelected() {
        let ids = selection.selectedIds
        guard !ids.isEmpty else { return }
        _ = try? PairDeletionService.deletePairs(ids: ids, in: modelContext, storage: storage)
        selection.exit()
    }
}

/// One grid cell. Stays small (<60 lines) so the parent view can remain
/// declarative.
private struct PairThumbnailCell: View {
    let pair: PhotoPair
    let storage: PhotoStorageService
    let isSelectionMode: Bool
    let isSelected: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailLayer
                .aspectRatio(1, contentMode: .fit)
                .clipped()
                .background(Color.gray.opacity(0.15))

            statusBadge
                .padding(6)

            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .white)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 3
                )
        )
        .task(id: pair.beforePath) {
            await loadThumbnail()
        }
    }

    @ViewBuilder
    private var thumbnailLayer: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else {
            // Placeholder while decode is in flight, or when the file is gone.
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .padding(24)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch pair.status {
            case .pendingAfter:
                badgeText(String(localized: "Before"), tint: .orange)
            case .complete:
                if let combined = pair.combinedPath, !combined.isEmpty {
                    badgeText(String(localized: "합성"), tint: .purple)
                } else {
                    badgeText(String(localized: "완료"), tint: .green)
                }
        }
    }

    private func badgeText(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
    }

    private func loadThumbnail() async {
        // Cheap synchronous cache hit on the main actor.
        if let cached = ThumbnailCache.shared.cached(forRelativePath: pair.beforePath) {
            thumbnail = cached
            return
        }
        // Off-main decode to keep scroll smooth.
        let path = pair.beforePath
        let storage = storage
        let decoded = await Task.detached(priority: .userInitiated) {
            ThumbnailCache.shared.loadThumbnail(forRelativePath: path, storage: storage)
        }.value
        thumbnail = decoded
    }
}

#Preview {
    NavigationStack {
        PairGalleryView(project: Project(title: "프리뷰"))
    }
    .modelContainer(for: [Project.self, PhotoPair.self], inMemory: true)
}
