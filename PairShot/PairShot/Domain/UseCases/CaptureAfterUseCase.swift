import Foundation

@MainActor
final class CaptureAfterUseCase {
    enum CaptureAfterError: Error, Equatable {
        case pairNotFound
    }

    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService
    let now: @Sendable () -> Date

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.now = now
    }

    func callAsFunction(
        pairId: UUID,
        afterJPEG: Data
    ) async throws -> PhotoPair {
        guard var pair = try await pairRepo.fetch(id: pairId) else {
            throw CaptureAfterError.pairNotFound
        }
        let timestamp = now()
        let localIdentifier = try await photoLibrary.saveImage(afterJPEG)
        pair.afterPhotoLocalIdentifier = localIdentifier
        pair.afterCapturedAt = timestamp
        pair.updatedAt = timestamp
        try await pairRepo.update(pair)
        return pair
    }
}
