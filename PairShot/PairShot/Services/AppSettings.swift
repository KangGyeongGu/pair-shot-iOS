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

    /// Initial alpha applied to the Before-overlay when the After camera
    /// loads a new pair (P8.3). Range 0.0 (invisible) ~ 1.0 (opaque).
    /// Defaults to ``GhostOverlayMath/defaultAlpha`` (0.5) so existing
    /// users keep the Android-parity behaviour.
    ///
    /// Reads/writes are clamped via ``CompositionDefaults/clampAlpha(_:)``
    /// so corrupted UserDefaults can't push the slider off-screen.
    var defaultOverlayAlpha: Double {
        get { CompositionDefaults.clampAlpha(defaults.double(forKey: Self.defaultOverlayAlphaKey)) }
        set { defaults.set(CompositionDefaults.clampAlpha(newValue), forKey: Self.defaultOverlayAlphaKey) }
    }

    /// Default composite layout shown first when the user opens the
    /// composite menu in `ComparisonView` (P8.3). Persisted as the
    /// enum's raw `String` value — `nil` / unknown values fall back to
    /// ``CompositionDefaults/fallbackLayout``.
    var defaultCompositeLayout: CompositeLayout {
        get {
            let raw = defaults.string(forKey: Self.defaultCompositeLayoutKey) ?? ""
            return CompositionDefaults.layout(forRawValue: raw)
        }
        set { defaults.set(newValue.rawValue, forKey: Self.defaultCompositeLayoutKey) }
    }

    /// Whether to stamp the bottom-right of composite images with the
    /// app name + capture date (P5.3 / P8.3). Mirrors
    /// `WatermarkOverlay.userDefaultsKey` so the existing renderer
    /// continues to read through `WatermarkOverlay.isEnabled` unchanged
    /// — `AppSettings` simply exposes the same key as a typed surface
    /// for the settings UI binding.
    var watermarkEnabled: Bool {
        get { defaults.bool(forKey: WatermarkOverlay.userDefaultsKey) }
        set { defaults.set(newValue, forKey: WatermarkOverlay.userDefaultsKey) }
    }

    /// UserDefaults key for the JPEG compression quality.
    static let jpegQualityKey = "pairshot.jpegQuality"

    /// UserDefaults key for the saved-file prefix.
    static let fileNamePrefixKey = "pairshot.fileNamePrefix"

    /// UserDefaults key for the After-overlay starting alpha (P8.3).
    static let defaultOverlayAlphaKey = "pairshot.defaultOverlayAlpha"

    /// UserDefaults key for the preferred composite layout (P8.3).
    static let defaultCompositeLayoutKey = "pairshot.defaultCompositeLayout"

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
            Self.defaultOverlayAlphaKey: CompositionDefaults.fallbackAlpha,
            Self.defaultCompositeLayoutKey: CompositionDefaults.fallbackLayout.rawValue,
            WatermarkOverlay.userDefaultsKey: WatermarkOverlay.defaultEnabled,
        ])
    }
}

/// Pure helpers for the P8.3 composition defaults surfaces. Extracted so
/// the clamping/parsing logic is unit-testable without spinning up
/// `AppSettings` against a real `UserDefaults` instance.
enum CompositionDefaults {
    /// Allowed alpha range. Mirrors ``GhostOverlayMath/alphaRange`` so
    /// the After-camera and the settings preview agree on bounds.
    static let alphaRange: ClosedRange<Double> = 0.0 ... 1.0

    /// Used both as the registered default and as the snap target when
    /// `clampAlpha` receives a non-finite input.
    static let fallbackAlpha: Double = 0.5

    /// Layout chosen when UserDefaults holds an empty/unknown raw value.
    /// Matches `CompositeOptions.default.layout` so the menu and the
    /// renderer don't disagree about "factory default".
    static let fallbackLayout: CompositeLayout = .horizontal

    /// Snap a stored alpha into ``alphaRange``. NaN / infinity collapse
    /// to ``fallbackAlpha`` rather than propagating a poison value into
    /// the slider binding.
    static func clampAlpha(_ value: Double) -> Double {
        guard value.isFinite else { return fallbackAlpha }
        return max(alphaRange.lowerBound, min(alphaRange.upperBound, value))
    }

    /// Resolve a stored raw `String` to a `CompositeLayout`. Empty and
    /// unknown values fall back to ``fallbackLayout`` so a manual edit
    /// of UserDefaults can't crash the picker.
    static func layout(forRawValue raw: String) -> CompositeLayout {
        CompositeLayout(rawValue: raw) ?? fallbackLayout
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
    static func nearest(to quality: Double) -> Self {
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
