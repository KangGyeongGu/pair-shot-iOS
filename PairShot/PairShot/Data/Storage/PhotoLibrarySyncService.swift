import Foundation
import Photos
@preconcurrency import SwiftData

final nonisolated class PhotoLibrarySyncService: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    nonisolated func photoLibraryDidChange(_: PHChange) {
        Task { @MainActor [weak self] in
            self?.reconcile()
        }
    }

    @MainActor
    func reconcile() {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return }
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<PhotoPairEntity>(predicate: #Predicate { !$0.isTutorial })
        guard let pairs = try? context.fetch(descriptor), !pairs.isEmpty else { return }

        let localIds = pairs.flatMap { [$0.beforePhotoLocalIdentifier, $0.afterPhotoLocalIdentifier] }
            .compactMap(\.self)
        guard !localIds.isEmpty else { return }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: localIds, options: nil)
        var existing = Set<String>()
        result.enumerateObjects { asset, _, _ in existing.insert(asset.localIdentifier) }

        var changed = false
        for pair in pairs {
            if let id = pair.beforePhotoLocalIdentifier, !existing.contains(id) {
                pair.beforePhotoLocalIdentifier = nil
                changed = true
            }
            if let id = pair.afterPhotoLocalIdentifier, !existing.contains(id) {
                pair.afterPhotoLocalIdentifier = nil
                changed = true
            }
            if pair.beforePhotoLocalIdentifier == nil, pair.afterPhotoLocalIdentifier == nil {
                context.delete(pair)
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}
