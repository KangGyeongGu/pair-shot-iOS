import Foundation
import SwiftData
import SwiftUI
import UIKit

/// One slot in the gallery grid — either a real `PhotoPair` or a
/// native-ad token vended by `NativeAdLoader`. Pulled out of the view so
/// `NativeAdInsertionStrategy` can build the slot list as a pure
/// transform unit-testable on its own.
enum GalleryItem: Identifiable {
    case pair(PhotoPair)
    case nativeAd(id: Int, ad: Any?)

    var id: AnyHashable {
        switch self {
            case let .pair(pair): pair.id
            case let .nativeAd(slotID, _): "ad-\(slotID)"
        }
    }
}

/// P4.1 — 2-column grid of `PhotoPair` thumbnails for a single `Project`.
///
/// Per phase plan:
/// - 2 columns via `LazyVGrid` (Android v1.1.3 layout).
/// - Cell shows the **Before** image with a corner status badge.
/// - Tap → comparison modal (`ComparisonView` since P5.1).
/// - Long-press → multi-select mode (P4.3).
/// - Top filter (P4.2) toggles ALL / 합성본.
/// - Bottom multi-select bar (P4.3) appears via `safeAreaInset`.
/// - Thumbnails are decoded once via `ThumbnailCache` (P4.4).
///
/// P6.8: a native-ad cell is inserted every 6 pairs unless AdFree is
/// active. Selection mode hides ad cells so the user isn't forced to
/// scroll past them while picking pairs.
struct PairGalleryView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @Environment(AdFreeStore.self) private var adFreeStore
    @Environment(NativeAdLoader.self) private var nativeAdLoader
    @State private var filter: GalleryFilter = .all
    @State private var selection = PairSelection()
    @State private var preview: PhotoPair?
    @State private var exportPayload: ExportPickerPayload?

    private let storage: PhotoStorageService

    init(project: Project, storage: PhotoStorageService = PhotoStorageService()) {
        self.project = project
        self.storage = storage
    }

    private var filteredPairs: [PhotoPair] {
        let sorted = project.pairs.sorted(by: { $0.beforeCapturedAt > $1.beforeCapturedAt })
        return filter.apply(to: sorted)
    }

    /// Build the rendered slot list. Selection mode and AdFree both
    /// suppress the ad cells — the rest is the filtered pair list.
    private var galleryItems: [GalleryItem] {
        let pairs = filteredPairs
        let suppressAds = adFreeStore.isAdFree || selection.isSelectionMode
        guard !suppressAds else {
            return pairs.map(GalleryItem.pair)
        }
        let adIndices = Set(NativeAdInsertionStrategy.indices(forPairCount: pairs.count))
        var items: [GalleryItem] = []
        items.reserveCapacity(pairs.count + adIndices.count)
        for (offset, pair) in pairs.enumerated() {
            items.append(.pair(pair))
            if adIndices.contains(offset) {
                items.append(.nativeAd(id: offset, ad: nativeAdLoader.adFor(index: offset)))
            }
        }
        return items
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
                grid
            }
        }
        .navigationTitle(project.title.isEmpty ? String(localized: "(이름 없음)") : project.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if selection.isSelectionMode {
                PairMultiSelectBar(
                    selection: selection,
                    onComposite: { /* multi-pair composite TBD */ },
                    onShare: presentExportPicker,
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
        .sheet(item: $exportPayload) { payload in
            ExportPicker(pairs: payload.pairs, storage: storage)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(galleryItems) { item in
                cell(for: item)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func cell(for item: GalleryItem) -> some View {
        switch item {
            case let .pair(pair):
                PairThumbnailCell(
                    pair: pair,
                    storage: storage,
                    isSelectionMode: selection.isSelectionMode,
                    isSelected: selection.contains(pair.id)
                )
                .contentShape(.rect)
                .onTapGesture { handleTap(pair) }
                .onLongPressGesture(minimumDuration: 0.4) { handleLongPress(pair) }
            case let .nativeAd(_, ad):
                NativeAdCell(ad: ad)
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

    private func presentExportPicker() {
        let ids = selection.selectedIds
        guard !ids.isEmpty else { return }
        let selected = filteredPairs.filter { ids.contains($0.id) }
        guard !selected.isEmpty else { return }
        exportPayload = ExportPickerPayload(pairs: selected)
    }
}

private struct PairGalleryViewPreviewWrapper: View {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Project.self,
        PhotoPair.self,
        Coupon.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        NavigationStack {
            PairGalleryView(project: Project(title: "프리뷰"))
        }
        .modelContainer(container)
        .environment(AdFreeStore(context: container.mainContext))
        .environment(\.fullscreenAdCoordinator, FullscreenAdCoordinator())
        .environment(InterstitialAdManager())
        .environment(NativeAdLoader())
    }
}

#Preview {
    PairGalleryViewPreviewWrapper()
}
