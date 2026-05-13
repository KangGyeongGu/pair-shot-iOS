import SwiftUI

struct AfterCameraStrip: View {
    @Environment(AppEnvironment.self) private var env

    let pairs: [PhotoPair]
    @Binding var selectedPairId: UUID?

    var body: some View {
        GeometryReader { proxy in
            let sideInset = max(
                StripDesign.stripPaddingHorizontal,
                (proxy.size.width - StripDesign.cardWidth) / 2
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: StripDesign.cardSpacing) {
                    ForEach(pairs) { pair in
                        StripCard(
                            pair: pair,
                            isActive: pair.id == selectedPairId
                        )
                        .id(pair.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPairId = pair.id
                        }
                        .scrollTransition(.interactive, axis: .horizontal) { effect, phase in
                            effect.scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                        }
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, sideInset, for: .scrollContent)
            .contentMargins(.vertical, StripDesign.stripPaddingVertical, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedPairId, anchor: .center)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appLetterbox)
        .onChange(of: selectedPairId) {
            env.hapticService.impact(.light)
        }
    }
}
