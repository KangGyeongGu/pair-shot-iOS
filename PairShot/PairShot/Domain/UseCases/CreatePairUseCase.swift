import Foundation

struct CreatePairUseCase {
    let pairRepo: PhotoPairRepository
    let storage: PhotoStoring
    let location: LocationFetching
    let fileNameBuilder: FileNameBuilding
    let exifNormalizer: ExifNormalizing
    let now: @Sendable () -> Date

    init(
        pairRepo: PhotoPairRepository,
        storage: PhotoStoring,
        location: LocationFetching,
        fileNameBuilder: FileNameBuilding,
        exifNormalizer: ExifNormalizing,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.pairRepo = pairRepo
        self.storage = storage
        self.location = location
        self.fileNameBuilder = fileNameBuilder
        self.exifNormalizer = exifNormalizer
        self.now = now
    }

    func callAsFunction(
        beforeJPEG: Data,
        prefix: String,
        cameraSettings: CameraSettings,
        jpegQuality: Double = AppSettingsSnapshot.defaultJpegQuality
    ) async throws -> PhotoPair {
        let timestamp = now()
        let pairId = UUID()
        let fileName = fileNameBuilder.before(prefix: prefix, timestamp: timestamp, pairId: pairId)
        let normalized = await exifNormalizer.normalize(beforeJPEG, jpegQuality: jpegQuality)
        let savedName = try storage.saveBeforeJPEG(normalized, fileName: fileName)
        let resolvedLocation = await location.fetchOnce()
        let pair = PhotoPair(
            beforeFileName: savedName,
            cameraSettings: cameraSettings,
            latitude: resolvedLocation?.latitude,
            longitude: resolvedLocation?.longitude,
            locationLabel: nil,
            capturedAt: timestamp
        )
        pair.id = pairId
        try await pairRepo.add(pair)
        return pair
    }
}
