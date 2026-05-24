nonisolated struct AppSettingsSnapshot: Equatable {
    static let defaultExportQualityRawValue: String = "lossless"
    static let defaultCompositeLayoutFallback: String = "horizontal"
    static let defaultLanguage: AppLanguage = .system
    static let defaultTheme: AppTheme = .system

    var exportQualityRawValue: String
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
