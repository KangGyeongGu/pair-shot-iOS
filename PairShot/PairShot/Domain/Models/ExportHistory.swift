import Foundation
import SwiftData

enum ExportHistoryKind: String, Codable, Equatable {
    case combined = "COMBINED"
    case watermarkedBefore = "WATERMARKED_BEFORE"
    case watermarkedAfter = "WATERMARKED_AFTER"
}

@Model
final class ExportHistory {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var photoLocalIdentifier: String
    var createdAt: Date
    var pair: PhotoPair?

    var kind: ExportHistoryKind {
        ExportHistoryKind(rawValue: kindRaw) ?? .combined
    }

    init(
        id: UUID = UUID(),
        kind: ExportHistoryKind,
        photoLocalIdentifier: String,
        createdAt: Date = .now,
        pair: PhotoPair? = nil
    ) {
        self.id = id
        kindRaw = kind.rawValue
        self.photoLocalIdentifier = photoLocalIdentifier
        self.createdAt = createdAt
        self.pair = pair
    }
}

extension PhotoPair {
    var hasCombinedExport: Bool {
        exportHistory.contains { $0.kind == .combined }
    }
}

@MainActor
enum ExportHistoryKindResolver {
    // swiftlint:disable switch_case_alignment
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

    // swiftlint:enable switch_case_alignment

    private static func isWatermarkActive(
        renderOptions: ExportRenderOptions,
        appSettings: AppSettings?
    ) -> Bool {
        guard renderOptions.applyWatermark else { return false }
        guard let appSettings else { return false }
        return appSettings.watermarkEnabled
    }
}
