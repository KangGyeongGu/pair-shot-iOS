import Foundation
import UniformTypeIdentifiers

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
        now: @escaping @Sendable () -> Date = { .now },
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.location = location
        self.now = now
    }

    func callAsFunction(
        beforeData: Data,
        beforeUTType: UTType,
        cameraSettings: CameraSettings,
        aspectRatio: AspectRatio = .default,
        isDeferredProxy: Bool = false,
    ) async throws -> PhotoPair {
        let timestamp = now()
        let pairId = UUID()
        let localIdentifier = try await photoLibrary.saveImage(
            beforeData,
            utType: beforeUTType,
            isDeferredProxy: isDeferredProxy,
        )
        let resolvedLocation = location.currentLocation
        var settings = cameraSettings
        settings.aspectRatio = aspectRatio
        let pair = PhotoPair(
            id: pairId,
            beforePhotoLocalIdentifier: localIdentifier,
            beforeZoomFactor: settings.zoomFactor,
            beforeLensIdentifier: settings.lensPosition.rawValue,
            createdAt: timestamp,
            latitude: resolvedLocation?.latitude,
            longitude: resolvedLocation?.longitude,
            locationLabel: nil,
            cameraSettings: settings,
        )
        try await pairRepo.add(pair)
        return pair
    }

    func refillBefore(
        pairId: UUID,
        beforeData: Data,
        beforeUTType: UTType,
        cameraSettings: CameraSettings,
        aspectRatio: AspectRatio = .default,
        isDeferredProxy: Bool = false,
    ) async throws -> PhotoPair {
        guard var pair = try await pairRepo.fetch(id: pairId) else {
            throw RefillError.pairNotFound
        }
        let timestamp = now()
        let localIdentifier = try await photoLibrary.saveImage(
            beforeData,
            utType: beforeUTType,
            isDeferredProxy: isDeferredProxy,
        )
        var settings = cameraSettings
        settings.aspectRatio = aspectRatio
        pair.beforePhotoLocalIdentifier = localIdentifier
        pair.beforeZoomFactor = settings.zoomFactor
        pair.beforeLensIdentifier = settings.lensPosition.rawValue
        pair.cameraSettings = settings
        pair.updatedAt = timestamp
        try await pairRepo.update(pair)
        return pair
    }
}
