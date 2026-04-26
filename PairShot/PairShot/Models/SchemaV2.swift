import Foundation
import SwiftData

enum SchemaV2: VersionedSchema {
    static let versionIdentifier: Schema.Version = .init(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Album.self, PhotoPair.self, Coupon.self]
    }
}
