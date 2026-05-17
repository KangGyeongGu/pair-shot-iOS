import SwiftUI

struct TutorialMessageModal: View {
    enum Placement {
        case top
        case bottom
        case centered
    }

    private static let horizontalPadding: CGFloat = 16
    private static let verticalEdgePadding: CGFloat = 20
    private static let anchorGap: CGFloat = 36
    private static let cornerRadius: CGFloat = 16
    private static let cardPadding: CGFloat = 16
    private static let estimatedHeight: CGFloat = 130
    private static let maxCardWidth: CGFloat = 280

    let text: String
    let progress: (current: Int, total: Int)
    let showsSkip: Bool
    let showsNext: Bool
    let nextButtonLabelKey: String.LocalizationValue
    let phoneOrientationAngle: Angle?
    let placement: Placement
    let targetRect: CGRect
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let onSkip: () -> Void
    let onNext: () -> Void

    @State private var measuredHeight: CGFloat = Self.estimatedHeight

    var body: some View {
        let availableWidth = max(0, containerSize.width - Self.horizontalPadding * 2)
        let width = min(availableWidth, Self.maxCardWidth)
        let centerY = Self.cardCenterY(
            placement: placement,
            targetRect: targetRect,
            containerSize: containerSize,
            safeAreaInsets: safeAreaInsets,
            cardHeight: measuredHeight,
            gap: Self.anchorGap,
            edgePadding: Self.verticalEdgePadding,
        )
        card
            .frame(width: width)
            .background(heightReader)
            .position(x: containerSize.width / 2, y: centerY)
            .onPreferenceChange(ModalHeightKey.self) { newValue in
                if abs(newValue - measuredHeight) > 0.5 {
                    measuredHeight = newValue
                }
            }
    }

    private var card: some View {
        VStack(spacing: 12) {
            topRow
            messageContent
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
        }
        .frame(maxWidth: .infinity)
    }

    private var topRow: some View {
        HStack(spacing: 12) {
            Text("\(progress.current) / \(progress.total)")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if showsSkip {
                Button(action: onSkip) {
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
            case .selectionShare,
                 .selectionSave,
                 .selectionDelete,
                 .selectionExport,
                 .done:
                true

            default:
                false
        }
    }

    static func cardCenterY(
        placement: Placement,
        targetRect: CGRect,
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets,
        cardHeight: CGFloat,
        gap: CGFloat,
        edgePadding: CGFloat,
    ) -> CGFloat {
        let halfHeight = cardHeight / 2
        let topLimit = safeAreaInsets.top + edgePadding + halfHeight
        let bottomLimit = containerSize.height - safeAreaInsets.bottom - edgePadding - halfHeight

        guard bottomLimit >= topLimit else {
            return max(topLimit, containerSize.height / 2)
        }

        if placement == .centered {
            return containerSize.height / 2
        }

        let preferredY: CGFloat = switch placement {
            case .top: targetRect.minY - gap - halfHeight
            case .bottom: targetRect.maxY + gap + halfHeight
            case .centered: containerSize.height / 2
        }

        let fitsPreferred = preferredY >= topLimit && preferredY <= bottomLimit
        if fitsPreferred {
            return preferredY
        }

        let spaceAbove = targetRect.minY - safeAreaInsets.top - edgePadding - gap
        let spaceBelow = containerSize.height - safeAreaInsets.bottom - edgePadding - gap - targetRect.maxY
        let fallbackY: CGFloat = if spaceAbove >= spaceBelow {
            targetRect.minY - gap - halfHeight
        } else {
            targetRect.maxY + gap + halfHeight
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
