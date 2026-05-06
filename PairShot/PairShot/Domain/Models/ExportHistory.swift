import Foundation

enum ExportHistoryKind: String, Codable, Equatable {
    case combined = "COMBINED"
    case watermarkedBefore = "WATERMARKED_BEFORE"
    case watermarkedAfter = "WATERMARKED_AFTER"
}

struct ExportHistory: Identifiable, Equatable {
    var id: UUID
    var kindRaw: String
    var photoLocalIdentifier: String
    var createdAt: Date
    var pairId: UUID?

    var kind: ExportHistoryKind {
        ExportHistoryKind(rawValue: kindRaw) ?? .combined
    }

    init(
        id: UUID = UUID(),
        kind: ExportHistoryKind,
        photoLocalIdentifier: String,
        createdAt: Date = .now,
        pairId: UUID? = nil
    ) {
        self.id = id
        kindRaw = kind.rawValue
        self.photoLocalIdentifier = photoLocalIdentifier
        self.createdAt = createdAt
        self.pairId = pairId
    }
}

@MainActor
enum ExportHistoryKindResolver {
    static func resolve(
        entryKind: ExportPhotoKind,
        renderOptions: ExportRenderOptions,
        appSettings: AppSettings?
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

    private static func isWatermarkActive(
        renderOptions: ExportRenderOptions,
        appSettings: AppSettings?
    ) -> Bool {
        guard renderOptions.applyWatermark else { return false }
        guard let appSettings else { return false }
        return appSettings.watermarkEnabled
    }
}
