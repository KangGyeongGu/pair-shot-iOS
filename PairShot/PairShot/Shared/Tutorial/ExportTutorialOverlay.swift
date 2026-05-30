import SwiftUI

struct ExportTutorialOverlay: View {
    private static let cutoutInset: CGFloat = -8
    private static let cutoutCornerRadius: CGFloat = 12
    private static let dimOpacity: Double = 0.78

    @Environment(ExportTutorialCoordinator.self) private var coord
    let anchors: [String: Anchor<CGRect>]
    let slotZeroAnchor: Anchor<CGRect>?

    var body: some View {
        GeometryReader { proxy in
            content(in: proxy)
        }
        .ignoresSafeArea()
        .allowsHitTesting(coord.isActive)
    }

    @ViewBuilder
    private func content(in proxy: GeometryProxy) -> some View {
        if let step = coord.current, let anchor = resolveAnchor(for: step) {
            anchoredContent(
                step: step,
                rect: proxy[anchor],
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
            )
        } else if let step = coord.current {
            fallbackContent(
                step: step,
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
            )
        }
    }

    private func resolveAnchor(for step: ExportTutorialStep) -> Anchor<CGRect>? {
        if step == .presetsAutoSave { return slotZeroAnchor }
        return anchors[anchorID(for: step)]
    }

    @ViewBuilder
    private func fallbackContent(
        step: ExportTutorialStep,
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets,
    ) -> some View {
        let centerRect = CGRect(
            x: containerSize.width / 2 - 1,
            y: containerSize.height / 2 - 1,
            width: 2,
            height: 2,
        )
        let progress = coord.progress(for: step)
        let isLast = step == ExportTutorialStep.allCases.last
        ZStack {
            Color.black.opacity(Self.dimOpacity)
            TutorialMessageModal(
                text: AttributedString(ExportTutorialStepCopy.text(for: step)),
                progress: progress,
                showsSkip: false,
                showsNext: true,
                nextButtonLabelKey: isLast ? "tutorial_button_finish" : "tutorial_button_next",
                phoneOrientationAngle: nil,
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
            SpotlightDimmedMask(
                containerSize: containerSize,
                cutout: rect,
                cornerRadius: Self.cutoutCornerRadius,
                opacity: Self.dimOpacity,
            )
            TutorialMessageModal(
                text: AttributedString(ExportTutorialStepCopy.text(for: step)),
                progress: progress,
                showsSkip: false,
                showsNext: true,
                nextButtonLabelKey: isLast ? "tutorial_button_finish" : "tutorial_button_next",
                phoneOrientationAngle: nil,
                placement: placement,
                targetRect: rect,
                containerSize: containerSize,
                safeAreaInsets: safeAreaInsets,
                anchorGap: TutorialMessageModal.defaultAnchorGap,
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
            case .presets: ExportTutorialAnchorID.presets
            case .presetsAutoSave: ExportTutorialAnchorID.presetsDefault
        }
    }
}

struct ExportTutorialOverlayModifier: ViewModifier {
    @State private var slotZeroAnchor: Anchor<CGRect>?

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(ExportPresetSlotZeroAnchorKey.self) { value in
                slotZeroAnchor = value
            }
            .overlayPreferenceValue(SpotlightAnchorKey.self) { anchors in
                ExportTutorialOverlay(anchors: anchors, slotZeroAnchor: slotZeroAnchor)
            }
    }
}

extension View {
    func exportTutorialOverlay() -> some View {
        modifier(ExportTutorialOverlayModifier())
    }
}
