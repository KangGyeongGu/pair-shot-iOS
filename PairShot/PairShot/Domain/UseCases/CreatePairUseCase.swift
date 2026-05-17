import Foundation
import UniformTypeIdentifiers

@MainActor
final class CreatePairUseCase {
    enum RefillError: Error, Equatable {
        case pairNotFound
    }

    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService
    let tutorialPhotoStore: TutorialPhotoStore?
    let location: CoreLocationService
    let now: @Sendable () -> Date

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        location: CoreLocationService,
        tutorialPhotoStore: TutorialPhotoStore? = nil,
        now: @escaping @Sendable () -> Date = { .now },
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.tutorialPhotoStore = tutorialPhotoStore
        self.location = location
        self.now = now
    }

    func callAsFunction(
        beforeData: Data,
        beforeUTType: UTType,
        cameraSettings: CameraSettings,
        aspectRatio: AspectRatio = .default,
        isDeferredProxy: Bool = false,
        isTutorial: Bool = false,
    ) async throws -> PhotoPair {
        let timestamp = now()
        let pairId = UUID()
        let localIdentifier = try await saveBeforeImage(
            data: beforeData,
            utType: beforeUTType,
            isDeferredProxy: isDeferredProxy,
            isTutorial: isTutorial,
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
            isTutorial: isTutorial,
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
        let localIdentifier = try await saveBeforeImage(
            data: beforeData,
            utType: beforeUTType,
            isDeferredProxy: isDeferredProxy,
            isTutorial: pair.isTutorial,
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

    private func saveBeforeImage(
        data: Data,
        utType: UTType,
        isDeferredProxy: Bool,
        isTutorial: Bool,
    ) async throws -> String {
        if isTutorial, let tutorialPhotoStore {
            return try await tutorialPhotoStore.save(data: data, utType: utType)
        }
        return try await photoLibrary.saveImage(
            data,
            utType: utType,
            isDeferredProxy: isDeferredProxy,
        )
    }
}
