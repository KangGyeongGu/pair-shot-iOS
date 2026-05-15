import Foundation
import SwiftData

@Model
final class AlbumEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var latitude: Double?
    var longitude: Double?
    var locationLabel: String?

    @Relationship(deleteRule: .nullify, inverse: \PhotoPairEntity.albums)
    var pairs: [PhotoPairEntity] = []

    init(
        name: String,
        id: UUID = UUID(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationLabel: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        updatedAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
    }
}

extension AlbumEntity {
    @MainActor
    func toDomain() -> Album {
        Album(
            name: name,
            id: id,
            latitude: latitude,
            longitude: longitude,
            locationLabel: locationLabel,
            createdAt: createdAt,
            pairIds: pairs.map(\.id)
        )
    }
}
