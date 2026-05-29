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

        if let afterId = pair.afterPhotoLocalIdentifier, !afterId.isEmpty {
            try await photoLibrary.deleteAssets(localIdentifiers: [afterId])
        }

        pair.afterPhotoLocalIdentifier = nil
        pair.afterCapturedAt = nil
        try await pairRepo.update(pair)
        return pair
    }
}
