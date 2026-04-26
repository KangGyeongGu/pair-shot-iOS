import Foundation

struct CaptureAfterUseCase {
    enum CaptureAfterError: Error, Equatable {
        case pairNotFound
    }

    let pairRepo: PhotoPairRepository
    let storage: PhotoStoring
    let fileNameBuilder: FileNameBuilding
    let exifNormalizer: ExifNormalizing
    let now: @Sendable () -> Date

    init(
        pairRepo: PhotoPairRepository,
        storage: PhotoStoring,
        fileNameBuilder: FileNameBuilding,
        exifNormalizer: ExifNormalizing,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.pairRepo = pairRepo
        self.storage = storage
        self.fileNameBuilder = fileNameBuilder
        self.exifNormalizer = exifNormalizer
        self.now = now
    }

    func callAsFunction(
        pairId: UUID,
        afterJPEG: Data,
        prefix: String,
        jpegQuality: Double = AppSettingsSnapshot.defaultJpegQuality
    ) async throws -> PhotoPair {
        guard let pair = try await pairRepo.fetch(id: pairId) else {
            throw CaptureAfterError.pairNotFound
        }
        let timestamp = now()
        let fileName = fileNameBuilder.after(prefix: prefix, timestamp: timestamp, pairId: pairId)
        let normalized = await exifNormalizer.normalize(afterJPEG, jpegQuality: jpegQuality)
        let savedName = try storage.saveAfterJPEG(normalized, fileName: fileName)
        pair.afterFileName = savedName
        pair.afterCapturedAt = timestamp
        pair.updatedAt = timestamp
        try await pairRepo.update(pair)
        return pair
    }
}
