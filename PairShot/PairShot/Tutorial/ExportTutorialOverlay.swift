import SwiftUI

struct ExportTutorialOverlay: View {
    private static let cutoutInset: CGFloat = -8
    private static let cutoutCornerRadius: CGFloat = 12
    private static let dimOpacity: Double = 0.55

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ExportTutorialCoordinator.self) private var coord
    let anchors: [String: Anchor<CGRect>]

    var body: some View {
        GeometryReader { proxy in
            content(in: proxy)
        }
        .ignoresSafeArea()
        .allowsHitTesting(coord.isActive)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: coord.current)
    }

    @ViewBuilder
    private func content(in proxy: GeometryProxy) -> some View {
        if let step = coord.current,
           let anchor = anchors[anchorID(for: step)]
        {
            anchoredContent(
                step: step,
                rect: proxy[anchor],
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
            )
        } else if coord.isActive {
            Color.black.opacity(Self.dimOpacity)
        }
    }

    @ViewBuilder
    private func anchoredContent(
        step: ExportTutorialStep,
        rect rawRect: CGRect,
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets,
    ) -> some View {
        let rect = rawRect.insetBy(dx: Self.cutoutInset, dy: Self.cutoutInset)
        let placement = TutorialMessageModal.placement(for: rect, containerSize: containerSize)
        let progress = coord.progress(for: step)
        let isLast = step == ExportTutorialStep.allCases.last
        ZStack {
            ExportDimmedMask(
                containerSize: containerSize,
                cutout: rect,
                cornerRadius: Self.cutoutCornerRadius,
                opacity: Self.dimOpacity,
            )
            TutorialMessageModal(
                text: ExportTutorialStepCopy.text(for: step),
                progress: progress,
                showsSkip: false,
                showsNext: true,
                nextButtonLabelKey: isLast ? "tutorial_button_finish" : "tutorial_button_next",
                phoneOrientationAngle: nil,
                placement: placement,
                targetRect: rect,
                containerSize: containerSize,
                safeAreaInsets: safeAreaInsets,
                onSkip: { coord.cancel() },
                onNext: { coord.advance() },
            )
        }
    }

    private func anchorID(for step: ExportTutorialStep) -> String {
        switch step {
            case .includes: ExportTutorialAnchorID.includes
            case .format: ExportTutorialAnchorID.format
            case .watermark: ExportTutorialAnchorID.watermark
            case .combine: ExportTutorialAnchorID.combine
        }
    }
}

private struct ExportDimmedMask: View {
    let containerSize: CGSize
    let cutout: CGRect
    let cornerRadius: CGFloat
    let opacity: Double

    var body: some View {
        let shape = ExportSpotlightHoleShape(cutout: cutout, cornerRadius: cornerRadius)
        Color.black.opacity(opacity)
            .frame(width: containerSize.width, height: containerSize.height)
            .mask(shape.fill(style: FillStyle(eoFill: true)))
            .contentShape(shape, eoFill: true)
    }
}

private struct ExportSpotlightHoleShape: Shape {
    let cutout: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(Path(roundedRect: cutout, cornerRadius: cornerRadius))
        return path
    }
}

struct ExportTutorialOverlayModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.overlayPreferenceValue(SpotlightAnchorKey.self) { anchors in
            ExportTutorialOverlay(anchors: anchors)
        }
    }
}

extension View {
    func exportTutorialOverlay() -> some View {
        modifier(ExportTutorialOverlayModifier())
    }
}
