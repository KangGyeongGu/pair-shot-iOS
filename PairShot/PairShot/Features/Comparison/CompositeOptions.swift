import Foundation
import SwiftUI

enum CompositeLayout: String, CaseIterable, Identifiable {
    case horizontal
    case vertical

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
            case .horizontal: String(localized: "좌우")
            case .vertical: String(localized: "상하")
        }
    }

    var systemImage: String {
        switch self {
            case .horizontal: "rectangle.split.2x1"
            case .vertical: "rectangle.split.1x2"
        }
    }
}

struct CompositeOptions: Equatable {
    var layout: CompositeLayout
    var jpegQuality: CGFloat
    var watermarkEnabled: Bool

    static let `default` = Self(
        layout: .horizontal,
        jpegQuality: 0.9,
        watermarkEnabled: true
    )
}
