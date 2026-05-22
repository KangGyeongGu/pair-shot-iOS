import Foundation

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

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, min(1, value))
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
            color: ColorRGBA = .white,
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
            textColor: ColorRGBA = .black,
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

    nonisolated enum LabelPlacement: String, Codable, CaseIterable {
        case image = "IMAGE"
        case border = "BORDER"
    }

    nonisolated struct BorderLabelPosition: Codable, Equatable {
        nonisolated enum Vertical: String, Codable, CaseIterable {
            case top
            case bottom
        }

        var horizontal: LabelPosition.Horizontal
        var vertical: Vertical

        init(
            horizontal: LabelPosition.Horizontal = .leading,
            vertical: Vertical = .bottom,
        ) {
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
            opacity: Double = 1.0,
            cornerRadius: Double = 25.0,
            matchBorderColor: Bool = true,
        ) {
            self.isEnabled = isEnabled
            self.color = color
            self.opacity = opacity
            self.cornerRadius = cornerRadius
            self.matchBorderColor = matchBorderColor
        }
    }

    enum CodingKeys: String, CodingKey {
        case direction
        case border
        case label
        case labelMode
        case beforePosition
        case afterPosition
        case fullWidthVertical
        case labelBackground
        case labelPlacement
        case beforeBorderPosition
        case afterBorderPosition
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
    var labelPlacement: LabelPlacement
    var beforeBorderPosition: BorderLabelPosition
    var afterBorderPosition: BorderLabelPosition

    init(
        direction: Direction = .horizontal,
        border: Border = .default,
        label: Label = .default,
        labelMode: LabelMode = .free,
        beforePosition: LabelPosition = LabelPosition(horizontal: .leading, vertical: .top),
        afterPosition: LabelPosition = LabelPosition(horizontal: .leading, vertical: .top),
        fullWidthVertical: LabelPosition.Vertical = .bottom,
        labelBackground: LabelBackground = .default,
        labelPlacement: LabelPlacement = .image,
        beforeBorderPosition: BorderLabelPosition = BorderLabelPosition(horizontal: .leading, vertical: .bottom),
        afterBorderPosition: BorderLabelPosition = BorderLabelPosition(horizontal: .trailing, vertical: .bottom),
    ) {
        self.direction = direction
        self.border = border
        self.label = label
        self.labelMode = labelMode
        self.beforePosition = beforePosition
        self.afterPosition = afterPosition
        self.fullWidthVertical = fullWidthVertical
        self.labelBackground = labelBackground
        self.labelPlacement = labelPlacement
        self.beforeBorderPosition = beforeBorderPosition
        self.afterBorderPosition = afterBorderPosition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        direction = try container.decode(Direction.self, forKey: .direction)
        border = try container.decode(Border.self, forKey: .border)
        label = try container.decode(Label.self, forKey: .label)
        labelMode = try container.decode(LabelMode.self, forKey: .labelMode)
        beforePosition = try container.decode(LabelPosition.self, forKey: .beforePosition)
        afterPosition = try container.decode(LabelPosition.self, forKey: .afterPosition)
        fullWidthVertical = try container.decode(LabelPosition.Vertical.self, forKey: .fullWidthVertical)
        labelBackground = try container.decode(LabelBackground.self, forKey: .labelBackground)
        labelPlacement = try container.decodeIfPresent(LabelPlacement.self, forKey: .labelPlacement) ?? .image
        beforeBorderPosition = try container.decodeIfPresent(
            BorderLabelPosition.self,
            forKey: .beforeBorderPosition,
        ) ?? BorderLabelPosition(horizontal: .leading, vertical: .bottom)
        afterBorderPosition = try container.decodeIfPresent(
            BorderLabelPosition.self,
            forKey: .afterBorderPosition,
        ) ?? BorderLabelPosition(horizontal: .trailing, vertical: .bottom)
    }

    func effective(isPro: Bool) -> Self {
        guard !isPro, label.isEnabled else { return self }
        var copy = self
        copy.label.isEnabled = false
        return copy
    }
}
