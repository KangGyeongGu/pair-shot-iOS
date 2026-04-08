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
    var depthAtCenter: Double?
    var relativeAltitude: Double?
    var referenceImagePath: String?
    var focalLength: Double?
    var zoomFactor: Double?

    var arIntrinsicsData: Data?
    var depthMapPath: String?
    var arRelocalized: Bool = false

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
        arTransformData: Data? = nil,
        depthAtCenter: Double? = nil,
        relativeAltitude: Double? = nil,
        referenceImagePath: String? = nil,
        focalLength: Double? = nil,
        zoomFactor: Double? = nil,
        arIntrinsicsData: Data? = nil,
        depthMapPath: String? = nil,
        arRelocalized: Bool = false
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
        self.depthAtCenter = depthAtCenter
        self.relativeAltitude = relativeAltitude
        self.referenceImagePath = referenceImagePath
        self.focalLength = focalLength
        self.zoomFactor = zoomFactor
        self.arIntrinsicsData = arIntrinsicsData
        self.depthMapPath = depthMapPath
        self.arRelocalized = arRelocalized
    }
}
