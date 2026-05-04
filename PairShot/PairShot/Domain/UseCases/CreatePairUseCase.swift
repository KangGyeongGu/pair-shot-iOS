import Foundation

@MainActor
final class CreatePairUseCase {
    enum RefillError: Error, Equatable {
        case pairNotFound
    }

    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService
    let location: CoreLocationService
    let now: @Sendable () -> Date

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        location: CoreLocationService,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.location = location
        self.now = now
    }

    func callAsFunction(
        beforeJPEG: Data,
        cameraSettings: CameraSettings,
        jpegQuality: Double = AppSettingsSnapshot.defaultJpegQuality
    ) async throws -> PhotoPair {
        let timestamp = now()
        let pairId = UUID()
        let normalized = await ExifNormalizer.normalizeAsync(beforeJPEG, jpegQuality: jpegQuality)
        let localIdentifier = try await photoLibrary.saveImage(normalized)
        let resolvedLocation = await location.fetchOnce()
        let pair = PhotoPair(
            id: pairId,
            beforePhotoLocalIdentifier: localIdentifier,
            beforeZoomFactor: cameraSettings.zoomFactor,
            beforeLensIdentifier: cameraSettings.lensPosition.rawValue,
            createdAt: timestamp,
            latitude: resolvedLocation?.latitude,
            longitude: resolvedLocation?.longitude,
            locationLabel: nil,
            cameraSettings: cameraSettings
        )
        try await pairRepo.add(pair)
        return pair
    }

    func refillBefore(
        pairId: UUID,
        beforeJPEG: Data,
        cameraSettings: CameraSettings,
        jpegQuality: Double = AppSettingsSnapshot.defaultJpegQuality
    ) async throws -> PhotoPair {
        guard var pair = try await pairRepo.fetch(id: pairId) else {
            throw RefillError.pairNotFound
        }
        let timestamp = now()
        let normalized = await ExifNormalizer.normalizeAsync(beforeJPEG, jpegQuality: jpegQuality)
        let localIdentifier = try await photoLibrary.saveImage(normalized)
        pair.beforePhotoLocalIdentifier = localIdentifier
        pair.beforeZoomFactor = cameraSettings.zoomFactor
        pair.beforeLensIdentifier = cameraSettings.lensPosition.rawValue
        pair.cameraSettings = cameraSettings
        pair.updatedAt = timestamp
        try await pairRepo.update(pair)
        return pair
    }
}
