import SwiftUI

struct TutorialTooltip: View {
    private struct Placement {
        let center: CGPoint
        let tailOnTop: Bool
    }

    private static let horizontalPadding: CGFloat = 16
    private static let verticalGap: CGFloat = 12
    private static let maxWidth: CGFloat = 280
    private static let tailSize: CGFloat = 8

    let text: String
    let targetRect: CGRect
    let containerSize: CGSize

    var body: some View {
        let placement = resolvePlacement()
        VStack(spacing: 0) {
            if placement.tailOnTop {
                tail.rotationEffect(.degrees(180))
            }
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: Self.maxWidth)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 2),
                )
            if !placement.tailOnTop {
                tail
            }
        }
        .position(x: placement.center.x, y: placement.center.y)
        .allowsHitTesting(false)
    }

    private var tail: some View {
        Triangle()
            .fill(Color.white)
            .frame(width: Self.tailSize * 2, height: Self.tailSize)
    }

    private func resolvePlacement() -> Placement {
        let approxHeight: CGFloat = 80
        let spaceBelow = containerSize.height - targetRect.maxY
        let spaceAbove = targetRect.minY
        let tailOnTop = spaceBelow >= approxHeight || spaceBelow >= spaceAbove
        let centerY: CGFloat = tailOnTop
            ? targetRect.maxY + Self.verticalGap + approxHeight / 2
            : targetRect.minY - Self.verticalGap - approxHeight / 2
        let clampedY = min(
            max(centerY, approxHeight / 2 + Self.horizontalPadding),
            containerSize.height - approxHeight / 2 - Self.horizontalPadding,
        )
        let centerX = min(
            max(targetRect.midX, Self.maxWidth / 2 + Self.horizontalPadding),
            containerSize.width - Self.maxWidth / 2 - Self.horizontalPadding,
        )
        return Placement(center: CGPoint(x: centerX, y: clampedY), tailOnTop: tailOnTop)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
