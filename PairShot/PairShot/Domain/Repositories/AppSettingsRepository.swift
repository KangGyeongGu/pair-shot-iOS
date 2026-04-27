import Foundation

nonisolated struct AppSettingsSnapshot: Equatable {
    static let defaultJpegQuality: Double = 0.95
    static let defaultOverlayAlphaValue: Double = 0.35
    static let defaultCompositeLayoutFallback: String = "horizontal"
    static let defaultWatermarkEnabled: Bool = false
    static let defaultLanguage: AppLanguage = .system
    static let defaultTheme: AppTheme = .system
    static let defaultFileNamePrefix: String = "PAIRSHOT"

    static let `default` = Self(
        jpegQuality: Self.defaultJpegQuality,
        fileNamePrefix: Self.defaultFileNamePrefix,
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

nonisolated protocol AppSettingsRepository: Sendable {
    func load() -> AppSettingsSnapshot
    func save(_ settings: AppSettingsSnapshot) async throws
    func observe() -> AsyncStream<AppSettingsSnapshot>
}
