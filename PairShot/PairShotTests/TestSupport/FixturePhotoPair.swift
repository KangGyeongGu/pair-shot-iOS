import Foundation
@testable import PairShot

@MainActor
enum FixturePhotoPair {
    static func make(
        id: UUID = UUID(),
        beforePhotoLocalIdentifier: String? = "before-fixture",
        afterPhotoLocalIdentifier: String? = "after-fixture",
        beforeZoomFactor: Double = 1.0,
        beforeLensIdentifier: String = "",
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        afterCapturedAt: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationLabel: String? = nil,
        cameraSettings: CameraSettings? = nil,
        albumIds: [UUID] = [],
        hasCombinedExport: Bool = false,
        isTutorial: Bool = false,
    ) -> PhotoPair {
        PhotoPair(
            id: id,
            beforePhotoLocalIdentifier: beforePhotoLocalIdentifier,
            afterPhotoLocalIdentifier: afterPhotoLocalIdentifier,
            beforeZoomFactor: beforeZoomFactor,
            beforeLensIdentifier: beforeLensIdentifier,
            createdAt: createdAt,
            updatedAt: updatedAt,
            afterCapturedAt: afterCapturedAt,
            latitude: latitude,
            longitude: longitude,
            locationLabel: locationLabel,
            cameraSettings: cameraSettings,
            albumIds: albumIds,
            hasCombinedExport: hasCombinedExport,
            isTutorial: isTutorial,
        )
    }

    static func makeBeforeOnly(
        id: UUID = UUID(),
        beforePhotoLocalIdentifier: String? = "before-fixture",
        albumIds: [UUID] = [],
        isTutorial: Bool = false,
    ) -> PhotoPair {
        make(
            id: id,
            beforePhotoLocalIdentifier: beforePhotoLocalIdentifier,
            afterPhotoLocalIdentifier: nil,
            albumIds: albumIds,
            isTutorial: isTutorial,
        )
    }
}
