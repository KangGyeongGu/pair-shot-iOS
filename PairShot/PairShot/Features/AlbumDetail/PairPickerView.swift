import SwiftData
import SwiftUI

struct PairPickerView: View {
    let albumId: UUID

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PhotoPairEntity.createdAt, order: .reverse)
    private var allPairs: [PhotoPairEntity]

    @Query private var albums: [AlbumEntity]

    @State private var viewModel: PairPickerViewModel?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    init(albumId: UUID) {
        self.albumId = albumId
        let predicate = #Predicate<AlbumEntity> { $0.id == albumId }
        _albums = Query(filter: predicate)
    }

    var body: some View {
        ZStack {
            if let viewModel {
                content(for: viewModel)
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

    @ViewBuilder
    private func content(for viewModel: PairPickerViewModel) -> some View {
        let membership = membershipPairIds()

        VStack(spacing: 0) {
            grid(viewModel: viewModel, membership: membership)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PairPickerBottomBar(
                buttonLabel: viewModel.buttonLabel,
                isDisabled: viewModel.isConfirmDisabled,
                action: { Task { await viewModel.confirm() } }
            )
        }
        .alert(
            String(localized: "common_dialog_error_title"),
            isPresented: errorBinding(for: viewModel)
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
        membership: Set<UUID>
    ) -> some View {
        if allPairs.isEmpty {
            PairPickerEmptyState()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(allPairs) { entity in
                        let pair = entity.toDomain()
                        let alreadyIn = membership.contains(pair.id)
                        let isSelected = viewModel.selection.contains(pair.id)

                        PairPickerCardView(
                            pair: pair,
                            isAlreadyInAlbum: alreadyIn,
                            isSelected: isSelected
                        )
                        .contentShape(.rect)
                        .onTapGesture {
                            viewModel.toggleSelection(
                                pair.id,
                                isAlreadyInAlbum: alreadyIn
                            )
                        }
                        .disabled(alreadyIn)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(String(localized: "common_button_close"))
        }
        ToolbarItem(placement: .principal) {
            Text(viewModel?.titleText ?? String(localized: "pair_picker_title"))
                .font(.headline)
        }
    }

    private func membershipPairIds() -> Set<UUID> {
        guard let album = albums.first else { return [] }
        return Set(album.pairs.map(\.id))
    }

    private func errorBinding(for viewModel: PairPickerViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.clearError() }
            }
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
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isDisabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
}
