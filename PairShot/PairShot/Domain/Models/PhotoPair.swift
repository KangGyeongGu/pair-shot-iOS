import Foundation

struct PhotoPair: Identifiable, Equatable {
    var id: UUID
    var beforePhotoLocalIdentifier: String?
    var afterPhotoLocalIdentifier: String?
    var beforeZoomFactor: Double
    var beforeLensIdentifier: String
    var createdAt: Date
    var updatedAt: Date
    var afterCapturedAt: Date?
    var latitude: Double?
    var longitude: Double?
    var locationLabel: String?
    var cameraSettings: CameraSettings?
    var albumIds: [UUID]
    var firstAlbumName: String?
    var hasCombinedExport: Bool
    var isTutorial: Bool

    init(
        id: UUID = UUID(),
        beforePhotoLocalIdentifier: String? = nil,
        afterPhotoLocalIdentifier: String? = nil,
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
        firstAlbumName: String? = nil,
        hasCombinedExport: Bool = false,
        isTutorial: Bool = false,
    ) {
        self.id = id
        self.beforePhotoLocalIdentifier = beforePhotoLocalIdentifier
        self.afterPhotoLocalIdentifier = afterPhotoLocalIdentifier
        self.beforeZoomFactor = beforeZoomFactor
        self.beforeLensIdentifier = beforeLensIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.afterCapturedAt = afterCapturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
        self.cameraSettings = cameraSettings
        self.albumIds = albumIds
        self.firstAlbumName = firstAlbumName
        self.hasCombinedExport = hasCombinedExport
        self.isTutorial = isTutorial
    }
}
