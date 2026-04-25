import Foundation
import SwiftUI
import UIKit

/// Pure helpers for the Before-overlay alpha. Lives outside the view so the
/// clamping is unit-testable and the view can stay tiny.
///
/// **Architecture invariant**: this overlay is a *plain semi-transparent
/// UIImage* — no homography, no optical flow, no Vision-based registration.
/// The user nudges the slider; that's the entire feature. (CLAUDE.md hard rule.)
enum GhostOverlayMath {
    /// Allowed alpha range. 0 = invisible, 1 = fully opaque.
    static let alphaRange: ClosedRange<Double> = 0.0 ... 1.0

    /// Default starting alpha when a pair is first opened. Android parity = 0.5.
    static let defaultAlpha: Double = 0.5

    /// Clamp a raw value into `alphaRange`. Used by the slider binding so an
    /// out-of-range starting value (e.g. corrupted UserDefaults) can't push
    /// the slider off-screen.
    static func clamp(_ value: Double) -> Double {
        max(alphaRange.lowerBound, min(value, alphaRange.upperBound))
    }
}

/// Loads a `UIImage` from a `PhotoStorageService` relative path. Synchronous
/// because Before JPEGs are small (≤ a few MB) and we want the overlay to
/// appear at the same instant as the preview. Returns `nil` if the file is
/// missing or unreadable — the overlay then renders empty (no crash).
enum GhostOverlayLoader {
    static func loadImage(
        relativePath: String,
        storage: PhotoStorageService
    ) -> UIImage? {
        guard let url = storage.resolve(relativePath: relativePath) else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

/// Semi-transparent overlay of the Before image, sized to match the preview
/// (`.scaledToFill`). Drawn above the AVCaptureVideoPreviewLayer at `alpha`.
///
/// The view itself is a thin wrapper — no autosizing, no transform; the
/// matching of Before/After framing is the user's responsibility (zoom is
/// auto-restored, but final composition is by hand).
struct GhostOverlayView: View {
    let image: UIImage?
    let alpha: Double

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(GhostOverlayMath.clamp(alpha))
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Slider that drives the Before-overlay alpha. Compact, sits on a translucent
/// pill so it's legible above the live camera feed.
struct GhostOverlayAlphaSlider: View {
    @Binding var alpha: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .accessibilityLabel(String(localized: "Before 투명도"))

            Slider(
                value: Binding(
                    get: { GhostOverlayMath.clamp(alpha) },
                    set: { alpha = GhostOverlayMath.clamp($0) }
                ),
                in: GhostOverlayMath.alphaRange
            )
            .tint(.yellow)

            Text(percentLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.45)))
    }

    private var percentLabel: String {
        let pct = Int((GhostOverlayMath.clamp(alpha) * 100).rounded())
        return "\(pct)%"
    }
}

#Preview {
    ZStack {
        Color.gray
        VStack {
            Spacer()
            GhostOverlayAlphaSlider(alpha: .constant(0.5))
                .padding()
        }
    }
}
