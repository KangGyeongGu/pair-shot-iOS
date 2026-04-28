import Foundation

@MainActor
final class DeleteCombinedExportsUseCase {
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
        var assetIdsToDelete: [String] = []
        for id in ids {
            guard let pair = try await pairRepo.fetch(id: id) else { continue }
            for record in pair.exportHistory where record.kind == .combined {
                if !record.photoLocalIdentifier.isEmpty {
                    assetIdsToDelete.append(record.photoLocalIdentifier)
                }
            }
        }
        guard !assetIdsToDelete.isEmpty else { return }
        try await photoLibrary.deleteAssets(localIdentifiers: assetIdsToDelete)
        try await pairRepo.deleteCombinedExportRecords(forPairIds: ids)
    }

    deinit {}
}
