import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct HomeViewModelTapPairTests {
    @Test
    func `tapPair — scheduled 상태 + 비-selection 모드 → AfterCamera 진입`() {
        let viewModel = makeViewModel()
        let pair = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: nil,
        )
        #expect(pair.status == .scheduled)

        viewModel.tapPair(pair, allPairs: [pair])

        #expect(viewModel.showAfterCamera)
        #expect(viewModel.afterCameraTargetPairId == pair.id)
        #expect(!viewModel.showBeforeCamera)
        #expect(viewModel.pendingPreviewPair == nil)
    }

    @Test
    func `tapPair — afterOnly 상태 + 비-selection 모드 → BeforeCamera 진입`() {
        let viewModel = makeViewModel()
        let pair = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: nil,
            afterPhotoLocalIdentifier: "after-id",
        )
        #expect(pair.status == .afterOnly)

        viewModel.tapPair(pair, allPairs: [pair])

        #expect(viewModel.showBeforeCamera)
        #expect(viewModel.beforeCameraTargetPairId == pair.id)
        #expect(!viewModel.showAfterCamera)
        #expect(viewModel.pendingPreviewPair == nil)
    }

    @Test
    func `tapPair — captured 상태 + 비-selection 모드 → preview pending 설정 (camera flag 미변경)`() {
        let viewModel = makeViewModel()
        let pair = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: "after-id",
        )
        #expect(pair.status == .captured)

        viewModel.tapPair(pair, allPairs: [pair])

        #expect(viewModel.pendingPreviewPair?.pair.id == pair.id)
        #expect(!viewModel.showBeforeCamera)
        #expect(!viewModel.showAfterCamera)
        #expect(viewModel.beforeCameraTargetPairId == nil)
        #expect(viewModel.afterCameraTargetPairId == nil)
    }

    @Test
    func `tapPair — selection 모드일 때는 상태 무시하고 단순 토글`() {
        let viewModel = makeViewModel()
        viewModel.isSelectionMode = true
        let captured = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: "after-id",
        )

        viewModel.tapPair(captured, allPairs: [captured])
        #expect(viewModel.selectedPairIds == [captured.id])
        #expect(!viewModel.showBeforeCamera)
        #expect(!viewModel.showAfterCamera)
        #expect(viewModel.pendingPreviewPair == nil)

        viewModel.tapPair(captured, allPairs: [captured])
        #expect(viewModel.selectedPairIds.isEmpty)
    }

    private func makeViewModel() -> HomeViewModel {
        HomeViewModelTapPairEnvironment.make().makeHomeViewModel()
    }
}

@MainActor
private enum HomeViewModelTapPairEnvironment {
    static func make() -> AppEnvironment {
        let suiteName = "homeviewmodel-tappair-\(UUID().uuidString)"
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
