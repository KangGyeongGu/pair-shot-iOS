import SwiftUI

struct TutorialFinishView: View {
    private static let cardMaxWidth: CGFloat = 320
    private static let dimOpacity: Double = 0.55

    let message: String
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(Self.dimOpacity)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Button(action: onFinish) {
                    Text(String(localized: "common_button_confirm"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: Self.cardMaxWidth)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4),
            )
            .padding(.horizontal, 24)
        }
    }
}
