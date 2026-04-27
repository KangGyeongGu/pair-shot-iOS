import Foundation
import SwiftData

enum SchemaV3: VersionedSchema {
    static let versionIdentifier: Schema.Version = .init(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Album.self, PhotoPair.self, Coupon.self]
    }
}
