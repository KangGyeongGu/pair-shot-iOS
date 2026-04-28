import Foundation
import SwiftUI
import UIKit

nonisolated struct ColorRGBA: Codable, Equatable {
    static let white = Self(red: 1, green: 1, blue: 1)
    static let black = Self(red: 0, green: 0, blue: 0)

    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    init(color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                alpha: Double(alpha)
            )
        } else {
            var white: CGFloat = 0
            var whiteAlpha: CGFloat = 0
            if uiColor.getWhite(&white, alpha: &whiteAlpha) {
                self.init(
                    red: Double(white),
                    green: Double(white),
                    blue: Double(white),
                    alpha: Double(whiteAlpha)
                )
            } else {
                self.init(red: 0, green: 0, blue: 0, alpha: 1.0)
            }
        }
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, min(1, value))
    }
}

extension Color {
    init(rgba: ColorRGBA) {
        self.init(
            .sRGB,
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
    }
}

extension UIColor {
    nonisolated convenience init(rgba: ColorRGBA) {
        self.init(
            red: CGFloat(rgba.red),
            green: CGFloat(rgba.green),
            blue: CGFloat(rgba.blue),
            alpha: CGFloat(rgba.alpha)
        )
    }
}

nonisolated struct CombineSettings: Codable, Equatable {
    nonisolated enum Direction: String, Codable, CaseIterable {
        case horizontal
        case vertical
    }

    nonisolated enum LabelMode: String, Codable, CaseIterable {
        case fullWidth = "FULL_WIDTH"
        case free = "FREE"
    }

    nonisolated struct Border: Codable, Equatable {
        static let `default` = Self()

        var isEnabled: Bool
        var thickness: Double
        var color: ColorRGBA

        init(
            isEnabled: Bool = true,
            thickness: Double = 16.0,
            color: ColorRGBA = .white
        ) {
            self.isEnabled = isEnabled
            self.thickness = thickness
            self.color = color
        }
    }

    nonisolated struct Label: Codable, Equatable {
        static let `default` = Self()

        var isEnabled: Bool
        var beforeText: String
        var afterText: String
        var textSizePercent: Double
        var textColor: ColorRGBA

        init(
            isEnabled: Bool = false,
            beforeText: String = "BEFORE",
            afterText: String = "AFTER",
            textSizePercent: Double = 5.0,
            textColor: ColorRGBA = .black
        ) {
            self.isEnabled = isEnabled
            self.beforeText = beforeText
            self.afterText = afterText
            self.textSizePercent = textSizePercent
            self.textColor = textColor
        }
    }

    nonisolated struct LabelPosition: Codable, Equatable {
        nonisolated enum Horizontal: String, Codable, CaseIterable {
            case leading
            case center
            case trailing
        }

        nonisolated enum Vertical: String, Codable, CaseIterable {
            case top
            case middle
            case bottom
        }

        var horizontal: Horizontal
        var vertical: Vertical

        init(horizontal: Horizontal = .center, vertical: Vertical = .top) {
            self.horizontal = horizontal
            self.vertical = vertical
        }
    }

    nonisolated struct LabelBackground: Codable, Equatable {
        static let `default` = Self()

        var isEnabled: Bool
        var color: ColorRGBA
        var opacity: Double
        var cornerRadius: Double
        var matchBorderColor: Bool

        init(
            isEnabled: Bool = true,
            color: ColorRGBA = .black,
            opacity: Double = 0.5,
            cornerRadius: Double = 25.0,
            matchBorderColor: Bool = true
        ) {
            self.isEnabled = isEnabled
            self.color = color
            self.opacity = opacity
            self.cornerRadius = cornerRadius
            self.matchBorderColor = matchBorderColor
        }
    }

    static let `default` = Self()

    static let borderThicknessRange: ClosedRange<Double> = 0.0 ... 32.0
    static let labelTextSizeRange: ClosedRange<Double> = 0.0 ... 10.0
    static let labelBackgroundOpacityRange: ClosedRange<Double> = 0.0 ... 1.0
    static let labelBackgroundCornerRadiusRange: ClosedRange<Double> = 0.0 ... 50.0

    var direction: Direction
    var border: Border
    var label: Label
    var labelMode: LabelMode
    var beforePosition: LabelPosition
    var afterPosition: LabelPosition
    var fullWidthVertical: LabelPosition.Vertical
    var labelBackground: LabelBackground

    init(
        direction: Direction = .horizontal,
        border: Border = .default,
        label: Label = .default,
        labelMode: LabelMode = .free,
        beforePosition: LabelPosition = LabelPosition(horizontal: .leading, vertical: .top),
        afterPosition: LabelPosition = LabelPosition(horizontal: .leading, vertical: .top),
        fullWidthVertical: LabelPosition.Vertical = .bottom,
        labelBackground: LabelBackground = .default
    ) {
        self.direction = direction
        self.border = border
        self.label = label
        self.labelMode = labelMode
        self.beforePosition = beforePosition
        self.afterPosition = afterPosition
        self.fullWidthVertical = fullWidthVertical
        self.labelBackground = labelBackground
    }
}
