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
        .modifier(PairPreviewSheetModifiers(viewModel: viewModel, pair: pair))
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
            .accessibilityLabel(String(localized: "닫기"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    viewModel?.onShareTapped()
                } label: {
                    Label(String(localized: "공유"), systemImage: "square.and.arrow.up")
                }
                Button {
                    viewModel?.onRetakeTapped()
                } label: {
                    Label(String(localized: "재촬영"), systemImage: "camera.rotate")
                }
                Button(role: .destructive) {
                    viewModel?.onDeleteTapped()
                } label: {
                    Label(String(localized: "삭제"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(String(localized: "더 보기"))
            .disabled(viewModel == nil)
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
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text(String(localized: "합성본이 아직 생성되지 않았습니다"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

private struct PairPreviewSheetModifiers: ViewModifier {
    @Bindable var viewModel: PairPreviewViewModel
    let pair: PhotoPair

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "페어 삭제"),
                isPresented: $viewModel.showDeleteConfirm
            ) {
                Button(String(localized: "삭제"), role: .destructive) {
                    Task { await viewModel.confirmDelete() }
                }
                Button(String(localized: "취소"), role: .cancel) {}
            } message: {
                Text(String(localized: "이 페어를 삭제하시겠습니까?"))
            }
            .alert(
                String(localized: "오류"),
                isPresented: errorBinding,
                presenting: viewModel.errorMessage
            ) { _ in
                Button(String(localized: "확인"), role: .cancel) {
                    viewModel.clearError()
                }
            } message: { message in
                Text(message)
            }
            .sheet(isPresented: $viewModel.showShareSheet) {
                ShareSheet(activityItems: viewModel.shareItems)
            }
            .fullScreenCover(isPresented: $viewModel.showRetake) {
                NavigationStack {
                    AfterCameraView(initialPairId: pair.id, retakeMode: true)
                }
            }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }
}
