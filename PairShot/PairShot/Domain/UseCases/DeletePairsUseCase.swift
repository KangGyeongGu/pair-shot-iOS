import Foundation

@MainActor
final class DeletePairsUseCase {
    enum Mode: Equatable {
        case wholePair
        case combinedOnly
    }

    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
    }

    func callAsFunction(ids: Set<UUID>, mode: Mode) async throws {
        guard !ids.isEmpty else { return }
        switch mode {
            case .wholePair:
                try await deleteWholePairs(ids: ids)

            case .combinedOnly:
                break
        }
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
            for record in pair.exportHistory where !record.photoLocalIdentifier.isEmpty {
                assetIdsToDelete.append(record.photoLocalIdentifier)
            }
        }
        try? await photoLibrary.deleteAssets(localIdentifiers: assetIdsToDelete)
        try await pairRepo.delete(ids: ids)
    }
}
