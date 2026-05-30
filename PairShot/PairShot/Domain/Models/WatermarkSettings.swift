import Foundation

extension CodingUserInfoKey {
    nonisolated static let watermarkLogoStore: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "pairshot.watermarkLogoStore") else {
            preconditionFailure("CodingUserInfoKey rawValue init must not fail for static literal")
        }
        return key
    }()
}

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

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case opacity
        case lineCount
        case repeatCount
        case textSizeRatio
        case logoImageData
        case logoImageRef
        case logoFileName
        case logoPosition
        case logoWidthRatio
        case logoAlpha
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
    var logoImageRef: String?
    var logoFileName: String?
    var logoPosition: LogoPosition
    var logoWidthRatio: Double
    var logoAlpha: Double
    var pendingLegacyLogoData: Data?

    var isBlank: Bool {
        switch type {
            case .text:
                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            case .logo:
                logoImageRef == nil && pendingLegacyLogoData == nil
        }
    }

    init(
        type: WatermarkType = .text,
        text: String = "",
        opacity: Double = 0.5,
        lineCount: Int = 10,
        repeatCount: Double = 1.5,
        textSizeRatio: Double = 0.03,
        logoImageRef: String? = nil,
        logoFileName: String? = nil,
        logoPosition: LogoPosition = .center,
        logoWidthRatio: Double = 0.5,
        logoAlpha: Double = 0.5,
    ) {
        self.type = type
        self.text = text
        self.opacity = opacity
        self.lineCount = lineCount
        self.repeatCount = repeatCount
        self.textSizeRatio = textSizeRatio
        self.logoImageRef = logoImageRef
        self.logoFileName = logoFileName
        self.logoPosition = logoPosition
        self.logoWidthRatio = logoWidthRatio
        self.logoAlpha = logoAlpha
        pendingLegacyLogoData = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(WatermarkType.self, forKey: .type) ?? .text
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.5
        lineCount = try container.decodeIfPresent(Int.self, forKey: .lineCount) ?? 10
        repeatCount = try container.decodeIfPresent(Double.self, forKey: .repeatCount) ?? 1.5
        textSizeRatio = try container.decodeIfPresent(Double.self, forKey: .textSizeRatio) ?? 0.03
        logoFileName = try container.decodeIfPresent(String.self, forKey: .logoFileName)
        logoPosition = try container.decodeIfPresent(LogoPosition.self, forKey: .logoPosition) ?? .center
        logoWidthRatio = try container.decodeIfPresent(Double.self, forKey: .logoWidthRatio) ?? 0.5
        logoAlpha = try container.decodeIfPresent(Double.self, forKey: .logoAlpha) ?? 0.5

        if let ref = try container.decodeIfPresent(String.self, forKey: .logoImageRef) {
            logoImageRef = ref
            pendingLegacyLogoData = nil
        } else if let legacyData = try container.decodeIfPresent(Data.self, forKey: .logoImageData) {
            if let store = decoder.userInfo[.watermarkLogoStore] as? WatermarkLogoStore,
               let migratedRef = try? store.save(legacyData)
            {
                logoImageRef = migratedRef
                pendingLegacyLogoData = nil
            } else {
                logoImageRef = nil
                pendingLegacyLogoData = legacyData
            }
        } else {
            logoImageRef = nil
            pendingLegacyLogoData = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(text, forKey: .text)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(lineCount, forKey: .lineCount)
        try container.encode(repeatCount, forKey: .repeatCount)
        try container.encode(textSizeRatio, forKey: .textSizeRatio)
        try container.encodeIfPresent(logoImageRef, forKey: .logoImageRef)
        try container.encodeIfPresent(logoFileName, forKey: .logoFileName)
        try container.encode(logoPosition, forKey: .logoPosition)
        try container.encode(logoWidthRatio, forKey: .logoWidthRatio)
        try container.encode(logoAlpha, forKey: .logoAlpha)
        if logoImageRef == nil, let pending = pendingLegacyLogoData {
            try container.encode(pending, forKey: .logoImageData)
        }
    }

    func effective(isPro: Bool) -> Self {
        guard !isPro, type == .logo else { return self }
        var copy = self
        copy.type = .text
        return copy
    }

    func loadLogoData(using store: WatermarkLogoStore) -> Data? {
        if let ref = logoImageRef, let data = store.load(ref: ref) {
            return data
        }
        return pendingLegacyLogoData
    }
}
