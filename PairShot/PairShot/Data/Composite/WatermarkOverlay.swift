import Foundation
import UIKit

enum WatermarkOverlay {
    static let userDefaultsKey = "watermarkEnabled"

    static let defaultEnabled = true

    static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [userDefaultsKey: defaultEnabled])
        return defaults.bool(forKey: userDefaultsKey)
    }

    static func makeText(appName: String = "PairShot", date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "\(appName) · \(formatter.string(from: date))"
    }

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
            source.draw(in: CGRect(origin: .zero, size: canvasSize))

            let fontSize = max(14, min(canvasSize.width, canvasSize.height) * 0.022)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let attributed = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributed.size()

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
