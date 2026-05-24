import SwiftUI

struct TutorialMessageModal: View {
    enum Placement {
        case top
        case bottom
        case centered
    }

    struct CardCenterYInput {
        let placement: Placement
        let targetRect: CGRect
        let containerSize: CGSize
        let safeAreaInsets: EdgeInsets
        let cardHeight: CGFloat
        let gap: CGFloat
        let edgePadding: CGFloat
    }

    private static let horizontalPadding: CGFloat = 16
    private static let verticalEdgePadding: CGFloat = 20
    static let defaultAnchorGap: CGFloat = 36
    private static let cornerRadius: CGFloat = 16
    private static let cardPadding: CGFloat = 16
    private static let messageVerticalPadding: CGFloat = 12
    private static let estimatedHeight: CGFloat = 150
    private static let maxCardWidth: CGFloat = 280
    private static let maxHeightRatio: CGFloat = 0.7

    let text: AttributedString
    let progress: (current: Int, total: Int)
    let showsSkip: Bool
    let showsNext: Bool
    let nextButtonLabelKey: String.LocalizationValue
    let phoneOrientationAngle: Angle?
    let placement: Placement
    let targetRect: CGRect
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let anchorGap: CGFloat
    let onSkip: () -> Void
    let onNext: () -> Void

    @State private var measuredHeight: CGFloat = Self.estimatedHeight
    @State private var showSkipConfirm = false
    @State private var contentVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let availableWidth = max(0, containerSize.width - Self.horizontalPadding * 2)
        let width = min(availableWidth, Self.maxCardWidth)
        let maxHeight = Self.cardMaxHeight(
            containerSize: containerSize,
            safeAreaInsets: safeAreaInsets,
            edgePadding: Self.verticalEdgePadding,
        )
        let centerY = Self.cardCenterY(input: CardCenterYInput(
            placement: placement,
            targetRect: targetRect,
            containerSize: containerSize,
            safeAreaInsets: safeAreaInsets,
            cardHeight: min(measuredHeight, maxHeight),
            gap: anchorGap,
            edgePadding: Self.verticalEdgePadding,
        ))
        card
            .frame(width: width)
            .frame(maxHeight: maxHeight)
            .background(heightReader)
            .opacity(contentVisible ? 1 : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: centerY)
            .position(x: containerSize.width / 2, y: centerY)
            .onChange(of: centerY) { _, _ in
                guard !reduceMotion else { return }
                contentVisible = false
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(.easeIn(duration: 0.15)) {
                        contentVisible = true
                    }
                }
            }
            .onPreferenceChange(ModalHeightKey.self) { newValue in
                if abs(newValue - measuredHeight) > 0.5 {
                    withTransaction(Transaction(animation: nil)) {
                        measuredHeight = newValue
                    }
                }
            }
            .alert(
                String(localized: "tutorial_skip_confirm_title"),
                isPresented: $showSkipConfirm,
            ) {
                Button(String(localized: "common_button_cancel"), role: .cancel) {}
                Button(String(localized: "tutorial_skip_confirm_end"), role: .destructive) {
                    onSkip()
                }
            }
    }

    private var card: some View {
        VStack(spacing: 12) {
            topRow
            ViewThatFits(in: .vertical) {
                messageContent
                    .padding(.vertical, Self.messageVerticalPadding)
                ScrollView(.vertical, showsIndicators: false) {
                    messageContent
                        .padding(.vertical, Self.messageVerticalPadding)
                }
            }
            if showsNext {
                bottomRow
            }
        }
        .padding(Self.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4),
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5),
        )
    }

    private var messageContent: some View {
        VStack(spacing: 12) {
            if let rotation = phoneOrientationAngle {
                PhoneOrientationGuide(targetRotation: rotation)
                    .frame(maxWidth: .infinity)
            }
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .transaction { $0.animation = nil }
        }
        .frame(maxWidth: .infinity)
    }

    private var topRow: some View {
        HStack(spacing: 12) {
            Text("\(progress.current) / \(progress.total)")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .transaction { $0.animation = nil }
            Spacer(minLength: 0)
            if showsSkip {
                Button {
                    showSkipConfirm = true
                } label: {
                    Text(String(localized: "tutorial_button_skip"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomRow: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Button(action: onNext) {
                Text(String(localized: nextButtonLabelKey))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .transaction { $0.animation = nil }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var heightReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ModalHeightKey.self, value: proxy.size.height)
        }
    }

    static func placement(for targetRect: CGRect, containerSize: CGSize) -> Placement {
        targetRect.midY > containerSize.height / 2 ? .top : .bottom
    }

    static func showsNext(for step: TutorialStep) -> Bool {
        switch step {
            case .afterCameraStrip,
                 .selectionShare,
                 .selectionSave,
                 .selectionDelete,
                 .selectionExport,
                 .done:
                true

            default:
                false
        }
    }

    static func cardMaxHeight(
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets,
        edgePadding: CGFloat,
    ) -> CGFloat {
        let usableHeight = containerSize.height - safeAreaInsets.top - safeAreaInsets.bottom - edgePadding * 2
        return max(120, usableHeight * maxHeightRatio)
    }

    static func cardCenterY(input: CardCenterYInput) -> CGFloat {
        let halfHeight = input.cardHeight / 2
        let topLimit = input.safeAreaInsets.top + input.edgePadding + halfHeight
        let bottomLimit = input.containerSize.height - input.safeAreaInsets.bottom - input.edgePadding - halfHeight

        guard bottomLimit >= topLimit else {
            return max(topLimit, input.containerSize.height / 2)
        }

        if input.placement == .centered {
            return input.containerSize.height / 2
        }

        let preferredY: CGFloat = switch input.placement {
            case .top: input.targetRect.minY - input.gap - halfHeight
            case .bottom: input.targetRect.maxY + input.gap + halfHeight
            case .centered: input.containerSize.height / 2
        }

        let fitsPreferred = preferredY >= topLimit && preferredY <= bottomLimit
        if fitsPreferred {
            return preferredY
        }

        let spaceAbove = input.targetRect.minY - input.safeAreaInsets.top - input.edgePadding - input.gap
        let spaceBelow = input.containerSize.height - input.safeAreaInsets.bottom - input.edgePadding
            - input.gap - input.targetRect.maxY
        if spaceAbove < input.cardHeight, spaceBelow < input.cardHeight {
            return input.containerSize.height / 2
        }
        let fallbackY: CGFloat = if spaceAbove >= spaceBelow {
            input.targetRect.minY - input.gap - halfHeight
        } else {
            input.targetRect.maxY + input.gap + halfHeight
        }
        return min(max(fallbackY, topLimit), bottomLimit)
    }
}

private struct ModalHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 130

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
