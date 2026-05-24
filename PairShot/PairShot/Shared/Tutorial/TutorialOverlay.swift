import SwiftUI

struct TutorialOverlay: View {
    private static let cutoutInset: CGFloat = -8
    private static let stripHorizontalInset: CGFloat = 40
    private static let cutoutCornerRadius: CGFloat = 12
    private static let standardDimOpacity: Double = 0.55

    @Environment(TutorialCoordinator.self) private var coord
    let anchors: [String: Anchor<CGRect>]

    var body: some View {
        GeometryReader { proxy in
            content(in: proxy)
        }
        .ignoresSafeArea()
        .allowsHitTesting(Self.shouldBlockHitTesting(step: coord.current))
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
        } else if coord.current == .afterCameraStripPeekClose {
            EmptyView()
        } else if let step = coord.current, step != .afterCameraInProgress {
            fallbackContent(
                step: step,
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
            )
        }
    }

    @ViewBuilder
    private func fallbackContent(
        step: TutorialStep,
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets,
    ) -> some View {
        let centerRect = CGRect(
            x: containerSize.width / 2 - 1,
            y: containerSize.height / 2 - 1,
            width: 2,
            height: 2,
        )
        let progress = coord.progress(for: step) ?? (current: 1, total: TutorialCoordinator.totalProgressSteps)
        let fallbackOpacity = Self.dimOpacity(for: step)
        ZStack {
            if fallbackOpacity > 0 {
                Color.black.opacity(fallbackOpacity)
            }
            TutorialMessageModal(
                text: TutorialStepCopy.attributedText(for: step),
                progress: progress,
                showsSkip: true,
                showsNext: TutorialMessageModal.showsNext(for: step),
                nextButtonLabelKey: "tutorial_button_next",
                phoneOrientationAngle: PhoneOrientationGuide.targetRotation(for: step),
                placement: .centered,
                targetRect: centerRect,
                containerSize: containerSize,
                safeAreaInsets: safeAreaInsets,
                anchorGap: TutorialMessageModal.defaultAnchorGap,
                onSkip: { coord.cancel() },
                onNext: { coord.advance() },
            )
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
                text: TutorialStepCopy.attributedText(for: .done),
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
                anchorGap: TutorialMessageModal.defaultAnchorGap,
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
        let baseRect = rawRect.insetBy(dx: Self.cutoutInset, dy: Self.cutoutInset)
        let rect: CGRect = step == .afterCameraStrip
            ? baseRect.insetBy(dx: Self.stripHorizontalInset, dy: 0)
            : baseRect
        let opacity = Self.dimOpacity(for: step)
        let placement = TutorialMessageModal.placement(for: rect, containerSize: containerSize)
        let progress = coord.progress(for: step) ?? (current: 1, total: TutorialCoordinator.totalProgressSteps)
        ZStack {
            if step != .afterCameraStripLongPressHint {
                SpotlightDimmedMask(
                    containerSize: containerSize,
                    cutout: rect,
                    cornerRadius: Self.cutoutCornerRadius,
                    opacity: opacity,
                )
            }
            if opacity == 0 || step == .afterCameraStrip || step == .afterCameraStripLongPressHint {
                SpotlightRing(
                    cutout: rect,
                    cornerRadius: Self.cutoutCornerRadius,
                )
            }
            TutorialMessageModal(
                text: TutorialStepCopy.attributedText(for: step),
                progress: progress,
                showsSkip: true,
                showsNext: TutorialMessageModal.showsNext(for: step),
                nextButtonLabelKey: "tutorial_button_next",
                phoneOrientationAngle: PhoneOrientationGuide.targetRotation(for: step),
                placement: placement,
                targetRect: rect,
                containerSize: containerSize,
                safeAreaInsets: safeAreaInsets,
                anchorGap: Self.anchorGap(for: step),
                onSkip: { coord.cancel() },
                onNext: { coord.advance() },
            )
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

            case .afterCameraStrip:
                TutorialAnchorID.afterStrip

            case .afterCameraStripLongPressHint:
                TutorialAnchorID.afterActiveCard

            case .afterCameraStripPeekClose:
                nil

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

    static func shouldBlockHitTesting(step: TutorialStep?) -> Bool {
        guard let step else { return false }
        return step != .afterCameraInProgress
    }

    static func anchorGap(for step: TutorialStep) -> CGFloat {
        switch step {
            case .afterCameraGuide: 220
            default: TutorialMessageModal.defaultAnchorGap
        }
    }

    static func dimOpacity(for step: TutorialStep) -> Double {
        switch step {
            case .captureGuidePortrait,
                 .captureGuideLeft,
                 .captureGuideRight,
                 .afterCameraGuide,
                 .afterCameraInProgress,
                 .afterCameraStripLongPressHint,
                 .afterCameraStripPeekClose,
                 .backToHome,
                 .backToHome2:
                0

            default:
                standardDimOpacity
        }
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
