import Foundation
import SwiftData

@Model
final class Photo {
    var id: UUID
    var filePath: String
    var thumbnailPath: String
    var timestamp: Date

    var latitude: Double?
    var longitude: Double?
    var altitude: Double?

    var heading: Double?
    var pitch: Double?
    var roll: Double?
    var yaw: Double?

    var notes: String?

    var worldMapPath: String?
    var arTransformData: Data?

    init(
        id: UUID = UUID(),
        filePath: String,
        thumbnailPath: String,
        timestamp: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        heading: Double? = nil,
        pitch: Double? = nil,
        roll: Double? = nil,
        yaw: Double? = nil,
        notes: String? = nil,
        worldMapPath: String? = nil,
        arTransformData: Data? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.heading = heading
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.notes = notes
        self.worldMapPath = worldMapPath
        self.arTransformData = arTransformData
    }
}
