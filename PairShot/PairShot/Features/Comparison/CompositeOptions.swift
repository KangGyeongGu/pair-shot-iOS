import Foundation
import SwiftUI

/// P5.2 — layout choices for the Before+After composite image.
///
/// **Architecture invariant** (CLAUDE.md): the composite is a *paste of two
/// images side-by-side or stacked*. There is no homography, no feature
/// matching, no auto color correction. The user picks one of these two
/// layouts and the renderer concatenates pixels.
///
/// Phase 8.3 ("Settings → 합성 레이아웃 기본값") will read a UserDefaults
/// value of this enum's `rawValue` to seed the picker. For now the only
/// caller is `ComparisonView`'s composite menu; the `CaseIterable` +
/// `Identifiable` conformance lets it render as a SwiftUI `Picker`.
enum CompositeLayout: String, CaseIterable, Identifiable {
    /// Before on the left, After on the right. Output canvas height matches
    /// the *smaller* of the two source heights so neither side is letterboxed.
    case horizontal
    /// Before on top, After on bottom. Output canvas width matches the
    /// *smaller* of the two source widths.
    case vertical

    var id: String {
        rawValue
    }

    /// Korean label for the layout picker.
    var label: String {
        switch self {
            case .horizontal: String(localized: "좌우")
            case .vertical: String(localized: "상하")
        }
    }

    /// SF Symbol used in the menu.
    var systemImage: String {
        switch self {
            case .horizontal: "rectangle.split.2x1"
            case .vertical: "rectangle.split.1x2"
        }
    }
}

/// Bundle of options forwarded from the UI to `CompositeRenderer`. Kept as a
/// value type so a future settings panel can construct it from UserDefaults
/// without leaking SwiftUI bindings into the renderer.
struct CompositeOptions: Equatable {
    /// horizontal | vertical
    var layout: CompositeLayout
    /// JPEG compression quality, 0.0~1.0. 0.9 matches Android v1.1.3 default.
    var jpegQuality: CGFloat
    /// Stamp the bottom-right with app name + capture date when `true`.
    /// Driven by `WatermarkOverlay.isEnabled` (UserDefaults-backed).
    var watermarkEnabled: Bool

    static let `default` = CompositeOptions(
        layout: .horizontal,
        jpegQuality: 0.9,
        watermarkEnabled: true
    )
}
