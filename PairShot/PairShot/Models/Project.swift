import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var title: String
    var createdAt: Date
    var latitude: Double?
    var longitude: Double?

    @Relationship(deleteRule: .cascade, inverse: \PhotoPair.project)
    var pairs: [PhotoPair]

    var completePairCount: Int {
        pairs.count(where: { $0.status == .complete })
    }

    var totalPairCount: Int {
        pairs.count
    }

    var coverThumbnailPath: String? {
        pairs
            .min { $0.createdAt < $1.createdAt }?
            .beforePhoto?
            .thumbnailPath
    }

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        pairs = []
    }
}
