import Foundation

@MainActor
final class DeleteCombinedExportsUseCase {
    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
    }

    func callAsFunction(ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        let assetIdsToDelete = try await pairRepo.combinedExportPhotoIdentifiers(forPairIds: ids)
        guard !assetIdsToDelete.isEmpty else { return }
        try await photoLibrary.deleteAssets(localIdentifiers: assetIdsToDelete)
        try await pairRepo.deleteCombinedExportRecords(forPairIds: ids)
    }
}
