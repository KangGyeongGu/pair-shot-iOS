import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct HomeViewModelTutorialSelectionTests {
    @Test
    func `enterSelectionMode autoSelectingPairIds 는 선택 페어 ID 를 적재한다`() {
        let viewModel = makeViewModel()
        let id1 = UUID()
        let id2 = UUID()

        viewModel.enterSelectionMode(autoSelectingPairIds: [id1, id2])

        #expect(viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds == Set([id1, id2]))
    }

    @Test
    func `enterSelectionMode autoSelectingPairIds 는 빈 배열에서 selection 을 비워둔다`() {
        let viewModel = makeViewModel()

        viewModel.enterSelectionMode(autoSelectingPairIds: [])

        #expect(viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds.isEmpty)
    }

    @Test
    func `이미 selection 모드이면 autoSelect 는 무시된다`() {
        let viewModel = makeViewModel()
        viewModel.enterSelectionMode()
        let id = UUID()

        viewModel.enterSelectionMode(autoSelectingPairIds: [id])

        #expect(viewModel.selectedPairIds.isEmpty)
    }

    @Test
    func `기존 enterSelectionMode 는 selection 을 비워둔다`() {
        let viewModel = makeViewModel()

        viewModel.enterSelectionMode()

        #expect(viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds.isEmpty)
    }

    private func makeViewModel() -> HomeViewModel {
        let env = HomeViewModelTestEnvironment.make()
        return env.makeHomeViewModel()
    }
}

@MainActor
private enum HomeViewModelTestEnvironment {
    static func make() -> AppEnvironment {
        let suiteName = "homeviewmodel-tutorial-selection-\(UUID().uuidString)"
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
