import Foundation
import SwiftData

@Model
final class PhotoPairEntity {
    @Attribute(.unique) var id: UUID
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
    var isTutorial: Bool = false

    @Attribute(.externalStorage) var cameraSettingsData: Data?

    var albums: [AlbumEntity] = []

    @Relationship(deleteRule: .cascade, inverse: \ExportHistoryEntity.pair)
    var exportHistory: [ExportHistoryEntity] = []

    var cameraSettings: CameraSettings? {
        get {
            guard let cameraSettingsData else { return nil }
            return try? JSONDecoder().decode(CameraSettings.self, from: cameraSettingsData)
        }
        set {
            guard let newValue else {
                cameraSettingsData = nil
                return
            }
            cameraSettingsData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: UUID = UUID(),
        beforePhotoLocalIdentifier: String? = nil,
        afterPhotoLocalIdentifier: String? = nil,
        beforeZoomFactor: Double = 1.0,
        beforeLensIdentifier: String = "",
        cameraSettings: CameraSettings? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationLabel: String? = nil,
        capturedAt: Date = .now,
        updatedAt: Date? = nil,
        afterCapturedAt: Date? = nil,
        isTutorial: Bool = false,
    ) {
        self.id = id
        self.beforePhotoLocalIdentifier = beforePhotoLocalIdentifier
        self.afterPhotoLocalIdentifier = afterPhotoLocalIdentifier
        self.beforeZoomFactor = beforeZoomFactor
        self.beforeLensIdentifier = beforeLensIdentifier
        createdAt = capturedAt
        self.updatedAt = updatedAt ?? capturedAt
        self.afterCapturedAt = afterCapturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
        self.isTutorial = isTutorial
        if let cameraSettings {
            cameraSettingsData = try? JSONEncoder().encode(cameraSettings)
        }
    }
}

extension PhotoPairEntity {
    @MainActor
    func toDomain() -> PhotoPair {
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
            albumIds: albums.map(\.id),
            firstAlbumName: albums.first?.name,
            hasCombinedExport: exportHistory.contains { $0.kind == .combined },
            isTutorial: isTutorial,
        )
    }
}
