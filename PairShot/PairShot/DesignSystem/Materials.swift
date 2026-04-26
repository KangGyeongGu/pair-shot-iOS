import SwiftUI

// P9.2 — Material tokens with iOS 26+ Liquid Glass conditional.
//
// Apple's iOS 26 SDK introduces "Liquid Glass" materials as part of
// the visionOS-influenced design refresh. The exact API name
// (`Material.glass`, `.glassRegular`, etc.) is provisional and is
// fenced behind `#available(iOS 26.0, *)` so the iOS 17 baseline
// continues to compile against `.regularMaterial`.
//
// Usage:
// ```swift
// HStack { ... }
//     .appMaterialBackground(.panel)
// ```
//
// Why a token enum rather than passing `Material` directly:
// - The token names (`panel`, `accent`, `sheet`) describe **intent**
//   rather than the rendered material, so the iOS 26 vs iOS 17
//   mapping is decoupled from the call site.
// - When iOS 26 finalises the API, only this file changes.

/// Semantic material tokens. Each maps to a concrete `Material` via
/// ``View/appMaterialBackground(_:)``.
enum AppMaterial: Equatable, Hashable, CaseIterable {
    /// Floating control bar / chrome over a camera preview.
    case panel
    /// Emphasised surface — buttons, pills, badges.
    case accent
    /// Bottom-sheet / modal surface.
    case sheet
}

extension View {
    /// Apply an `AppMaterial` token as the view's background. iOS 26+
    /// receives the Liquid Glass variant; older versions fall back to
    /// `.regularMaterial` / `.thinMaterial` / `.thickMaterial` per the
    /// token's intent.
    func appMaterialBackground(_ material: AppMaterial) -> some View {
        background(material.swiftUIMaterial)
    }
}

extension AppMaterial {
    /// Resolve to the concrete `Material` for the current OS. Internal
    /// rather than `private` so ``MaterialResolverTests`` can assert
    /// the iOS 17 mapping directly without driving SwiftUI.
    var swiftUIMaterial: Material {
        // P10b — actual `#available(iOS 26.0, *)` branch is now in
        // place. The Liquid Glass material symbols (`Material.glass`
        // family) are still being finalised in the iOS 26 SDK, so the
        // 26+ branch deliberately reuses the same `Material` mapping
        // as iOS 17~25 for now. The structural fork keeps the
        // single-call-site contract: when Apple finalises the API,
        // only the branch body changes — every call site continues to
        // use `.appMaterialBackground(.panel)` etc.
        if #available(iOS 26.0, *) {
            liquidGlassMaterial
        } else {
            legacyMaterial
        }
    }

    /// iOS 17~25 mapping. Conservative `Material` palette that ships
    /// today and renders consistently across the supported range.
    var legacyMaterial: Material {
        switch self {
            case .panel: .regularMaterial
            case .accent: .thinMaterial
            case .sheet: .thickMaterial
        }
    }

    /// iOS 26+ Liquid Glass mapping. Currently identical to
    /// ``legacyMaterial`` because the official `Material.glass`
    /// symbol is still pre-release; once it lands we swap each case
    /// to its glass variant in this single place. Marked
    /// `@available(iOS 26.0, *)` so the compiler enforces the gate
    /// when the symbol is updated.
    @available(iOS 26.0, *)
    var liquidGlassMaterial: Material {
        // TODO(P11): swap to `Material.glassRegular` / `.glassThin` /
        // `.glassThick` once the iOS 26 SDK ships final symbols.
        switch self {
            case .panel: .regularMaterial
            case .accent: .thinMaterial
            case .sheet: .thickMaterial
        }
    }

    /// Stable identifier exposed for tests and accessibility audits.
    /// Round-trip via `init?(identifier:)` so `MaterialResolverTests`
    /// can verify the mapping is exhaustive.
    var identifier: String {
        switch self {
            case .panel: "panel"
            case .accent: "accent"
            case .sheet: "sheet"
        }
    }

    /// Inverse of ``identifier`` — `nil` for unknown strings. Used by
    /// tests to verify every case round-trips.
    init?(identifier: String) {
        switch identifier {
            case "panel": self = .panel
            case "accent": self = .accent
            case "sheet": self = .sheet
            default: return nil
        }
    }
}
