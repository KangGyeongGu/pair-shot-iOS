import SwiftUI
import UIKit

extension ColorRGBA {
    init(color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                alpha: Double(alpha),
            )
            return
        }
        var white: CGFloat = 0
        var whiteAlpha: CGFloat = 0
        if uiColor.getWhite(&white, alpha: &whiteAlpha) {
            self.init(
                red: Double(white),
                green: Double(white),
                blue: Double(white),
                alpha: Double(whiteAlpha),
            )
            return
        }
        self.init(red: 0, green: 0, blue: 0, alpha: 1.0)
    }
}

extension Color {
    init(rgba: ColorRGBA) {
        self.init(
            .sRGB,
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha,
        )
    }
}

extension UIColor {
    convenience nonisolated init(rgba: ColorRGBA) {
        self.init(
            red: CGFloat(rgba.red),
            green: CGFloat(rgba.green),
            blue: CGFloat(rgba.blue),
            alpha: CGFloat(rgba.alpha),
        )
    }
}
