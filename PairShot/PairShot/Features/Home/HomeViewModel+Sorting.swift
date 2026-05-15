import Foundation

extension HomeViewModel {
    func sortedPairs(from all: [PhotoPair]) -> [PhotoPair] {
        switch sortOrder {
            case .newest:
                all.sorted { $0.createdAt > $1.createdAt }

            case .oldest:
                all.sorted { $0.createdAt < $1.createdAt }
        }
    }

    func groupedPairs(from all: [PhotoPair], calendar: Calendar = .current) -> [(date: Date, pairs: [PhotoPair])] {
        let sorted = sortedPairs(from: all)
        let grouped = Dictionary(grouping: sorted) { calendar.startOfDay(for: $0.createdAt) }
        return
            grouped
                .map { (date: $0.key, pairs: $0.value) }
                .sorted { sortOrder == .newest ? $0.date > $1.date : $0.date < $1.date }
    }

    func sortedAlbums(from all: [Album]) -> [Album] {
        switch sortOrder {
            case .newest:
                all.sorted { $0.createdAt > $1.createdAt }

            case .oldest:
                all.sorted { $0.createdAt < $1.createdAt }
        }
    }

    func groupedAlbums(from all: [Album], calendar: Calendar = .current) -> [(date: Date, albums: [Album])] {
        let sorted = sortedAlbums(from: all)
        let grouped = Dictionary(grouping: sorted) { calendar.startOfDay(for: $0.createdAt) }
        return
            grouped
                .map { (date: $0.key, albums: $0.value) }
                .sorted { sortOrder == .newest ? $0.date > $1.date : $0.date < $1.date }
    }

    func setSortOrder(_ order: HomeSortOrder) {
        sortOrder = order
    }
}
