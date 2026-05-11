import Foundation
import SwiftData

@Model
final class ExportHistoryEntity {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var photoLocalIdentifier: String
    var createdAt: Date
    var pair: PhotoPairEntity?

    var kind: ExportHistoryKind {
        ExportHistoryKind(rawValue: kindRaw) ?? .combined
    }

    init(
        kind: ExportHistoryKind,
        photoLocalIdentifier: String,
        id: UUID = UUID(),
        createdAt: Date = .now,
        pair: PhotoPairEntity? = nil
    ) {
        self.id = id
        kindRaw = kind.rawValue
        self.photoLocalIdentifier = photoLocalIdentifier
        self.createdAt = createdAt
        self.pair = pair
    }
}
