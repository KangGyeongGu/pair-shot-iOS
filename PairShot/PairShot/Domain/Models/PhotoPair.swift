import Foundation
import SwiftData

@Model
final class PhotoPair {
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

    @Attribute(.externalStorage) var cameraSettingsData: Data?

    var albums: [Album] = []

    @Relationship(deleteRule: .cascade, inverse: \ExportHistory.pair)
    var exportHistory: [ExportHistory] = []

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
        beforePhotoLocalIdentifier: String? = nil,
        beforeZoomFactor: Double = 1.0,
        beforeLensIdentifier: String = "",
        cameraSettings: CameraSettings? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationLabel: String? = nil,
        capturedAt: Date = .now
    ) {
        id = UUID()
        self.beforePhotoLocalIdentifier = beforePhotoLocalIdentifier
        self.beforeZoomFactor = beforeZoomFactor
        self.beforeLensIdentifier = beforeLensIdentifier
        createdAt = capturedAt
        updatedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
        if let cameraSettings {
            cameraSettingsData = try? JSONEncoder().encode(cameraSettings)
        }
    }
}
