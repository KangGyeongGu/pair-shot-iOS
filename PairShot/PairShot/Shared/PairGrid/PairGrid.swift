import SwiftUI

struct PairGrid<Cell: View>: View {
    let pairs: [PhotoPair]
    let tutorialAnchorOnFirst: Bool
    let onRefresh: (() async -> Void)?
    let cell: (PhotoPair) -> Cell

    @Environment(AppEnvironment.self) private var env
    @Environment(Membership.self) private var membership

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        let adFree = AdSuppression.isSuppressed(
            membership: membership,
            tutorialCoordinator: env.tutorialCoordinator,
        )
        let groupChunks = buildGroupChunks(adFree: adFree)
        let firstPairId = pairs.first?.id
        scroll(groupChunks: groupChunks, firstPairId: firstPairId)
    }

    init(
        pairs: [PhotoPair],
        tutorialAnchorOnFirst: Bool = false,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder cell: @escaping (PhotoPair) -> Cell,
    ) {
        self.pairs = pairs
        self.tutorialAnchorOnFirst = tutorialAnchorOnFirst
        self.onRefresh = onRefresh
        self.cell = cell
    }

    @ViewBuilder
    private func scroll(
        groupChunks: [(date: Date, chunks: [PairListWithAdsBuilder.PairChunk])],
        firstPairId: UUID?,
    ) -> some View {
        let base = ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(groupChunks, id: \.date) { group in
                    dateSection(
                        date: group.date,
                        chunks: group.chunks,
                        firstPairId: firstPairId,
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .contentMargins(.bottom, 40, for: .scrollContent)

        if let onRefresh {
            base.refreshable { await onRefresh() }
        } else {
            base
        }
    }

    private func dateSection(
        date: Date,
        chunks: [PairListWithAdsBuilder.PairChunk],
        firstPairId: UUID?,
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(HomeDateFormatter.base(for: date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appOnSurfaceVariant)
                .padding(.horizontal, 12)

            ForEach(chunks) { chunk in
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(chunk.pairs) { pair in
                        cell(pair)
                            .modifier(FirstPairCardAnchor(
                                isFirst: tutorialAnchorOnFirst && firstPairId == pair.id,
                            ))
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

    private func buildGroupChunks(
        adFree: Bool,
    ) -> [(date: Date, chunks: [PairListWithAdsBuilder.PairChunk])] {
        let groups = groupedByDay(pairs)
        var slotIndex = 0
        var result: [(date: Date, chunks: [PairListWithAdsBuilder.PairChunk])] = []
        for group in groups {
            let chunkResult = PairListWithAdsBuilder.buildChunks(
                pairs: group.pairs,
                adFree: adFree,
                startingAdSlotIndex: slotIndex,
            )
            slotIndex = chunkResult.nextSlotIndex
            result.append((group.date, chunkResult.chunks))
        }
        return result
    }

    private func groupedByDay(
        _ pairs: [PhotoPair],
        calendar: Calendar = .current,
    ) -> [(date: Date, pairs: [PhotoPair])] {
        var dayOrder: [Date] = []
        var byDay: [Date: [PhotoPair]] = [:]
        for pair in pairs {
            let day = calendar.startOfDay(for: pair.createdAt)
            if byDay[day] == nil {
                dayOrder.append(day)
            }
            byDay[day, default: []].append(pair)
        }
        return dayOrder.map { ($0, byDay[$0] ?? []) }
    }
}
