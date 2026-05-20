import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct AlbumDetailViewModelTapPairTests {
    @Test
    func `tapPair — scheduled 분기 결과는 다음 tap (captured) 호출 시 덮어쓰여짐`() {
        let viewModel = makeViewModel()
        let scheduled = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: nil,
        )
        let captured = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: "after-id",
        )

        viewModel.tapPair(scheduled, allPairs: [scheduled, captured])
        #expect(viewModel.showAfterCamera)
        #expect(viewModel.afterCameraTargetPairId == scheduled.id)

        viewModel.tapPair(captured, allPairs: [scheduled, captured])

        #expect(viewModel.pendingPreviewPair?.pair.id == captured.id)
        #expect(viewModel.showAfterCamera)
        #expect(viewModel.afterCameraTargetPairId == scheduled.id)
    }

    @Test
    func `tapPair — afterOnly 두 번 연속 → beforeCameraTargetPairId 가 최신 pair id 로 갱신`() {
        let viewModel = makeViewModel()
        let first = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: nil,
            afterPhotoLocalIdentifier: "after-1",
        )
        let second = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: nil,
            afterPhotoLocalIdentifier: "after-2",
        )

        viewModel.tapPair(first, allPairs: [first, second])
        #expect(viewModel.beforeCameraTargetPairId == first.id)

        viewModel.tapPair(second, allPairs: [first, second])

        #expect(viewModel.beforeCameraTargetPairId == second.id)
        #expect(viewModel.showBeforeCamera)
    }

    @Test
    func `tapPair — selection 모드에서 captured pair 도 단순 토글만, preview 미진입`() {
        let viewModel = makeViewModel()
        viewModel.isSelectionMode = true
        let captured = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: "after-id",
        )
        let scheduled = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: nil,
        )

        viewModel.tapPair(captured, allPairs: [captured, scheduled])
        viewModel.tapPair(scheduled, allPairs: [captured, scheduled])

        #expect(viewModel.selectedPairIds == [captured.id, scheduled.id])
        #expect(viewModel.pendingPreviewPair == nil)
        #expect(!viewModel.showAfterCamera)
        #expect(!viewModel.showBeforeCamera)
    }

    private func makeViewModel() -> AlbumDetailViewModel {
        Self.makeEnv().makeAlbumDetailViewModel(albumId: UUID())
    }

    private static func makeEnv() -> AppEnvironment {
        let suiteName = "albumdetail-tappair-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let settings = AppSettings(defaults: defaults)
        return AppEnvironment(
            modelContainer: makeContainer(),
            appSettings: settings,
        )
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("test container failure: \(error)")
        }
    }
}
