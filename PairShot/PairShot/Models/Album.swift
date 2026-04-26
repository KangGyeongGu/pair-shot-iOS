import Foundation
import SwiftData

@Model
final class Album {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var latitude: Double?
    var longitude: Double?
    var locationLabel: String?

    @Relationship(deleteRule: .nullify, inverse: \PhotoPair.albums)
    var pairs: [PhotoPair] = []

    init(
        name: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationLabel: String? = nil,
        createdAt: Date = .now
    ) {
        id = UUID()
        self.name = name
        self.createdAt = createdAt
        updatedAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
    }
}
