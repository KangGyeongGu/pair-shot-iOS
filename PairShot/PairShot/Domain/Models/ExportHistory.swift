import Foundation

enum ExportHistoryKind: String, Codable, Equatable {
    case combined = "COMBINED"
    case watermarkedBefore = "WATERMARKED_BEFORE"
    case watermarkedAfter = "WATERMARKED_AFTER"
}

nonisolated enum ExportHistoryKindResolver {
    @MainActor
    static func resolve(
        entryKind: ExportPhotoKind,
        renderOptions: ExportRenderOptions,
        appSettings: AppSettings
    ) -> ExportHistoryKind? {
        switch entryKind {
            case .combined:
                return .combined

            case .before:
                guard isWatermarkActive(renderOptions: renderOptions, appSettings: appSettings) else {
                    return nil
                }
                return .watermarkedBefore

            case .after:
                guard isWatermarkActive(renderOptions: renderOptions, appSettings: appSettings) else {
                    return nil
                }
                return .watermarkedAfter
        }
    }

    @MainActor
    private static func isWatermarkActive(
        renderOptions: ExportRenderOptions,
        appSettings: AppSettings
    ) -> Bool {
        guard renderOptions.applyWatermark else { return false }
        return appSettings.watermarkEnabled
    }
}
