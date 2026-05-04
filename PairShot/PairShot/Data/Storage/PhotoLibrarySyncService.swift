import Foundation
import Photos
@preconcurrency import SwiftData

@MainActor
final class PhotoLibrarySyncService: NSObject, PHPhotoLibraryChangeObserver {
    private let container: ModelContainer
    private let photoLibrary: PhotoLibraryService

    init(container: ModelContainer, photoLibrary: PhotoLibraryService) {
        self.container = container
        self.photoLibrary = photoLibrary
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    nonisolated func photoLibraryDidChange(_: PHChange) {
        Task { @MainActor [weak self] in
            await self?.reconcile()
        }
    }

    func reconcile() async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PhotoPair>()
        guard let pairs = try? context.fetch(descriptor) else { return }
        var didChange = false
        for pair in pairs {
            if let beforeId = pair.beforePhotoLocalIdentifier,
               photoLibrary.fetchAsset(localIdentifier: beforeId) == nil
            {
                pair.beforePhotoLocalIdentifier = nil
                didChange = true
            }
            if let afterId = pair.afterPhotoLocalIdentifier,
               photoLibrary.fetchAsset(localIdentifier: afterId) == nil
            {
                pair.afterPhotoLocalIdentifier = nil
                didChange = true
            }
            if pair.beforePhotoLocalIdentifier == nil, pair.afterPhotoLocalIdentifier == nil {
                context.delete(pair)
                didChange = true
            }
        }
        if didChange {
            try? context.save()
        }
    }
}
