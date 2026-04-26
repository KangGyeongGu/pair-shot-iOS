import SwiftUI

enum AppMaterial: Equatable, Hashable, CaseIterable {
    case panel
    case accent
    case sheet
}

extension View {
    func appMaterialBackground(_ material: AppMaterial) -> some View {
        background(material.swiftUIMaterial)
    }
}

extension AppMaterial {
    var swiftUIMaterial: Material {
        if #available(iOS 26.0, *) {
            liquidGlassMaterial
        } else {
            legacyMaterial
        }
    }

    var legacyMaterial: Material {
        switch self {
            case .panel: .regularMaterial
            case .accent: .thinMaterial
            case .sheet: .thickMaterial
        }
    }

    @available(iOS 26.0, *)
    var liquidGlassMaterial: Material {
        switch self {
            case .panel: .regularMaterial
            case .accent: .thinMaterial
            case .sheet: .thickMaterial
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
