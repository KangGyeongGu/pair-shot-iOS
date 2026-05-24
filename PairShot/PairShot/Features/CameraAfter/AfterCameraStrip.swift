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

    private var peekCloseHintInfo: PeekCloseHintInfo? {
        let coord = env.tutorialCoordinator
        guard coord.isAtStep(.afterCameraStripPeekClose) else { return nil }
        let progress = coord.progress(for: .afterCameraStripPeekClose)
            ?? (current: 1, total: TutorialCoordinator.totalProgressSteps)
        return PeekCloseHintInfo(
            text: TutorialStepCopy.text(for: .afterCameraStripPeekClose),
            progressCurrent: progress.current,
            progressTotal: progress.total,
        )
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
                        Label("크게 보기", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                }
            },
            preview: {
                if isActive {
                    ContextPreviewImage(
                        pair: pair,
                        photoLibrary: env.photoLibrary,
                        onPreviewAppear: handlePreviewAppear,
                        onPreviewDisappear: handlePreviewDisappear,
                        peekCloseHint: peekCloseHintInfo,
                    )
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

    private func handlePreviewAppear() {
        if env.tutorialCoordinator.isAtStep(.afterCameraStripLongPressHint) {
            env.tutorialCoordinator.advance()
        }
    }

    private func handlePreviewDisappear() {
        if env.tutorialCoordinator.isAtStep(.afterCameraStripPeekClose) {
            env.tutorialCoordinator.advance()
        }
    }
}

struct PeekCloseHintInfo: Equatable {
    let text: String
    let progressCurrent: Int
    let progressTotal: Int
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
    let onPreviewAppear: () -> Void
    let onPreviewDisappear: () -> Void
    let peekCloseHint: PeekCloseHintInfo?

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .frame(width: 220, height: 220)
            }
            if let hint = peekCloseHint {
                VStack {
                    Spacer()
                    hintCard(hint: hint)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
                .allowsHitTesting(false)
            }
        }
        .task(id: pair.id) {
            await load()
        }
        .onAppear { onPreviewAppear() }
        .onDisappear { onPreviewDisappear() }
    }

    private func hintCard(hint: PeekCloseHintInfo) -> some View {
        VStack(spacing: 8) {
            Text("\(hint.progressCurrent) / \(hint.progressTotal)")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(hint.text)
                .font(.callout)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4),
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5),
        )
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
