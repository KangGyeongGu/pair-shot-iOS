import Foundation
import SwiftData

@MainActor
final class DeleteCombinedExportsUseCase {
    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService
    let modelContainer: ModelContainer

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        modelContainer: ModelContainer
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.modelContainer = modelContainer
    }

    func callAsFunction(ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        var pairs: [PhotoPair] = []
        var assetIdsToDelete: [String] = []
        for id in ids {
            guard let pair = try await pairRepo.fetch(id: id) else { continue }
            pairs.append(pair)
            for record in pair.exportHistory where record.kind == .combined {
                if !record.photoLocalIdentifier.isEmpty {
                    assetIdsToDelete.append(record.photoLocalIdentifier)
                }
            }
        }
        guard !assetIdsToDelete.isEmpty else { return }
        try await photoLibrary.deleteAssets(localIdentifiers: assetIdsToDelete)
        let context = modelContainer.mainContext
        for pair in pairs {
            let combinedRecords = pair.exportHistory.filter { $0.kind == .combined }
            for record in combinedRecords {
                context.delete(record)
            }
        }
        try context.save()
    }

    deinit {}
}
