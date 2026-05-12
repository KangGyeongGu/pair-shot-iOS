import SwiftUI

enum AdaptiveGlassKind: Equatable, Hashable, CaseIterable {
    case regular
    case thin
    case thick
}

extension View {
    func adaptiveGlass(in shape: some Shape, kind: AdaptiveGlassKind = .regular) -> some View {
        modifier(AdaptiveGlassModifier(shape: shape, kind: kind))
    }

    func adaptiveGlass(
        in shape: some Shape,
        legacyFill: Color,
        kind: AdaptiveGlassKind = .regular
    ) -> some View {
        modifier(AdaptiveGlassFillModifier(shape: shape, kind: kind, legacyFill: legacyFill))
    }
}

private struct AdaptiveGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let kind: AdaptiveGlassKind

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(kind.liquidGlass, in: shape)
        } else {
            content.background(shape.fill(kind.legacyMaterial))
        }
    }
}

private struct AdaptiveGlassFillModifier<S: Shape>: ViewModifier {
    let shape: S
    let kind: AdaptiveGlassKind
    let legacyFill: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(kind.liquidGlass, in: shape)
        } else {
            content.background(shape.fill(legacyFill))
        }
    }
}

extension AdaptiveGlassKind {
    var legacyMaterial: Material {
        switch self {
            case .regular: .regularMaterial
            case .thin: .thinMaterial
            case .thick: .thickMaterial
        }
    }

    @available(iOS 26.0, *)
    var liquidGlass: Glass {
        .regular
    }
}
