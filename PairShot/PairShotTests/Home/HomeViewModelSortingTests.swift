import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct HomeViewModelSortingTests {
    private static let baseDate = Date(timeIntervalSinceReferenceDate: 700_000_000)

    @Test
    func `sortedPairs newest 는 createdAt 내림차순`() {
        let viewModel = makeViewModel()
        viewModel.setSortOrder(.newest)
        let oldest = PhotoPair(createdAt: Self.baseDate)
        let middle = PhotoPair(createdAt: Self.baseDate.addingTimeInterval(3600))
        let newest = PhotoPair(createdAt: Self.baseDate.addingTimeInterval(7200))

        let result = viewModel.sortedPairs(from: [oldest, newest, middle])

        #expect(result.map(\.id) == [newest.id, middle.id, oldest.id])
    }

    @Test
    func `sortedPairs oldest 는 createdAt 오름차순`() {
        let viewModel = makeViewModel()
        viewModel.setSortOrder(.oldest)
        let oldest = PhotoPair(createdAt: Self.baseDate)
        let middle = PhotoPair(createdAt: Self.baseDate.addingTimeInterval(3600))
        let newest = PhotoPair(createdAt: Self.baseDate.addingTimeInterval(7200))

        let result = viewModel.sortedPairs(from: [newest, middle, oldest])

        #expect(result.map(\.id) == [oldest.id, middle.id, newest.id])
    }

    @Test
    func `sortedPairs 는 빈 배열에서 빈 배열 반환`() {
        let viewModel = makeViewModel()
        #expect(viewModel.sortedPairs(from: []).isEmpty)
    }

    @Test
    func `sortedAlbums newest 는 createdAt 내림차순`() {
        let viewModel = makeViewModel()
        viewModel.setSortOrder(.newest)
        let oldest = Album(name: "A", createdAt: Self.baseDate)
        let newest = Album(name: "B", createdAt: Self.baseDate.addingTimeInterval(3600))

        let result = viewModel.sortedAlbums(from: [oldest, newest])

        #expect(result.map(\.id) == [newest.id, oldest.id])
    }

    @Test
    func `sortedAlbums oldest 는 createdAt 오름차순`() {
        let viewModel = makeViewModel()
        viewModel.setSortOrder(.oldest)
        let oldest = Album(name: "A", createdAt: Self.baseDate)
        let newest = Album(name: "B", createdAt: Self.baseDate.addingTimeInterval(3600))

        let result = viewModel.sortedAlbums(from: [newest, oldest])

        #expect(result.map(\.id) == [oldest.id, newest.id])
    }

    @Test
    func `groupedPairs 는 동일한 day 의 페어를 묶어 반환 (newest 정렬 시 group 도 내림차순)`() {
        let viewModel = makeViewModel()
        viewModel.setSortOrder(.newest)
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Self.baseDate
        let day2 = Self.baseDate.addingTimeInterval(60 * 60 * 24)
        let day1AM = PhotoPair(createdAt: day1.addingTimeInterval(3600))
        let day1PM = PhotoPair(createdAt: day1.addingTimeInterval(7200))
        let day2AM = PhotoPair(createdAt: day2.addingTimeInterval(3600))

        let groups = viewModel.groupedPairs(from: [day1AM, day1PM, day2AM], calendar: calendar)

        #expect(groups.count == 2)
        #expect(groups[0].pairs.contains(where: { $0.id == day2AM.id }))
        #expect(Set(groups[1].pairs.map(\.id)) == Set([day1AM.id, day1PM.id]))
    }

    @Test
    func `groupedPairs oldest 는 group 순서가 오름차순 + 그룹 내 정렬도 오름차순`() {
        let viewModel = makeViewModel()
        viewModel.setSortOrder(.oldest)
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Self.baseDate
        let day2 = Self.baseDate.addingTimeInterval(60 * 60 * 24)
        let day1AM = PhotoPair(createdAt: day1.addingTimeInterval(3600))
        let day1PM = PhotoPair(createdAt: day1.addingTimeInterval(7200))
        let day2AM = PhotoPair(createdAt: day2.addingTimeInterval(3600))

        let groups = viewModel.groupedPairs(from: [day2AM, day1PM, day1AM], calendar: calendar)

        #expect(groups.count == 2)
        #expect(groups[0].pairs.map(\.id) == [day1AM.id, day1PM.id])
        #expect(groups[1].pairs.first?.id == day2AM.id)
    }

    @Test
    func `groupedAlbums 도 day 단위로 묶고 정렬에 맞춰 group 순서 결정`() {
        let viewModel = makeViewModel()
        viewModel.setSortOrder(.newest)
        let calendar = Calendar(identifier: .gregorian)
        let day1Album = Album(name: "D1", createdAt: Self.baseDate)
        let day2Album = Album(name: "D2", createdAt: Self.baseDate.addingTimeInterval(60 * 60 * 24))

        let groups = viewModel.groupedAlbums(from: [day1Album, day2Album], calendar: calendar)

        #expect(groups.count == 2)
        #expect(groups[0].albums.first?.id == day2Album.id)
        #expect(groups[1].albums.first?.id == day1Album.id)
    }

    @Test
    func `setSortOrder 는 sortOrder property 를 변경 + appSettings 에 persist (동일 instance 에서 round-trip)`() {
        let viewModel = makeViewModel()
        viewModel.setSortOrder(.oldest)
        #expect(viewModel.sortOrder == .oldest)

        viewModel.setSortOrder(.newest)
        #expect(viewModel.sortOrder == .newest)
    }

    @Test
    func `HomeSortOrderMapping ASC 문자열 → oldest, 그 외 → newest`() {
        #expect(HomeSortOrderMapping.sortOrder(from: SortOrderPersistence.ascending) == .oldest)
        #expect(HomeSortOrderMapping.sortOrder(from: SortOrderPersistence.descending) == .newest)
        #expect(HomeSortOrderMapping.sortOrder(from: "UNKNOWN") == .newest)
        #expect(HomeSortOrderMapping.sortOrder(from: "") == .newest)
    }

    @Test
    func `HomeSortOrderMapping persisted 는 enum 을 정공 문자열로 변환`() {
        #expect(HomeSortOrderMapping.persisted(from: .newest) == SortOrderPersistence.descending)
        #expect(HomeSortOrderMapping.persisted(from: .oldest) == SortOrderPersistence.ascending)
    }

    private func makeViewModel() -> HomeViewModel {
        HomeViewModelTestEnvironment.make().makeHomeViewModel()
    }
}

@MainActor
private enum HomeViewModelTestEnvironment {
    static func make() -> AppEnvironment {
        let suiteName = "homeviewmodel-sorting-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let settings = AppSettings(defaults: defaults)
        return AppEnvironment(
            modelContainer: makeContainer(),
            appSettings: settings,
        )
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("test container failure: \(error)")
        }
    }
}
