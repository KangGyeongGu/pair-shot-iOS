import Foundation

@MainActor
final class CaptureAfterUseCase {
    enum CaptureAfterError: Error, Equatable {
        case pairNotFound
    }

    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService
    let exifNormalizer: ExifNormalizing
    let now: @Sendable () -> Date

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        exifNormalizer: ExifNormalizing,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.exifNormalizer = exifNormalizer
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
        let normalized = await exifNormalizer.normalize(afterJPEG, jpegQuality: jpegQuality)
        let localIdentifier = try await photoLibrary.saveImage(normalized)
        pair.afterPhotoLocalIdentifier = localIdentifier
        pair.afterCapturedAt = timestamp
        pair.updatedAt = timestamp
        try await pairRepo.update(pair)
        return pair
    }
}
