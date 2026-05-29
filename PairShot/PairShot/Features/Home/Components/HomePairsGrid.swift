import SwiftUI

struct HomePairsGrid: View {
    let viewModel: HomeViewModel
    let pairs: [PhotoPair]

    var body: some View {
        PairGrid(
            pairs: pairs,
            tutorialAnchorOnFirst: true,
            onRefresh: { await viewModel.reload() },
            cell: { pair in
                HomePairCardView(
                    pair: pair,
                    isSelectionMode: viewModel.isSelectionMode,
                    isSelected: viewModel.selectedPairIds.contains(pair.id),
                )
                .contentShape(.rect)
                .onTapGesture { viewModel.tapPair(pair, allPairs: pairs) }
                .modifier(PairCardContextMenu(
                    pair: pair,
                    isSelectionMode: viewModel.isSelectionMode,
                    actions: viewModel.pairCardActions,
                ))
            },
        )
    }
}
