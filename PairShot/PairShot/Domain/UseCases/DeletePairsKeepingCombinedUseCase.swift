import Foundation

@MainActor
final class DeletePairsKeepingCombinedUseCase {
    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
    }

    func callAsFunction(ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        var originalIds: [String] = []
        for id in ids {
            guard let pair = try await pairRepo.fetch(id: id) else { continue }
            if let beforeId = pair.beforePhotoLocalIdentifier, !beforeId.isEmpty {
                originalIds.append(beforeId)
            }
            if let afterId = pair.afterPhotoLocalIdentifier, !afterId.isEmpty {
                originalIds.append(afterId)
            }
        }
        try await photoLibrary.deleteAssets(localIdentifiers: originalIds)
        try await pairRepo.delete(ids: ids)
    }
}
