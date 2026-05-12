import SwiftUI

struct BeforeCameraStrip: View {
    let pendingPairs: [PhotoPair]
    @Binding var selectedPairId: UUID?

    var body: some View {
        Group {
            if pendingPairs.isEmpty {
                emptyState
            } else {
                strip
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.appLetterbox)
    }

    private var strip: some View {
        GeometryReader { proxy in
            let sideInset = max(
                StripDesign.stripPaddingHorizontal,
                (proxy.size.width - StripDesign.cardWidth) / 2
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: StripDesign.cardSpacing) {
                    ForEach(pendingPairs) { pair in
                        StripCard(pair: pair, isActive: pair.id == selectedPairId)
                            .id(pair.id)
                            .scrollTransition(.interactive, axis: .horizontal) { effect, phase in
                                effect.scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, sideInset, for: .scrollContent)
            .contentMargins(.vertical, StripDesign.stripPaddingVertical, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedPairId, anchor: .center)
        }
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
