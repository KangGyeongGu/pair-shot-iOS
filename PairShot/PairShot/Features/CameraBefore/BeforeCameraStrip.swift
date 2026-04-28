import SwiftUI

struct BeforeCameraStrip: View {
    let pendingPairs: [PhotoPair]

    var body: some View {
        Group {
            if pendingPairs.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: StripDesign.cardSpacing) {
                        ForEach(pendingPairs) { pair in
                            StripCard(pair: pair, isActive: false)
                        }
                    }
                    .padding(.horizontal, StripDesign.stripPaddingHorizontal)
                    .padding(.vertical, StripDesign.stripPaddingVertical)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.appLetterbox)
    }

    private var emptyState: some View {
        Text(String(localized: "camera_strip_empty"))
            .font(.appCaption)
            .foregroundStyle(.white.opacity(0.65))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
}
