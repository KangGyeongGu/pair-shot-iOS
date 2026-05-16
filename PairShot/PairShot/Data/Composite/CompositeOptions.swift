import Foundation
import SwiftUI

nonisolated enum CompositeLayout: String, CaseIterable, Identifiable {
    case horizontal
    case vertical

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
            case .horizontal: String(localized: "combine_direction_horizontal")
            case .vertical: String(localized: "combine_direction_vertical")
        }
    }

    var systemImage: String {
        switch self {
            case .horizontal: "rectangle.split.2x1"
            case .vertical: "rectangle.split.1x2"
        }
    }
}

nonisolated struct CompositeOptions: Equatable {
    static let `default` = Self(
        layout: .horizontal,
        jpegQuality: 0.9,
        watermarkEnabled: false,
        watermark: nil,
        combineSettings: nil,
        includeGPS: true,
    )

    var layout: CompositeLayout
    var jpegQuality: CGFloat
    var watermarkEnabled: Bool
    var watermark: WatermarkSettings?
    var combineSettings: CombineSettings?
    var includeGPS: Bool
}
