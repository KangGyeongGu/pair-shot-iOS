import SwiftUI

struct BeforeCameraStrip: View {
    let pendingPairs: [PhotoPair]
    let activePairId: UUID?
    let stripZoneHeight: CGFloat

    @State private var scrolledId: UUID?

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
                    ForEach(pendingPairs) { pair in
                        StripCard(
                            pair: pair,
                            isActive: pair.id == activePairId,
                            stripZoneHeight: stripZoneHeight,
                        )
                        .id(pair.id)
                        .scrollTransition(.interactive, axis: .horizontal) { effect, phase in
                            effect.scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                        }
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
            .scrollPosition(id: $scrolledId, anchor: .center)
        }
        .onChange(of: activePairId, initial: true) { _, newId in
            withAnimation(.smooth) { scrolledId = newId }
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
