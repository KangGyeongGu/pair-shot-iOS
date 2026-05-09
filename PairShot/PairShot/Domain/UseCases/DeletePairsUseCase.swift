import Foundation

@MainActor
final class DeletePairsUseCase {
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
        try await deleteWholePairs(ids: ids)
    }

    private func deleteWholePairs(ids: Set<UUID>) async throws {
        var assetIdsToDelete: [String] = []
        for id in ids {
            guard let pair = try await pairRepo.fetch(id: id) else { continue }
            if let beforeId = pair.beforePhotoLocalIdentifier, !beforeId.isEmpty {
                assetIdsToDelete.append(beforeId)
            }
            if let afterId = pair.afterPhotoLocalIdentifier, !afterId.isEmpty {
                assetIdsToDelete.append(afterId)
            }
        }
        let exportIds = try await pairRepo.allExportPhotoIdentifiers(forPairIds: ids)
        assetIdsToDelete.append(contentsOf: exportIds)
        try await photoLibrary.deleteAssets(localIdentifiers: assetIdsToDelete)
        try await pairRepo.delete(ids: ids)
    }
}
