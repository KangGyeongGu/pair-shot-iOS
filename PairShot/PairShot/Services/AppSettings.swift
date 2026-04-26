import Foundation
import Observation

/// P8.1·P8.2 — UserDefaults-backed app preferences exposed to SwiftUI.
///
/// Why a single `@Observable` wrapper instead of inlining `@AppStorage`
/// in each view:
/// - `PhotoStorageService` and the capture coordinators consume settings
///   from non-View contexts, where `@AppStorage` is awkward (it requires
///   a `View` to register its publisher).
/// - The UserDefaults schema is centralised so future migrations only
///   touch one file.
///
/// Pattern matches `WatermarkOverlay.isEnabled` (P5.3) but as an
/// instance type so SwiftUI views can `@Bindable` against it.
///
/// Lifecycle: instantiated once in `PairShotApp.init`, injected via
/// `.environment(_:)`. Tests can construct an isolated instance with a
/// scratch `UserDefaults` to avoid bleeding global state.
@MainActor
@Observable
final class AppSettings {
    /// JPEG compression quality applied to Before/After/composite saves.
    /// 0.0 (smallest) ~ 1.0 (largest). Defaults to ``CaptureQualityPreset/standard``.
    var jpegQuality: Double {
        get { defaults.double(forKey: Self.jpegQualityKey) }
        set { defaults.set(newValue, forKey: Self.jpegQualityKey) }
    }

    /// Optional filename prefix prepended to saved JPEGs (`<prefix><UUID>.jpg`).
    /// Empty string disables prefixing. Persisted raw — sanitization is
    /// the writer's job (`FileNamePrefixValidator.sanitize`).
    var fileNamePrefix: String {
        get { defaults.string(forKey: Self.fileNamePrefixKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.fileNamePrefixKey) }
    }

    /// UserDefaults key for the JPEG compression quality.
    static let jpegQualityKey = "pairshot.jpegQuality"

    /// UserDefaults key for the saved-file prefix.
    static let fileNamePrefixKey = "pairshot.fileNamePrefix"

    /// Process-wide singleton used by services that aren't view-injected
    /// (e.g. background coordinators). View code should prefer the
    /// `@Environment(AppSettings.self)` injection so test doubles work.
    static let shared = AppSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Self.jpegQualityKey: CaptureQualityPreset.standard.rawValue,
            Self.fileNamePrefixKey: "",
        ])
    }
}

/// Discrete JPEG quality preset surfaced in the settings UI. Three steps
/// — low / standard / high — matches the Android reference v1.1.3 to
/// minimise the choice surface for field workers.
enum CaptureQualityPreset: Double, CaseIterable, Identifiable {
    case low = 0.6
    case standard = 0.8
    case high = 0.95

    var id: Double {
        rawValue
    }

    /// Korean label for the picker.
    var label: String {
        switch self {
            case .low: String(localized: "낮음")
            case .standard: String(localized: "표준")
            case .high: String(localized: "높음")
        }
    }

    /// Picks the closest preset to a stored quality value. Used to seed
    /// the segmented picker when UserDefaults holds an arbitrary value.
    static func nearest(to quality: Double) -> CaptureQualityPreset {
        allCases.min(by: { abs($0.rawValue - quality) < abs($1.rawValue - quality) }) ?? .standard
    }
}

/// Pure helpers for sanitising user-supplied filename prefixes.
///
/// Constraints:
/// - Trim leading/trailing whitespace.
/// - Strip filesystem-reserved characters (`/`, `\`, `:`, `?`, `*`, `"`,
///   `<`, `>`, `|`, control chars). HFS+/APFS technically accept `:` but
///   it surfaces as `/` to legacy code paths, so we reject it too.
/// - Truncate to a sensible upper bound (`maxLength`) so the resulting
///   `<prefix><UUID>.jpg` filename fits comfortably under the FAT32
///   limit some external tools still impose.
enum FileNamePrefixValidator {
    /// Maximum number of characters retained after sanitisation.
    static let maxLength = 32

    /// Characters stripped during sanitisation. Includes the POSIX
    /// path separator and all Windows-reserved chars (Photos export to
    /// SMB shares is a common field-worker workflow).
    static let forbiddenCharacters: CharacterSet = {
        var set = CharacterSet(charactersIn: "/\\:?*\"<>|")
        set.formUnion(.controlCharacters)
        set.formUnion(.newlines)
        return set
    }()

    /// Returns `raw` with whitespace trimmed, forbidden characters
    /// removed, and length capped at ``maxLength``.
    static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let scrubbed = trimmed.unicodeScalars
            .filter { !forbiddenCharacters.contains($0) }
            .map(String.init)
            .joined()
        if scrubbed.count <= maxLength {
            return scrubbed
        }
        return String(scrubbed.prefix(maxLength))
    }
}
