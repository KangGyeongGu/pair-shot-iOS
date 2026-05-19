import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct HomeViewModelSelectionTests {
    @Test
    func `enterSelectionMode 는 isSelectionMode true 로 전환 + selection 초기화`() {
        let viewModel = makeViewModel()
        viewModel.selectedPairIds = [UUID()]
        viewModel.selectedAlbumIds = [UUID()]
        viewModel.isSelectionMode = false

        viewModel.enterSelectionMode()

        #expect(viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds.isEmpty)
        #expect(viewModel.selectedAlbumIds.isEmpty)
    }

    @Test
    func `enterSelectionMode 는 이미 selection 모드 시 no-op (selection 보존)`() {
        let viewModel = makeViewModel()
        let preselected = UUID()
        viewModel.isSelectionMode = true
        viewModel.selectedPairIds = [preselected]

        viewModel.enterSelectionMode()

        #expect(viewModel.selectedPairIds == [preselected])
    }

    @Test
    func `enterSelectionMode autoSelecting 은 주어진 pair ID 로 selection 초기화`() {
        let viewModel = makeViewModel()
        let id1 = UUID()
        let id2 = UUID()

        viewModel.enterSelectionMode(autoSelectingPairIds: [id1, id2])

        #expect(viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds == Set([id1, id2]))
        #expect(viewModel.selectedAlbumIds.isEmpty)
    }

    @Test
    func `cancelSelection 은 모드 끄고 양쪽 selection 비움`() {
        let viewModel = makeViewModel()
        viewModel.enterSelectionMode(autoSelectingPairIds: [UUID(), UUID()])
        viewModel.selectedAlbumIds = [UUID()]

        viewModel.cancelSelection()

        #expect(!viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds.isEmpty)
        #expect(viewModel.selectedAlbumIds.isEmpty)
    }

    @Test
    func `togglePairSelection 은 미선택 → 선택 → 미선택 토글`() {
        let viewModel = makeViewModel()
        let id = UUID()

        viewModel.togglePairSelection(id)
        #expect(viewModel.selectedPairIds == [id])

        viewModel.togglePairSelection(id)
        #expect(viewModel.selectedPairIds.isEmpty)
    }

    @Test
    func `toggleAlbumSelection 은 독립된 album set 만 토글`() {
        let viewModel = makeViewModel()
        let pairId = UUID()
        let albumId = UUID()
        viewModel.togglePairSelection(pairId)

        viewModel.toggleAlbumSelection(albumId)

        #expect(viewModel.selectedAlbumIds == [albumId])
        #expect(viewModel.selectedPairIds == [pairId])
    }

    @Test
    func `selectAllPairs 는 전체 선택 ↔ 비선택 토글 (이미 전체 선택 시 비움)`() {
        let viewModel = makeViewModel()
        let pairs = [makePair(), makePair(), makePair()]

        viewModel.selectAllPairs(from: pairs)
        #expect(viewModel.selectedPairIds == Set(pairs.map(\.id)))

        viewModel.selectAllPairs(from: pairs)
        #expect(viewModel.selectedPairIds.isEmpty)
    }

    @Test
    func `selectAllPairs 부분 선택 시 — 전체 선택으로 채움`() {
        let viewModel = makeViewModel()
        let pairs = [makePair(), makePair(), makePair()]
        viewModel.togglePairSelection(pairs[0].id)

        viewModel.selectAllPairs(from: pairs)

        #expect(viewModel.selectedPairIds == Set(pairs.map(\.id)))
    }

    @Test
    func `selectAllAlbums 도 동일 토글 패턴 적용`() {
        let viewModel = makeViewModel()
        let albums = [Album(name: "A"), Album(name: "B")]

        viewModel.selectAllAlbums(from: albums)
        #expect(viewModel.selectedAlbumIds == Set(albums.map(\.id)))

        viewModel.selectAllAlbums(from: albums)
        #expect(viewModel.selectedAlbumIds.isEmpty)
    }

    @Test
    func `areAllPairsSelected 는 빈 배열에서 false (none-of-empty 게이트)`() {
        let viewModel = makeViewModel()

        #expect(!viewModel.areAllPairsSelected(from: []))
    }

    @Test
    func `areAllPairsSelected 는 부분 선택 시 false, 전체 선택 시 true`() {
        let viewModel = makeViewModel()
        let pairs = [makePair(), makePair(), makePair()]
        viewModel.togglePairSelection(pairs[0].id)
        #expect(!viewModel.areAllPairsSelected(from: pairs))

        viewModel.togglePairSelection(pairs[1].id)
        viewModel.togglePairSelection(pairs[2].id)
        #expect(viewModel.areAllPairsSelected(from: pairs))
    }

    @Test
    func `areAllAlbumsSelected 도 동일 게이트`() {
        let viewModel = makeViewModel()
        let albums = [Album(name: "A"), Album(name: "B")]
        viewModel.toggleAlbumSelection(albums[0].id)
        #expect(!viewModel.areAllAlbumsSelected(from: albums))

        viewModel.toggleAlbumSelection(albums[1].id)
        #expect(viewModel.areAllAlbumsSelected(from: albums))
    }

    @Test
    func `switchContentMode 는 같은 모드 호출 시 no-op (selection 보존)`() {
        let viewModel = makeViewModel()
        let preselected = UUID()
        viewModel.enterSelectionMode(autoSelectingPairIds: [preselected])

        viewModel.switchContentMode(to: .pairs)

        #expect(viewModel.contentMode == .pairs)
        #expect(viewModel.selectedPairIds == [preselected])
        #expect(viewModel.isSelectionMode)
    }

    @Test
    func `switchContentMode 는 다른 모드 전환 시 selection 모두 취소`() {
        let viewModel = makeViewModel()
        viewModel.enterSelectionMode(autoSelectingPairIds: [UUID(), UUID()])

        viewModel.switchContentMode(to: .albums)

        #expect(viewModel.contentMode == .albums)
        #expect(!viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds.isEmpty)
        #expect(viewModel.selectedAlbumIds.isEmpty)
    }

    private func makeViewModel() -> HomeViewModel {
        HomeViewModelTestEnvironment.make().makeHomeViewModel()
    }

    private func makePair(createdAt: Date = .now) -> PhotoPair {
        PhotoPair(createdAt: createdAt)
    }
}

@MainActor
private enum HomeViewModelTestEnvironment {
    static func make() -> AppEnvironment {
        let suiteName = "homeviewmodel-selection-\(UUID().uuidString)"
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
