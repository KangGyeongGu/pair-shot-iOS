import Foundation
import SwiftData
import SwiftUI
import UIKit

struct PairGalleryView: View {
    let albumId: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(AdFreeStore.self) private var adFreeStore
    @Environment(NativeAdLoader.self) private var nativeAdLoader
    @Query(sort: \PhotoPair.createdAt, order: .reverse) private var allPairs: [PhotoPair]
    @State private var filter: GalleryFilter = .all
    @State private var selection = PairSelection()
    @State private var preview: PhotoPair?
    @State private var exportPayload: ExportPickerPayload?
    @State private var showBeforeCamera: Bool = false
    @State private var showAfterCamera: Bool = false

    private let storage: PhotoStorageService

    init(albumId: UUID? = nil, storage: PhotoStorageService = PhotoStorageService()) {
        self.albumId = albumId
        self.storage = storage
    }

    private var scopedPairs: [PhotoPair] {
        guard let albumId else { return allPairs }
        return allPairs.filter { pair in
            pair.albums.contains(where: { $0.id == albumId })
        }
    }

    private var filteredPairs: [PhotoPair] {
        filter.apply(to: scopedPairs)
    }

    private var galleryItems: [GalleryItem] {
        GalleryItemBuilder.build(
            pairs: filteredPairs,
            suppressAds: adFreeStore.isAdFree || selection.isSelectionMode,
            adProvider: nativeAdLoader.adFor(index:)
        )
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
        .navigationTitle(String(localized: "페어"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            PairGalleryToolbar(
                isSelectionMode: selection.isSelectionMode,
                onBeforeCamera: { showBeforeCamera = true }
            )
        }
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
        .pairGalleryCameraCovers(
            albumId: albumId,
            showBeforeCamera: $showBeforeCamera,
            showAfterCamera: $showAfterCamera
        )
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
        } else if pair.afterFileName == nil {
            showAfterCamera = true
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
        for: Schema(versionedSchema: SchemaV2.self),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        NavigationStack {
            PairGalleryView()
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
