import Foundation
import UIKit

/// P5.3 — bottom-right text watermark for a composite image.
///
/// **Scope deliberately tiny**: a single `NSAttributedString` drawn with a
/// translucent dark pill behind it. No fancy effects, no image stamps, no
/// per-pixel manipulation. Phase 8.3 will expose the on/off toggle in the
/// settings UI; for now the only knob is `UserDefaults.standard.bool(forKey:
/// "watermarkEnabled")` which defaults to `true` via `register(defaults:)`.
///
/// Why a separate file vs. inlining inside `CompositeRenderer`: the watermark
/// also gets reused for the share-sheet export path in P7.3, where the source
/// image isn't a fresh composite (could be a single Before/After). Keeping
/// the API as a pure `apply(to:)` makes that reuse mechanical.
enum WatermarkOverlay {
    /// UserDefaults key. Settings UI (P8.3) and CompositeRenderer (P5.2) both
    /// read through `isEnabled` rather than the raw key.
    static let userDefaultsKey = "watermarkEnabled"

    /// Default = on. Field workers in the Android beta consistently asked for
    /// timestamps; making it opt-out matches that behaviour. Settings can
    /// override per-user.
    static let defaultEnabled = true

    /// Read the current toggle. Registers the default the first time it's
    /// asked, so pre-Phase-8 callers behave correctly even before the
    /// settings UI lands.
    static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [userDefaultsKey: defaultEnabled])
        return defaults.bool(forKey: userDefaultsKey)
    }

    /// Compose the watermark text from the app name + a captured date. Kept
    /// pure (no UIKit) so it's testable without spinning up a graphics
    /// context.
    ///
    /// Audit-C — `Locale(identifier: "ko_KR")` was hard-coded, which
    /// produced Korean 12-/24-hour boundaries even for English-locale
    /// users sharing the JPEG abroad. The format string itself
    /// (`yyyy-MM-dd HH:mm`) is locale-agnostic, but `Locale.current`
    /// keeps the calendar / digit shaping consistent with the rest of
    /// the device's UX.
    static func makeText(appName: String = "PairShot", date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "\(appName) · \(formatter.string(from: date))"
    }

    /// Returns a new `UIImage` with the watermark stamped in the bottom-right.
    /// The original image's pixels are preserved untouched outside the badge
    /// rectangle (no full-frame redraw of the source bitmap).
    ///
    /// - Parameters:
    ///   - source: the canvas to stamp.
    ///   - date: timestamp shown next to the app name. Defaults to `.now`.
    /// - Returns: `source` if the resulting graphics context can't be created;
    ///   otherwise the stamped variant.
    static func apply(to source: UIImage, date: Date = .now) -> UIImage {
        let text = makeText(date: date)
        let canvasSize = source.size
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return source
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { _ in
            // Step 1: blit the source. We're not modifying pixels outside the
            // badge, but UIGraphicsImageRenderer needs a fresh context so a
            // baseline draw is unavoidable.
            source.draw(in: CGRect(origin: .zero, size: canvasSize))

            // Step 2: text attributes. Font scales with the smaller edge so
            // a 4032-px composite gets a readable badge while a thumbnail
            // doesn't get drowned.
            let fontSize = max(14, min(canvasSize.width, canvasSize.height) * 0.022)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.white,
            ]
            let attributed = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributed.size()

            // Step 3: badge rectangle in the bottom-right with consistent
            // padding regardless of canvas size.
            let padding = max(8, min(canvasSize.width, canvasSize.height) * 0.012)
            let badgeRect = CGRect(
                x: canvasSize.width - textSize.width - padding * 3,
                y: canvasSize.height - textSize.height - padding * 2,
                width: textSize.width + padding * 2,
                height: textSize.height + padding
            )
            let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: padding)
            UIColor.black.withAlphaComponent(0.55).setFill()
            badgePath.fill()

            let textOrigin = CGPoint(
                x: badgeRect.minX + padding,
                y: badgeRect.minY + padding / 2
            )
            attributed.draw(at: textOrigin)
        }
    }
}
