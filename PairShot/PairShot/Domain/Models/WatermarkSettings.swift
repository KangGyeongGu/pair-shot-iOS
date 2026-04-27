import Foundation

nonisolated enum LogoPosition: String, Codable, CaseIterable {
    case topLeft
    case topCenter
    case topRight
    case centerLeft
    case center
    case centerRight
    case bottomLeft
    case bottomCenter
    case bottomRight
}

nonisolated struct WatermarkSettings: Codable, Equatable {
    nonisolated enum WatermarkType: String, Codable, CaseIterable {
        case text
        case logo
    }

    static let `default` = Self()

    static let opacityRange: ClosedRange<Double> = 0.0 ... 1.0
    static let lineCountRange: ClosedRange<Int> = 0 ... 20
    static let repeatCountRange: ClosedRange<Double> = 0.0 ... 3.0
    static let logoWidthRatioRange: ClosedRange<Double> = 0.1 ... 0.9
    static let textSizeRatioRange: ClosedRange<Double> = 0.02 ... 0.06
    static let logoAlphaRange: ClosedRange<Double> = 0.0 ... 1.0

    var type: WatermarkType
    var text: String
    var opacity: Double
    var lineCount: Int
    var repeatCount: Double
    var textSizeRatio: Double
    var logoImageData: Data?
    var logoPosition: LogoPosition
    var logoWidthRatio: Double
    var logoAlpha: Double

    init(
        type: WatermarkType = .text,
        text: String = "",
        opacity: Double = 0.5,
        lineCount: Int = 10,
        repeatCount: Double = 1.5,
        textSizeRatio: Double = 0.03,
        logoImageData: Data? = nil,
        logoPosition: LogoPosition = .center,
        logoWidthRatio: Double = 0.5,
        logoAlpha: Double = 0.5
    ) {
        self.type = type
        self.text = text
        self.opacity = opacity
        self.lineCount = lineCount
        self.repeatCount = repeatCount
        self.textSizeRatio = textSizeRatio
        self.logoImageData = logoImageData
        self.logoPosition = logoPosition
        self.logoWidthRatio = logoWidthRatio
        self.logoAlpha = logoAlpha
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case opacity
        case lineCount
        case repeatCount
        case textSizeRatio
        case logoImageData
        case logoPosition
        case logoWidthRatio
        case logoAlpha
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(WatermarkType.self, forKey: .type) ?? .text
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.5
        lineCount = try container.decodeIfPresent(Int.self, forKey: .lineCount) ?? 10
        repeatCount = try container.decodeIfPresent(Double.self, forKey: .repeatCount) ?? 1.5
        textSizeRatio = try container.decodeIfPresent(Double.self, forKey: .textSizeRatio) ?? 0.03
        logoImageData = try container.decodeIfPresent(Data.self, forKey: .logoImageData)
        logoPosition = try container.decodeIfPresent(LogoPosition.self, forKey: .logoPosition) ?? .center
        logoWidthRatio = try container.decodeIfPresent(Double.self, forKey: .logoWidthRatio) ?? 0.5
        logoAlpha = try container.decodeIfPresent(Double.self, forKey: .logoAlpha) ?? 0.5
    }
}
