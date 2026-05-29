import SwiftUI

struct PairPickerView: View {
    let albumId: UUID

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PairPickerViewModel?

    var body: some View {
        AlbumByIdQueryHost(id: albumId) { album in
            PhotoPairQueryHost { allPairs in
                rootContent(album: album, allPairs: allPairs)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(
                action: { dismiss() },
                label: { Image(systemName: "xmark") },
            )
            .accessibilityLabel(String(localized: "common_button_close"))
        }
        ToolbarItem(placement: .principal) {
            Text(viewModel?.titleText ?? String(localized: "pair_picker_title"))
                .font(.headline)
        }
    }

    init(albumId: UUID) {
        self.albumId = albumId
    }

    @ViewBuilder
    private func rootContent(album: Album?, allPairs: [PhotoPair]) -> some View {
        let membership = Set(album?.pairIds ?? [])

        ZStack {
            if let viewModel {
                content(for: viewModel, allPairs: allPairs, membership: membership)
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbar }
        .task { ensureViewModel() }
        .onChange(of: viewModel?.didFinish ?? false) { _, finished in
            if finished { dismiss() }
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makePairPickerViewModel(albumId: albumId)
        }
    }

    private func content(
        for viewModel: PairPickerViewModel,
        allPairs: [PhotoPair],
        membership: Set<UUID>,
    ) -> some View {
        VStack(spacing: 0) {
            grid(viewModel: viewModel, allPairs: allPairs, membership: membership)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PairPickerBottomBar(
                buttonLabel: viewModel.buttonLabel,
                isDisabled: viewModel.isConfirmDisabled,
                action: { Task { await viewModel.confirm() } },
            )
        }
        .alert(
            String(localized: "common_dialog_error_title"),
            isPresented: errorBinding(for: viewModel),
        ) {
            Button(String(localized: "common_button_confirm"), role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func grid(
        viewModel: PairPickerViewModel,
        allPairs: [PhotoPair],
        membership: Set<UUID>,
    ) -> some View {
        if allPairs.isEmpty {
            PairPickerEmptyState()
        } else {
            PairGrid(pairs: allPairs) { pair in
                let alreadyIn = membership.contains(pair.id)
                let isSelected = viewModel.selection.contains(pair.id)

                PairPickerCardView(
                    pair: pair,
                    isAlreadyInAlbum: alreadyIn,
                    isSelected: isSelected,
                )
                .contentShape(.rect)
                .onTapGesture {
                    viewModel.toggleSelection(
                        pair.id,
                        isAlreadyInAlbum: alreadyIn,
                    )
                }
                .disabled(alreadyIn)
            }
        }
    }

    private func errorBinding(for viewModel: PairPickerViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.clearError() }
            },
        )
    }
}

struct PairPickerEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(.secondary)

            Text(String(localized: "pair_picker_empty"))
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}

struct PairPickerBottomBar: View {
    let buttonLabel: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(buttonLabel)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .disabled(isDisabled)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
}
