import Foundation

final nonisolated class ExportPreferences: @unchecked Sendable {
    static let includeCombinedKey = "pairshot.exportIncludeCombined"
    static let includeBeforeKey = "pairshot.exportIncludeBefore"
    static let includeAfterKey = "pairshot.exportIncludeAfter"
    static let formatKey = "pairshot.exportFormat"
    static let applyCombineKey = "pairshot.exportApplyCombine"

    private let defaults: UserDefaults

    var includeCombined: Bool {
        get { defaults.bool(forKey: Self.includeCombinedKey) }
        set { defaults.set(newValue, forKey: Self.includeCombinedKey) }
    }

    var includeBefore: Bool {
        get { defaults.bool(forKey: Self.includeBeforeKey) }
        set { defaults.set(newValue, forKey: Self.includeBeforeKey) }
    }

    var includeAfter: Bool {
        get { defaults.bool(forKey: Self.includeAfterKey) }
        set { defaults.set(newValue, forKey: Self.includeAfterKey) }
    }

    var format: ExportFormat {
        get {
            let raw = defaults.string(forKey: Self.formatKey) ?? ExportFormat.individualImages.rawValue
            return ExportFormat(rawValue: raw) ?? .individualImages
        }
        set { defaults.set(newValue.rawValue, forKey: Self.formatKey) }
    }

    var applyCombineSettings: Bool {
        get { defaults.bool(forKey: Self.applyCombineKey) }
        set { defaults.set(newValue, forKey: Self.applyCombineKey) }
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
    }
}
