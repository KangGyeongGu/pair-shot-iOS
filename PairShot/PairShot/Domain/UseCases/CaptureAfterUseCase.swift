import Foundation
import UniformTypeIdentifiers

@MainActor
final class CaptureAfterUseCase {
    enum CaptureAfterError: Error, Equatable {
        case pairNotFound
    }

    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService
    let tutorialPhotoStore: TutorialPhotoStore?
    let now: @Sendable () -> Date

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        tutorialPhotoStore: TutorialPhotoStore? = nil,
        now: @escaping @Sendable () -> Date = { .now },
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.tutorialPhotoStore = tutorialPhotoStore
        self.now = now
    }

    func callAsFunction(
        pairId: UUID,
        afterData: Data,
        afterUTType: UTType,
        aspectRatio: AspectRatio = .default,
        isDeferredProxy: Bool = false,
    ) async throws -> PhotoPair {
        guard var pair = try await pairRepo.fetch(id: pairId) else {
            throw CaptureAfterError.pairNotFound
        }
        let timestamp = now()
        let localIdentifier = try await saveAfterImage(
            data: afterData,
            utType: afterUTType,
            isDeferredProxy: isDeferredProxy,
            isTutorial: pair.isTutorial,
        )
        pair.afterPhotoLocalIdentifier = localIdentifier
        pair.afterCapturedAt = timestamp
        pair.updatedAt = timestamp
        if var settings = pair.cameraSettings {
            settings.aspectRatio = aspectRatio
            pair.cameraSettings = settings
        } else {
            pair.cameraSettings = CameraSettings(aspectRatio: aspectRatio)
        }
        try await pairRepo.update(pair)
        return pair
    }

    private func saveAfterImage(
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
