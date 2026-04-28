import SwiftUI

enum AppMaterial: Equatable, Hashable, CaseIterable {
    case panel
    case accent
    case sheet
}

enum AdaptiveGlassKind: Equatable, Hashable, CaseIterable {
    case regular
    case thin
    case thick
}

extension View {
    func appMaterialBackground(_ material: AppMaterial) -> some View {
        modifier(AppMaterialBackgroundModifier(material: material))
    }

    func appMaterialBackground(_ material: AppMaterial, in shape: some Shape) -> some View {
        modifier(AppMaterialBackgroundShapeModifier(material: material, shape: shape))
    }

    func adaptiveGlass(in shape: some Shape, kind: AdaptiveGlassKind = .regular) -> some View {
        modifier(AdaptiveGlassModifier(shape: shape, kind: kind))
    }

    func adaptiveGlass(
        in shape: some Shape,
        kind: AdaptiveGlassKind = .regular,
        legacyFill: Color
    ) -> some View {
        modifier(AdaptiveGlassFillModifier(shape: shape, kind: kind, legacyFill: legacyFill))
    }
}

private struct AppMaterialBackgroundModifier: ViewModifier {
    let material: AppMaterial

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(material.liquidGlass, in: Rectangle())
        } else {
            content.background(material.legacyMaterial)
        }
    }
}

private struct AppMaterialBackgroundShapeModifier<S: Shape>: ViewModifier {
    let material: AppMaterial
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(material.liquidGlass, in: shape)
        } else {
            content.background(shape.fill(material.legacyMaterial))
        }
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

extension AppMaterial {
    var legacyMaterial: Material {
        switch self {
            case .panel: .regularMaterial
            case .accent: .thinMaterial
            case .sheet: .thickMaterial
        }
    }

    @available(iOS 26.0, *)
    var liquidGlass: Glass {
        switch self {
            case .panel: .regular
            case .accent: .regular
            case .sheet: .regular
        }
    }

    var identifier: String {
        switch self {
            case .panel: "panel"
            case .accent: "accent"
            case .sheet: "sheet"
        }
    }

    init?(identifier: String) {
        switch identifier {
            case "panel": self = .panel
            case "accent": self = .accent
            case "sheet": self = .sheet
            default: return nil
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
