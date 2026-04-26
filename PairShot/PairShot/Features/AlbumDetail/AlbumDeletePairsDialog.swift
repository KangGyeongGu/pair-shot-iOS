import SwiftUI

struct AlbumDeletePairsDialog: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "페어 삭제"),
                isPresented: pairDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingPairDelete
            ) { request in
                Button(String(localized: "앨범에서 제거")) {
                    Task {
                        await viewModel.removeFromAlbum(pairs: request.pairs)
                        viewModel.pendingPairDelete = nil
                    }
                }
                Button(String(localized: "모두 삭제"), role: .destructive) {
                    Task {
                        await viewModel.confirmPairDeletion(mode: .wholePair, pairs: request.pairs)
                        viewModel.pendingPairDelete = nil
                    }
                }
                if viewModel.hasCombined(in: request.pairs) {
                    Button(String(localized: "합성본만 삭제")) {
                        Task {
                            await viewModel.confirmPairDeletion(mode: .combinedOnly, pairs: request.pairs)
                            viewModel.pendingPairDelete = nil
                        }
                    }
                }
                Button(String(localized: "취소"), role: .cancel) {
                    viewModel.pendingPairDelete = nil
                }
            } message: { request in
                Text(String(format: String(localized: "%lld개의 페어를 어떻게 처리할까요?"), request.pairs.count))
            }
            .alert(
                String(localized: "페어 삭제"),
                isPresented: singlePairDeleteBinding,
                presenting: viewModel.pendingSinglePairDelete
            ) { request in
                Button(String(localized: "삭제"), role: .destructive) {
                    Task {
                        await viewModel.confirmSinglePairDeletion(request.pair)
                        viewModel.pendingSinglePairDelete = nil
                    }
                }
                Button(String(localized: "취소"), role: .cancel) {
                    viewModel.pendingSinglePairDelete = nil
                }
            } message: { _ in
                Text(String(localized: "이 페어를 삭제하시겠습니까?"))
            }
    }

    private var pairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPairDelete != nil },
            set: { if !$0 { viewModel.pendingPairDelete = nil } }
        )
    }

    private var singlePairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSinglePairDelete != nil },
            set: { if !$0 { viewModel.pendingSinglePairDelete = nil } }
        )
    }
}
