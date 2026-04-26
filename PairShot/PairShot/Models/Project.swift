import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var latitude: Double?
    var longitude: Double?
    var locationLabel: String?

    @Relationship(deleteRule: .cascade, inverse: \PhotoPair.project)
    var pairs: [PhotoPair] = []

    init(
        title: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationLabel: String? = nil,
        createdAt: Date = .now
    ) {
        id = UUID()
        self.title = title
        self.createdAt = createdAt
        updatedAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
    }
}
