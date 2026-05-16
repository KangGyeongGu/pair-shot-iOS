import Foundation

struct Album: Identifiable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var latitude: Double?
    var longitude: Double?
    var locationLabel: String?
    var pairIds: [UUID]

    init(
        name: String,
        id: UUID = UUID(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationLabel: String? = nil,
        createdAt: Date = .now,
        pairIds: [UUID] = [],
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
        self.pairIds = pairIds
    }
}
