import Foundation
import UIKit

// P9.1 — Centralised haptic feedback wrapper.
//
// Why not call `UIImpactFeedbackGenerator` directly at the call site:
// - **Test seam**: a `HapticServicing` protocol lets tests verify *that*
//   a haptic fired without trying to assert on the actual taptic engine.
// - **Style consistency**: shutter is always `.heavy`, toggles are
//   always `.light`, completion is always `.success`. Centralising the
//   mapping prevents one feature drifting to `.medium` while another
//   uses `.heavy`.
// - **Prepare cost**: `prepare()` is documented to reduce latency by
//   ~100 ms. We call it exactly once per emit so back-to-back taps
//   don't lag.
//
// **MainActor isolation**: UIKit's feedback generators are not
// thread-safe and must be touched from the main actor. Both the
// protocol and the production class are `@MainActor`-isolated to
// satisfy Swift 6 strict concurrency.

/// Impact feedback styles. 1:1 wrapper over
/// `UIImpactFeedbackGenerator.FeedbackStyle` so callers don't import
/// UIKit just to pick a style.
enum HapticImpactStyle: Equatable {
    case light
    case medium
    case heavy
    case soft
    case rigid

    fileprivate var uikit: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
            case .light: .light
            case .medium: .medium
            case .heavy: .heavy
            case .soft: .soft
            case .rigid: .rigid
        }
    }
}

/// Notification feedback kinds. Mirrors
/// `UINotificationFeedbackGenerator.FeedbackType`.
enum HapticNotificationKind: Equatable {
    case success
    case warning
    case error

    fileprivate var uikit: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
            case .success: .success
            case .warning: .warning
            case .error: .error
        }
    }
}

/// Protocol so view code can depend on a stub in tests / Previews.
@MainActor
protocol HapticServicing: AnyObject {
    func impact(_ style: HapticImpactStyle)
    func notify(_ kind: HapticNotificationKind)
}

/// Production implementation. Allocates a fresh generator per emit so
/// the call site doesn't have to manage a long-lived generator
/// reference. The impact generator is `prepare()`d immediately before
/// firing, which is the documented Apple recipe for minimising latency
/// when the firing moment isn't predictable in advance.
@MainActor
final class HapticService: HapticServicing {
    /// Shared singleton matching the rest of the service layer
    /// (`AppSettings.shared`, `ThumbnailCache.shared`). View code can
    /// take a non-shared instance for tests via `init()`.
    static let shared = HapticService()

    init() {}

    func impact(_ style: HapticImpactStyle) {
        let generator = UIImpactFeedbackGenerator(style: style.uikit)
        generator.prepare()
        generator.impactOccurred()
    }

    func notify(_ kind: HapticNotificationKind) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(kind.uikit)
    }
}
