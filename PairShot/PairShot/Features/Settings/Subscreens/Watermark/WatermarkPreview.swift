import SwiftUI
import UIKit

struct WatermarkPreview: View {
    let settings: WatermarkSettings
    let logoData: Data?

    var body: some View {
        ZStack {
            sampleBackdrop
            content
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .frame(minHeight: 200)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "watermark_preview_desc"))
    }

    private var sampleBackdrop: some View {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.18, blue: 0.20),
                Color(red: 0.45, green: 0.46, blue: 0.50),
                Color(red: 0.78, green: 0.79, blue: 0.82),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
        .overlay {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .padding(48)
                .foregroundStyle(.white.opacity(0.18))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch settings.type {
            case .text:
                if settings.text.isEmpty {
                    Text(String(localized: "watermark_preview_empty"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    WatermarkTextPreviewCanvas(settings: settings)
                }

            case .logo:
                WatermarkLogoPreview(settings: settings, logoData: logoData)
        }
    }
}

private struct WatermarkTextPreviewCanvas: View {
    let settings: WatermarkSettings

    var body: some View {
        Canvas { context, size in
            guard !settings.text.isEmpty,
                  size.width > 0,
                  size.height > 0
            else { return }
            let safeRatio = max(
                WatermarkSettings.textSizeRatioRange.lowerBound,
                min(WatermarkSettings.textSizeRatioRange.upperBound, settings.textSizeRatio),
            )
            let fontSize = max(10, size.width * CGFloat(safeRatio))
            let resolved = context.resolve(
                Text(verbatim: settings.text)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(settings.opacity)),
            )
            let textSize = resolved.measure(in: size)
            guard textSize.width > 0, textSize.height > 0 else { return }

            let safeLineCount = max(1, settings.lineCount)
            let safeRepeatCount = max(0.1, settings.repeatCount)
            let diagonal = sqrt(size.width * size.width + size.height * size.height)
            let lineSpacing = diagonal / CGFloat(safeLineCount + 1)
            let textSpacing = max(textSize.width * CGFloat(2.0 / safeRepeatCount), textSize.width + 16)

            context.drawLayer { layer in
                layer.translateBy(x: size.width / 2, y: size.height / 2)
                layer.rotate(by: .degrees(-45))
                layer.translateBy(x: -size.width / 2, y: -size.height / 2)

                let extendedWidth = size.width * 1.5
                let extendedHeight = size.height * 1.5
                let originX = -size.width * 0.25
                let originY = -size.height * 0.25

                var y = originY
                while y < originY + extendedHeight {
                    var x = originX
                    while x < originX + extendedWidth {
                        layer.draw(resolved, at: CGPoint(x: x, y: y), anchor: .topLeading)
                        x += textSpacing
                    }
                    y += lineSpacing
                }
            }
        }
    }
}

private struct WatermarkLogoPreview: View {
    let settings: WatermarkSettings
    let logoData: Data?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                if let data = logoData,
                   let uiImage = UIImage(data: data)
                {
                    let ratio = clampedRatio(settings.logoWidthRatio)
                    let width = geometry.size.width * CGFloat(ratio)
                    let aspect = uiImage.size.height / max(uiImage.size.width, 1)
                    let height = width * aspect
                    let padding = geometry.size.width * 0.02
                    let origin = computeOrigin(
                        in: geometry.size,
                        width: width,
                        height: height,
                        padding: padding,
                        position: settings.logoPosition,
                    )
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: height)
                        .opacity(settings.logoAlpha)
                        .offset(x: origin.x, y: origin.y)
                } else {
                    Text(String(localized: "watermark_preview_empty"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func clampedRatio(_ value: Double) -> Double {
        max(
            WatermarkSettings.logoWidthRatioRange.lowerBound,
            min(WatermarkSettings.logoWidthRatioRange.upperBound, value),
        )
    }

    private func computeOrigin(
        in canvas: CGSize,
        width: CGFloat,
        height: CGFloat,
        padding: CGFloat,
        position: LogoPosition,
    ) -> CGPoint {
        switch position {
            case .topLeft: CGPoint(x: padding, y: padding)
            case .topCenter: CGPoint(x: (canvas.width - width) / 2, y: padding)
            case .topRight: CGPoint(x: canvas.width - width - padding, y: padding)
            case .centerLeft: CGPoint(x: padding, y: (canvas.height - height) / 2)
            case .center: CGPoint(x: (canvas.width - width) / 2, y: (canvas.height - height) / 2)
            case .centerRight: CGPoint(x: canvas.width - width - padding, y: (canvas.height - height) / 2)
            case .bottomLeft: CGPoint(x: padding, y: canvas.height - height - padding)
            case .bottomCenter: CGPoint(x: (canvas.width - width) / 2, y: canvas.height - height - padding)
            case .bottomRight: CGPoint(x: canvas.width - width - padding, y: canvas.height - height - padding)
        }
    }
}
