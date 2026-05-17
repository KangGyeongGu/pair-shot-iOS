import SwiftUI

struct TutorialOverlay: View {
    private static let cutoutInset: CGFloat = -8
    private static let cutoutCornerRadius: CGFloat = 12
    private static let standardDimOpacity: Double = 0.55

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TutorialCoordinator.self) private var coord
    let anchors: [String: Anchor<CGRect>]

    var body: some View {
        GeometryReader { proxy in
            content(in: proxy)
        }
        .ignoresSafeArea()
        .allowsHitTesting(Self.shouldBlockHitTesting(step: coord.current))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: coord.current)
    }

    static func shouldBlockHitTesting(step: TutorialStep?) -> Bool {
        guard let step else { return false }
        return step != .afterCameraInProgress
    }

    @ViewBuilder
    private func content(in proxy: GeometryProxy) -> some View {
        if coord.current == .done {
            doneContent(containerSize: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
        } else if let step = coord.current,
                  let anchorID = anchorID(for: step),
                  let anchor = anchors[anchorID]
        {
            anchoredContent(
                step: step,
                rect: proxy[anchor],
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
            )
        } else if let step = coord.current, Self.dimOpacity(for: step) > 0 {
            Color.black.opacity(Self.dimOpacity(for: step))
        }
    }

    @ViewBuilder
    private func doneContent(containerSize: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let centerRect = CGRect(
            x: containerSize.width / 2 - 1,
            y: containerSize.height / 2 - 1,
            width: 2,
            height: 2,
        )
        ZStack {
            Color.black.opacity(Self.standardDimOpacity)
            TutorialMessageModal(
                text: TutorialStepCopy.text(for: .done),
                progress: (
                    current: TutorialCoordinator.totalProgressSteps,
                    total: TutorialCoordinator.totalProgressSteps,
                ),
                showsSkip: false,
                showsNext: true,
                nextButtonLabelKey: "tutorial_button_finish",
                phoneOrientationAngle: nil,
                placement: .centered,
                targetRect: centerRect,
                containerSize: containerSize,
                safeAreaInsets: safeAreaInsets,
                onSkip: { coord.finishAndCleanup() },
                onNext: { coord.finishAndCleanup() },
            )
        }
    }

    @ViewBuilder
    private func anchoredContent(
        step: TutorialStep,
        rect rawRect: CGRect,
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets,
    ) -> some View {
        let rect = rawRect.insetBy(dx: Self.cutoutInset, dy: Self.cutoutInset)
        let opacity = Self.dimOpacity(for: step)
        let placement = TutorialMessageModal.placement(for: rect, containerSize: containerSize)
        let progress = coord.progress(for: step) ?? (current: 1, total: TutorialCoordinator.totalProgressSteps)
        ZStack {
            DimmedMask(
                containerSize: containerSize,
                cutout: rect,
                cornerRadius: Self.cutoutCornerRadius,
                opacity: opacity,
            )
            if opacity == 0 {
                SpotlightRing(
                    cutout: rect,
                    cornerRadius: Self.cutoutCornerRadius,
                )
            }
            TutorialMessageModal(
                text: TutorialStepCopy.text(for: step),
                progress: progress,
                showsSkip: true,
                showsNext: TutorialMessageModal.showsNext(for: step),
                nextButtonLabelKey: "tutorial_button_next",
                phoneOrientationAngle: PhoneOrientationGuide.targetRotation(for: step),
                placement: placement,
                targetRect: rect,
                containerSize: containerSize,
                safeAreaInsets: safeAreaInsets,
                onSkip: { coord.cancel() },
                onNext: { coord.advance() },
            )
        }
    }

    static func dimOpacity(for step: TutorialStep) -> Double {
        switch step {
            case .captureGuidePortrait,
                 .captureGuideLeft,
                 .captureGuideRight,
                 .afterCameraGuide,
                 .afterCameraInProgress,
                 .backToHome,
                 .backToHome2:
                0

            default:
                standardDimOpacity
        }
    }

    private func anchorID(for step: TutorialStep) -> String? {
        switch step {
            case .captureGuidePortrait,
                 .captureGuideLeft,
                 .captureGuideRight:
                TutorialAnchorID.cameraShutter

            case .backToHome:
                TutorialAnchorID.cameraHomeButton

            case .tapPairCard:
                TutorialAnchorID.homeFirstPairCard

            case .afterCameraGuide:
                TutorialAnchorID.afterShutter

            case .afterCameraInProgress:
                nil

            case .backToHome2:
                TutorialAnchorID.afterHomeButton

            case .enterSelectionMode:
                TutorialAnchorID.homeSelectionToggle

            case .selectionShare:
                TutorialAnchorID.selectionShare

            case .selectionSave:
                TutorialAnchorID.selectionSave

            case .selectionDelete:
                TutorialAnchorID.selectionDelete

            case .selectionExport:
                TutorialAnchorID.selectionExport

            case .goSettings:
                TutorialAnchorID.homeSettings

            case .done:
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

private struct SpotlightRing: View {
    private static let lineWidth: CGFloat = 4
    private static let ringOpacity: Double = 0.95

    let cutout: CGRect
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.45), lineWidth: Self.lineWidth + 2)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(Self.ringOpacity), lineWidth: Self.lineWidth)
        }
        .frame(width: cutout.width, height: cutout.height)
        .position(x: cutout.midX, y: cutout.midY)
        .shadow(color: .black.opacity(0.4), radius: 6)
        .allowsHitTesting(false)
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
