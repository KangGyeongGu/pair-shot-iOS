import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct HomeViewModelAfterDeletionTests {
    @Test
    func `requestAfterDeletion — 일반 모드 + After 있는 페어 → pendingAfterDelete 에 해당 페어 세팅`() {
        let viewModel = Self.makeViewModel()
        let pair = FixturePhotoPair.make(afterPhotoLocalIdentifier: "after-asset")

        viewModel.requestAfterDeletion(pair)

        #expect(viewModel.pendingAfterDelete?.pair.id == pair.id)
    }

    @Test
    func `requestAfterDeletion — 선택 모드일 때 호출 → 무시 (다중 선택 흐름과 충돌 방지)`() {
        let viewModel = Self.makeViewModel()
        viewModel.isSelectionMode = true
        let pair = FixturePhotoPair.make(afterPhotoLocalIdentifier: "after-asset")

        viewModel.requestAfterDeletion(pair)

        #expect(viewModel.pendingAfterDelete == nil)
    }

    @Test
    func `requestAfterDeletion — After 없는 페어 (scheduled) → 무시 (UI 가드 우회 시도 방어)`() {
        let viewModel = Self.makeViewModel()
        let pair = FixturePhotoPair.makeBeforeOnly()

        viewModel.requestAfterDeletion(pair)

        #expect(viewModel.pendingAfterDelete == nil)
    }

    private static func makeViewModel() -> HomeViewModel {
        let suiteName = "home-vm-after-delete-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let settings = AppSettings(defaults: defaults)
        let env = AppEnvironment(
            modelContainer: makeContainer(),
            appSettings: settings,
        )
        return env.makeHomeViewModel()
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
