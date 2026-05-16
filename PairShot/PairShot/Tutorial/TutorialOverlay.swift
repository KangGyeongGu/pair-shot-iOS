import SwiftUI

struct TutorialOverlay: View {
    private static let cutoutInset: CGFloat = -8
    private static let cutoutCornerRadius: CGFloat = 12
    private static let dimOpacity: Double = 0.55
    private static let fullDimOpacity: Double = 0.5

    @Environment(TutorialCoordinator.self) private var coord
    let anchors: [String: Anchor<CGRect>]

    var body: some View {
        GeometryReader { proxy in
            content(in: proxy)
        }
        .ignoresSafeArea()
        .allowsHitTesting(coord.isActive)
    }

    @ViewBuilder
    private func content(in proxy: GeometryProxy) -> some View {
        if let step = coord.current,
           step != .done,
           let anchorID = anchorID(for: step),
           let anchor = anchors[anchorID]
        {
            let rect = proxy[anchor].insetBy(dx: Self.cutoutInset, dy: Self.cutoutInset)
            ZStack {
                DimmedMask(
                    containerSize: proxy.size,
                    cutout: rect,
                    cornerRadius: Self.cutoutCornerRadius,
                    opacity: Self.dimOpacity,
                )
                TutorialTooltip(
                    text: TutorialStepCopy.text(for: step),
                    targetRect: rect,
                    containerSize: proxy.size,
                )
            }
        } else if coord.isActive {
            Color.black.opacity(Self.fullDimOpacity)
        }
    }

    private func anchorID(for step: TutorialStep) -> String? {
        switch step {
            case .homeCaptureHighlight,
                 .captureGuidePortrait,
                 .captureGuideLeft,
                 .captureGuideRight:
                TutorialAnchorID.cameraShutter

            case .backToHome:
                TutorialAnchorID.cameraHomeButton

            case .tapPairCard:
                TutorialAnchorID.homeFirstPairCard

            case .afterCameraGuide:
                TutorialAnchorID.afterShutter

            case .backToHome2:
                TutorialAnchorID.afterHomeButton

            default:
                nil
        }
    }
}

private struct DimmedMask: View {
    let containerSize: CGSize
    let cutout: CGRect
    let cornerRadius: CGFloat
    let opacity: Double

    var body: some View {
        let shape = SpotlightHoleShape(cutout: cutout, cornerRadius: cornerRadius)
        Color.black.opacity(opacity)
            .frame(width: containerSize.width, height: containerSize.height)
            .mask(shape.fill(style: FillStyle(eoFill: true)))
            .contentShape(shape, eoFill: true)
    }
}

private struct SpotlightHoleShape: Shape {
    let cutout: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(Path(roundedRect: cutout, cornerRadius: cornerRadius))
        return path
    }
}
