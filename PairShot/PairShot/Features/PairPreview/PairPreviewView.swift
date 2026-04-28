import SwiftUI
import UIKit

struct PairPreviewView: View {
    let pair: PhotoPair

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PairPreviewViewModel?

    init(pair: PhotoPair) {
        self.pair = pair
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let viewModel {
                    content(for: viewModel)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .task { ensureViewModel() }
        .task { await observeEvents() }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makePairPreviewViewModel(pair: pair)
            Task { await viewModel?.loadPreview() }
        }
    }

    private func observeEvents() async {
        while viewModel == nil {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let viewModel else { return }
        for await event in viewModel.events {
            switch event {
                case .dismiss:
                    dismiss()
            }
        }
    }

    private func content(for viewModel: PairPreviewViewModel) -> some View {
        VStack(spacing: 0) {
            previewArea(for: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            BannerAdSlot()
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

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel?.dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(String(localized: "common_button_close"))
        }
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
                .gesture(pinchGesture)
                .onTapGesture(count: 2) { viewModel.resetZoom() }
                .animation(.easeOut(duration: 0.18), value: viewModel.zoomScale)
        }
        .clipped()
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in viewModel.onPinchChanged(value) }
            .onEnded { value in viewModel.onPinchEnded(value) }
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

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "common_dialog_error_title"),
                isPresented: errorBinding,
                presenting: viewModel.errorMessage
            ) { _ in
                Button(String(localized: "common_button_confirm"), role: .cancel) {
                    viewModel.clearError()
                }
            } message: { message in
                Text(message)
            }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }
}
