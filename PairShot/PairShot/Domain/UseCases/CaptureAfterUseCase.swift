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
        afterJPEG: Data,
        jpegQuality: Double = AppSettingsSnapshot.defaultJpegQuality
    ) async throws -> PhotoPair {
        guard let pair = try await pairRepo.fetch(id: pairId) else {
            throw CaptureAfterError.pairNotFound
        }
        let timestamp = now()
        let normalized = await ExifNormalizer.normalizeAsync(afterJPEG, jpegQuality: jpegQuality)
        let localIdentifier = try await photoLibrary.saveImage(normalized)
        pair.afterPhotoLocalIdentifier = localIdentifier
        pair.afterCapturedAt = timestamp
        pair.updatedAt = timestamp
        try await pairRepo.update(pair)
        return pair
    }
}
