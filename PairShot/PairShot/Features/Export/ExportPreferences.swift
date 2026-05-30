import Foundation
import Observation

@Observable
final nonisolated class ExportPreferences: @unchecked Sendable {
    static let includeCombinedKey = "pairshot.exportIncludeCombined"
    static let includeBeforeKey = "pairshot.exportIncludeBefore"
    static let includeAfterKey = "pairshot.exportIncludeAfter"
    static let formatKey = "pairshot.exportFormat"
    static let applyCombineKey = "pairshot.exportApplyCombine"

    @ObservationIgnored private let defaults: UserDefaults

    var includeCombined: Bool {
        didSet { defaults.set(includeCombined, forKey: Self.includeCombinedKey) }
    }

    var includeBefore: Bool {
        didSet { defaults.set(includeBefore, forKey: Self.includeBeforeKey) }
    }

    var includeAfter: Bool {
        didSet { defaults.set(includeAfter, forKey: Self.includeAfterKey) }
    }

    var format: ExportFormat {
        didSet { defaults.set(format.rawValue, forKey: Self.formatKey) }
    }

    var applyCombineSettings: Bool {
        didSet { defaults.set(applyCombineSettings, forKey: Self.applyCombineKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Self.includeCombinedKey: true,
            Self.includeBeforeKey: false,
            Self.includeAfterKey: false,
            Self.formatKey: ExportFormat.individualImages.rawValue,
            Self.applyCombineKey: true,
        ])
        includeCombined = defaults.bool(forKey: Self.includeCombinedKey)
        includeBefore = defaults.bool(forKey: Self.includeBeforeKey)
        includeAfter = defaults.bool(forKey: Self.includeAfterKey)
        let rawFormat = defaults.string(forKey: Self.formatKey) ?? ExportFormat.individualImages.rawValue
        format = ExportFormat(rawValue: rawFormat) ?? .individualImages
        applyCombineSettings = defaults.bool(forKey: Self.applyCombineKey)
    }
}
