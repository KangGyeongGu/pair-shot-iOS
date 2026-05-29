import SwiftUI
import UIKit

struct PairPreviewView: View {
    let pair: PhotoPair
    let actions: PairCardActions

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PairPreviewViewModel?

    var body: some View {
        ZStack {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { ensureViewModel() }
    }

    init(pair: PhotoPair, actions: PairCardActions) {
        self.pair = pair
        self.actions = actions
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makePairPreviewViewModel(pair: pair)
            Task { await viewModel?.loadPreview() }
        }
    }

    private func content(for viewModel: PairPreviewViewModel) -> some View {
        VStack(spacing: 0) {
            BannerAdSlot()
                .padding(.top, 28)
            previewArea(for: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottom) {
            PairPreviewBottomBar(items: actionItems())
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
        .modifier(PairPreviewSheetModifiers(viewModel: viewModel))
    }

    @ViewBuilder
    private func previewArea(for viewModel: PairPreviewViewModel) -> some View {
        if let image = viewModel.livePreviewImage {
            PairPreviewImage(image: image, viewModel: viewModel)
        } else if viewModel.isRendering {
            ProgressView()
        } else {
            PairPreviewEmptyState()
        }
    }

    private func actionItems() -> [PairShotActionItem] {
        [
            PairShotActionItem(
                title: String(localized: "common_button_share"),
                systemImage: "square.and.arrow.up",
                action: { actions.onShare(pair) },
            ),
            PairShotActionItem(
                title: String(localized: "common_button_save_to_device"),
                systemImage: "arrow.down.to.line",
                action: { actions.onExport(pair) },
            ),
            PairShotActionItem(
                title: String(localized: "pair_card_menu_delete_after"),
                systemImage: "trash.slash",
                role: .destructive,
                action: {
                    dismiss()
                    actions.onRequestAfterDeletion(pair)
                },
            ),
            PairShotActionItem(
                title: String(localized: "common_button_delete"),
                systemImage: "trash",
                role: .destructive,
                action: {
                    dismiss()
                    actions.onRequestPairDeletion(pair)
                },
            ),
        ]
    }
}

private struct PairPreviewImage: View {
    let image: UIImage
    @Bindable var viewModel: PairPreviewViewModel

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(viewModel.zoomScale)
                .offset(viewModel.panOffset)
                .gesture(SimultaneousGesture(pinchGesture, dragGesture))
                .onTapGesture(count: 2) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        viewModel.resetZoom()
                    }
                }
                .animation(.easeOut(duration: 0.18), value: viewModel.zoomScale)
                .onAppear { viewModel.updateContainerSize(geometry.size) }
                .onChange(of: geometry.size) { _, newSize in
                    viewModel.updateContainerSize(newSize)
                }
        }
        .clipped()
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                viewModel.onPinchChanged(
                    value.magnification,
                    anchor: CGPoint(x: value.startAnchor.x, y: value.startAnchor.y),
                )
            }
            .onEnded { value in
                viewModel.onPinchEnded(
                    value.magnification,
                    anchor: CGPoint(x: value.startAnchor.x, y: value.startAnchor.y),
                )
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in viewModel.onDragChanged(translation: value.translation) }
            .onEnded { value in viewModel.onDragEnded(translation: value.translation) }
    }
}

private struct PairPreviewBottomBar: View {
    let items: [PairShotActionItem]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                actionColumn(item)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 60)
        .adaptiveGlass(in: Capsule(style: .continuous), kind: .regular)
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5),
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 3)
    }

    private func actionColumn(_ item: PairShotActionItem) -> some View {
        Button(role: item.role, action: item.action) {
            VStack(spacing: 4) {
                Image(systemName: item.systemImage)
                    .font(.title3)
                    .frame(height: 24)
                Text(item.title)
                    .font(.appLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(item.role == .destructive ? Color.appSnackbarError : Color.primary)
        .opacity(item.isEnabled ? 1 : 0.38)
        .disabled(!item.isEnabled)
        .accessibilityLabel(item.title)
    }
}

private struct PairPreviewEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(.secondary)
            Text(String(localized: "pair_preview_no_composite"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

private struct PairPreviewSheetModifiers: ViewModifier {
    @Bindable var viewModel: PairPreviewViewModel

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } },
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "common_dialog_error_title"),
                isPresented: errorBinding,
                presenting: viewModel.errorMessage,
            ) { _ in
                Button(String(localized: "common_button_confirm"), role: .cancel) {
                    viewModel.clearError()
                }
            } message: { message in
                Text(message)
            }
    }
}
