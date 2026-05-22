import SwiftUI

struct AfterCameraStrip: View {
    @Environment(AppEnvironment.self) private var env

    let pairs: [PhotoPair]
    @Binding var selectedPairId: UUID?
    let stripZoneHeight: CGFloat
    var onPeek: ((UUID) -> Void)?

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
                        card(for: pair)
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

    @ViewBuilder
    private func card(for pair: PhotoPair) -> some View {
        let isActive = pair.id == selectedPairId
        StripCard(
            pair: pair,
            isActive: isActive,
            stripZoneHeight: stripZoneHeight,
        )
        .id(pair.id)
        .contentShape(Rectangle())
        .modifier(ActiveCardTutorialAnchor(isActive: isActive))
        .onTapGesture {
            selectedPairId = pair.id
        }
        .contextMenu(
            menuItems: {
                if isActive {
                    Button {
                        handlePeek(pair.id)
                    } label: {
                        Label("BEFORE 확대해서 보기", systemImage: "plus.magnifyingglass")
                    }
                }
            },
            preview: {
                if isActive {
                    ContextPreviewImage(pair: pair, photoLibrary: env.photoLibrary)
                } else {
                    EmptyView()
                }
            },
        )
        .scrollTransition(.interactive, axis: .horizontal) { effect, phase in
            effect.scaleEffect(phase.isIdentity ? 1.0 : 0.95)
        }
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private func handlePeek(_ pairId: UUID) {
        onPeek?(pairId)
    }
}

private struct ActiveCardTutorialAnchor: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.tutorialAnchor(TutorialAnchorID.afterActiveCard)
        } else {
            content
        }
    }
}

private struct ContextPreviewImage: View {
    let pair: PhotoPair
    let photoLibrary: PhotoLibraryService

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .frame(width: 220, height: 220)
            }
        }
        .task(id: pair.id) {
            await load()
        }
    }

    private func load() async {
        guard let identifier = pair.beforePhotoLocalIdentifier, !identifier.isEmpty else {
            return
        }
        let loaded = await photoLibrary.requestPreviewImage(
            localIdentifier: identifier,
            targetSize: CGSize(width: 1024, height: 1024),
        )
        guard pair.beforePhotoLocalIdentifier == identifier else { return }
        image = loaded
    }
}
