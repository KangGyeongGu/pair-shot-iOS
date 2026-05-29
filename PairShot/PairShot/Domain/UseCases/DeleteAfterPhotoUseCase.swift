import Foundation

@MainActor
final class DeleteAfterPhotoUseCase {
    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
    }

    func callAsFunction(pairId: UUID) async throws -> PhotoPair? {
        guard var pair = try await pairRepo.fetch(id: pairId) else { return nil }

        var assetIdsToDelete: [String] = []
        if let afterId = pair.afterPhotoLocalIdentifier, !afterId.isEmpty {
            assetIdsToDelete.append(afterId)
        }
        let combinedIds = try await pairRepo.combinedExportPhotoIdentifiers(forPairIds: [pairId])
        assetIdsToDelete.append(contentsOf: combinedIds)

        if !assetIdsToDelete.isEmpty {
            try await photoLibrary.deleteAssets(localIdentifiers: assetIdsToDelete)
        }
        try await pairRepo.deleteCombinedExportRecords(forPairIds: [pairId])

        pair.afterPhotoLocalIdentifier = nil
        pair.afterCapturedAt = nil
        pair.hasCombinedExport = false
        try await pairRepo.update(pair)
        return pair
    }
}
