import SwiftUI

struct PairPickerCardView: View {
    let pair: PhotoPair
    let isAlreadyInAlbum: Bool
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HomePairCardView(
                pair: pair,
                isSelectionMode: false,
                isSelected: false,
            )

            if isAlreadyInAlbum {
                alreadyAddedOverlay
            } else if isSelected {
                selectedCheckmark
                    .padding(8)
            }
        }
        .overlay(borderOverlay)
        .overlay(selectionTint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var alreadyAddedOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.appLetterbox.opacity(0.45))
            Text(String(localized: "pair_picker_already_added"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .multilineTextAlignment(.center)
        }
        .allowsHitTesting(false)
    }

    private var selectedCheckmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.title3)
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.white, Color.accentColor)
            .background(Circle().fill(.black.opacity(0.35)))
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if isAlreadyInAlbum {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    Color(uiColor: .separator).opacity(0.8),
                    lineWidth: 2,
                )
                .allowsHitTesting(false)
        } else if isSelected {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var selectionTint: some View {
        if isSelected, !isAlreadyInAlbum {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.18))
                .allowsHitTesting(false)
        }
    }

    private var accessibilityLabelText: String {
        let base = HomePairCardView.accessibilityLabel(
            for: pair,
            isSelected: false,
            isSelectionMode: false,
        )
        if isAlreadyInAlbum {
            return base + ", " + String(localized: "pair_picker_already_added")
        }
        if isSelected {
            return base + ", " + String(localized: "common_state_selected")
        }
        return base
    }
}
