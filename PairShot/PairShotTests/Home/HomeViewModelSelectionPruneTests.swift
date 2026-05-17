import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct HomeViewModelSelectionPruneTests {
    @Test
    func `pruneStalePairSelections 는 현재 ID 목록에 없는 선택을 제거한다`() {
        let viewModel = makeViewModel()
        let live = UUID()
        let stale = UUID()
        viewModel.enterSelectionMode(autoSelectingPairIds: [live, stale])

        viewModel.pruneStalePairSelections(currentIds: [live])

        #expect(viewModel.selectedPairIds == Set([live]))
    }

    @Test
    func `pruneStalePairSelections 는 변동이 없으면 selection 을 그대로 유지한다`() {
        let viewModel = makeViewModel()
        let id1 = UUID()
        let id2 = UUID()
        viewModel.enterSelectionMode(autoSelectingPairIds: [id1, id2])

        viewModel.pruneStalePairSelections(currentIds: [id1, id2])

        #expect(viewModel.selectedPairIds == Set([id1, id2]))
    }

    @Test
    func `pruneStalePairSelections 는 빈 selection 에서 noop`() {
        let viewModel = makeViewModel()

        viewModel.pruneStalePairSelections(currentIds: [UUID()])

        #expect(viewModel.selectedPairIds.isEmpty)
    }

    @Test
    func `pruneStaleAlbumSelections 도 stale ID 를 제거한다`() {
        let viewModel = makeViewModel()
        let live = UUID()
        let stale = UUID()
        viewModel.isSelectionMode = true
        viewModel.selectedAlbumIds = [live, stale]

        viewModel.pruneStaleAlbumSelections(currentIds: [live])

        #expect(viewModel.selectedAlbumIds == Set([live]))
    }

    private func makeViewModel() -> HomeViewModel {
        let env = HomeViewModelTestEnvironment.make()
        return env.makeHomeViewModel()
    }
}

@MainActor
private enum HomeViewModelTestEnvironment {
    static func make() -> AppEnvironment {
        let suiteName = "homeviewmodel-selection-prune-\(UUID().uuidString)"
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
