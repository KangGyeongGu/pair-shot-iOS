import Foundation

struct AppSettingsSnapshot: Equatable {
    static let defaultJpegQuality: Double = 0.8
    static let defaultOverlayAlphaValue: Double = 0.5
    static let defaultCompositeLayoutFallback: String = "horizontal"
    static let defaultWatermarkEnabled: Bool = true
    static let defaultLanguage: AppLanguage = .system
    static let defaultTheme: AppTheme = .system

    static let `default` = Self(
        jpegQuality: Self.defaultJpegQuality,
        fileNamePrefix: "",
        defaultOverlayAlpha: Self.defaultOverlayAlphaValue,
        defaultCompositeLayoutRawValue: Self.defaultCompositeLayoutFallback,
        watermarkEnabled: Self.defaultWatermarkEnabled,
        language: Self.defaultLanguage,
        theme: Self.defaultTheme,
        watermark: nil,
        combine: nil
    )

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

protocol AppSettingsRepository: Sendable {
    func load() -> AppSettingsSnapshot
    func save(_ settings: AppSettingsSnapshot) async throws
    func observe() -> AsyncStream<AppSettingsSnapshot>
}
