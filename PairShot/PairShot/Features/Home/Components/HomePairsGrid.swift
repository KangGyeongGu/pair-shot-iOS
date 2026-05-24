import SwiftUI

struct HomePairsGrid: View {
    let viewModel: HomeViewModel
    let pairs: [PhotoPair]

    @Environment(AppEnvironment.self) private var env
    @Environment(Membership.self) private var membership

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        let groups = viewModel.groupedPairs(from: pairs)
        var slotIndex = 0
        let groupChunks: [(date: Date, pairs: [PhotoPair], chunks: [PairListWithAdsBuilder.PairChunk])] =
            groups
                .map { group in
                    let result = PairListWithAdsBuilder.buildChunks(
                        pairs: group.pairs,
                        adFree: AdSuppression.isSuppressed(
                            membership: membership,
                            tutorialCoordinator: env.tutorialCoordinator,
                        ),
                        startingAdSlotIndex: slotIndex,
                    )
                    slotIndex = result.nextSlotIndex
                    return (group.date, group.pairs, result.chunks)
                }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(groupChunks, id: \.date) { group in
                    pairDateSection(
                        date: group.date,
                        pairs: group.pairs,
                        chunks: group.chunks,
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .contentMargins(.bottom, 40, for: .scrollContent)
        .refreshable { await viewModel.reload() }
    }

    private func pairDateSection(
        date: Date,
        pairs: [PhotoPair],
        chunks: [PairListWithAdsBuilder.PairChunk],
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(HomeDateFormatter.base(for: date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appOnSurfaceVariant)
                .padding(.horizontal, 12)

            ForEach(chunks) { chunk in
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(chunk.pairs) { pair in
                        pairCell(pair: pair, allPairs: pairs)
                    }
                }
                .padding(.horizontal, 12)

                if let adSlotIndex = chunk.adSlotIndex {
                    NativeAdCard(slotIndex: adSlotIndex)
                        .padding(.horizontal, 12)
                }
            }
        }
    }

    private func pairCell(pair: PhotoPair, allPairs: [PhotoPair]) -> some View {
        HomePairCardView(
            pair: pair,
            isSelectionMode: viewModel.isSelectionMode,
            isSelected: viewModel.selectedPairIds.contains(pair.id),
        )
        .modifier(FirstPairCardAnchor(isFirst: allPairs.first?.id == pair.id))
        .contentShape(.rect)
        .onTapGesture { viewModel.tapPair(pair, allPairs: allPairs) }
        .modifier(HomePairContextMenu(viewModel: viewModel, pair: pair))
    }
}
