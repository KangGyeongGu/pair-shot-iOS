import Foundation

nonisolated struct AppSettingsSnapshot: Equatable {
    static let defaultJpegQuality: Double = 0.95
    static let defaultOverlayAlphaValue: Double = 0.35
    static let defaultCompositeLayoutFallback: String = "horizontal"
    static let defaultWatermarkEnabled: Bool = false
    static let defaultLanguage: AppLanguage = .system
    static let defaultTheme: AppTheme = .system
    static let defaultFileNamePrefix: String = "PAIRSHOT"

    var jpegQuality: Double
    var fileNamePrefix: String
    var defaultOverlayAlpha: Double
    var defaultCompositeLayoutRawValue: String
    var watermarkEnabled: Bool
    var language: AppLanguage
    var theme: AppTheme
    var watermark: WatermarkSettings?
    var combine: CombineSettings?
}

nonisolated protocol AppSettingsRepository: Sendable {
    func load() -> AppSettingsSnapshot
    func save(_ settings: AppSettingsSnapshot) async throws
}
