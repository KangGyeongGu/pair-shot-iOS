import Foundation
import SwiftData

@Model
final class ExportHistoryEntity {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var photoLocalIdentifier: String
    var createdAt: Date
    var pair: PhotoPair?

    var kind: ExportHistoryKind {
        ExportHistoryKind(rawValue: kindRaw) ?? .combined
    }

    init(
        id: UUID = UUID(),
        kind: ExportHistoryKind,
        photoLocalIdentifier: String,
        createdAt: Date = .now,
        pair: PhotoPair? = nil
    ) {
        self.id = id
        kindRaw = kind.rawValue
        self.photoLocalIdentifier = photoLocalIdentifier
        self.createdAt = createdAt
        self.pair = pair
    }
}
