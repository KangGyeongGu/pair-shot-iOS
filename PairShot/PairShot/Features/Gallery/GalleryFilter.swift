import Foundation
import SwiftUI

enum GalleryFilter: String, CaseIterable, Identifiable {
    case all
    case combinedOnly

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
            case .all: String(localized: "전체")
            case .combinedOnly: String(localized: "합성본")
        }
    }

    var systemImage: String {
        switch self {
            case .all: "square.grid.2x2"
            case .combinedOnly: "rectangle.on.rectangle"
        }
    }

    func apply(to pairs: [PhotoPair]) -> [PhotoPair] {
        switch self {
            case .all:
                pairs

            case .combinedOnly:
                pairs.filter { pair in
                    guard let combined = pair.combinedFileName else { return false }
                    return !combined.isEmpty
                }
        }
    }
}
