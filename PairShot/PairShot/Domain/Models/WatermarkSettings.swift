import Foundation

struct WatermarkSettings: Codable, Equatable {
    enum WatermarkType: String, Codable, CaseIterable {
        case text
        case logo
    }

    static let `default` = Self()

    static let opacityRange: ClosedRange<Double> = 0.0 ... 1.0
    static let lineCountRange: ClosedRange<Int> = 0 ... 20
    static let repeatCountRange: ClosedRange<Double> = 0.0 ... 3.0

    var isEnabled: Bool
    var type: WatermarkType
    var text: String
    var opacity: Double
    var lineCount: Int
    var repeatCount: Double

    init(
        isEnabled: Bool = false,
        type: WatermarkType = .text,
        text: String = "PairShot",
        opacity: Double = 0.5,
        lineCount: Int = 1,
        repeatCount: Double = 1.0
    ) {
        self.isEnabled = isEnabled
        self.type = type
        self.text = text
        self.opacity = opacity
        self.lineCount = lineCount
        self.repeatCount = repeatCount
    }
}
