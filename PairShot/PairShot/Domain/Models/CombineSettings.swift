import Foundation
import SwiftUI
import UIKit

struct ColorRGBA: Codable, Equatable {
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

struct CombineSettings: Codable, Equatable {
    enum Direction: String, Codable, CaseIterable {
        case horizontal
        case vertical
    }

    enum LabelMode: String, Codable, CaseIterable {
        case fullWidth = "full_width"
        case free
    }

    struct Border: Codable, Equatable {
        static let `default` = Self()

        var isEnabled: Bool
        var thickness: Double
        var color: ColorRGBA

        init(
            isEnabled: Bool = false,
            thickness: Double = 4.0,
            color: ColorRGBA = .black
        ) {
            self.isEnabled = isEnabled
            self.thickness = thickness
            self.color = color
        }
    }

    struct Label: Codable, Equatable {
        static let `default` = Self()

        var isEnabled: Bool
        var beforeText: String
        var afterText: String
        var textSizePercent: Double
        var textColor: ColorRGBA

        init(
            isEnabled: Bool = true,
            beforeText: String = "BEFORE",
            afterText: String = "AFTER",
            textSizePercent: Double = 4.0,
            textColor: ColorRGBA = .white
        ) {
            self.isEnabled = isEnabled
            self.beforeText = beforeText
            self.afterText = afterText
            self.textSizePercent = textSizePercent
            self.textColor = textColor
        }
    }

    struct LabelPosition: Codable, Equatable {
        enum Horizontal: String, Codable, CaseIterable {
            case leading
            case center
            case trailing
        }

        enum Vertical: String, Codable, CaseIterable {
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

    struct LabelBackground: Codable, Equatable {
        static let `default` = Self()

        var isEnabled: Bool
        var color: ColorRGBA
        var opacity: Double
        var cornerRadius: Double
        var matchBorderColor: Bool

        init(
            isEnabled: Bool = false,
            color: ColorRGBA = .black,
            opacity: Double = 0.6,
            cornerRadius: Double = 8.0,
            matchBorderColor: Bool = false
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
        labelMode: LabelMode = .fullWidth,
        beforePosition: LabelPosition = LabelPosition(horizontal: .leading, vertical: .top),
        afterPosition: LabelPosition = LabelPosition(horizontal: .trailing, vertical: .top),
        fullWidthVertical: LabelPosition.Vertical = .top,
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
