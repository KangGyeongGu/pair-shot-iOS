import SwiftUI

struct AfterCameraStrip: View {
    @Environment(AppEnvironment.self) private var env

    let pairs: [PhotoPair]
    @Binding var selectedPairId: UUID?

    @State private var scrolledId: UUID?

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
                            isActive: pair.id == scrolledId
                        )
                        .id(pair.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            scrolledId = pair.id
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, sideInset, for: .scrollContent)
            .contentMargins(.vertical, StripDesign.stripPaddingVertical, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledId, anchor: .center)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appLetterbox)
        .onAppear {
            if scrolledId == nil { scrolledId = selectedPairId }
        }
        .onChange(of: selectedPairId) { _, newValue in
            if scrolledId != newValue { scrolledId = newValue }
        }
        .onChange(of: scrolledId) { _, newValue in
            if selectedPairId != newValue {
                selectedPairId = newValue
                env.hapticService.impact(.light)
            }
        }
    }
}
