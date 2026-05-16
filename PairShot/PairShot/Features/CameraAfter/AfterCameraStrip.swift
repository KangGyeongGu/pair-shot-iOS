import SwiftUI

struct AfterCameraStrip: View {
    @Environment(AppEnvironment.self) private var env

    let pairs: [PhotoPair]
    @Binding var selectedPairId: UUID?
    let stripZoneHeight: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = StripDesign.cardWidth(stripHeight: stripZoneHeight)
            let sideInset = max(
                StripDesign.stripPaddingHorizontal,
                (proxy.size.width - cardWidth) / 2,
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(
                    alignment: .center,
                    spacing: StripDesign.cardSpacing(stripHeight: stripZoneHeight),
                ) {
                    ForEach(pairs) { pair in
                        StripCard(
                            pair: pair,
                            isActive: pair.id == selectedPairId,
                            stripZoneHeight: stripZoneHeight,
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
            .contentMargins(
                .vertical,
                StripDesign.paddingVertical(stripHeight: stripZoneHeight),
                for: .scrollContent,
            )
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
