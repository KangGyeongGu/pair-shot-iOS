import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct AfterCameraViewModelPeekTests {
    @Test
    func `requestPeek — selected pair 면 peekPairId 세팅`() {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        let pair = FixturePhotoPair.makeBeforeOnly()
        viewModel.pairs = [pair]
        viewModel.selectedPairId = pair.id

        viewModel.requestPeek(id: pair.id)

        #expect(viewModel.peekPairId == pair.id)
    }

    @Test
    func `requestPeek — selected 가 아닌 id 면 무시`() {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        let selectedPair = FixturePhotoPair.makeBeforeOnly()
        let otherPair = FixturePhotoPair.makeBeforeOnly()
        viewModel.pairs = [selectedPair, otherPair]
        viewModel.selectedPairId = selectedPair.id

        viewModel.requestPeek(id: otherPair.id)

        #expect(viewModel.peekPairId == nil)
    }

    @Test
    func `requestPeek — pairs 에 없는 id 면 무시`() {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        let pair = FixturePhotoPair.makeBeforeOnly()
        let danglingId = UUID()
        viewModel.pairs = [pair]
        viewModel.selectedPairId = danglingId

        viewModel.requestPeek(id: danglingId)

        #expect(viewModel.peekPairId == nil)
    }

    @Test
    func `dismissPeek — peekPairId 를 nil 로 되돌린다`() {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        let pair = FixturePhotoPair.makeBeforeOnly()
        viewModel.pairs = [pair]
        viewModel.selectedPairId = pair.id
        viewModel.requestPeek(id: pair.id)
        #expect(viewModel.peekPairId == pair.id)

        viewModel.dismissPeek()

        #expect(viewModel.peekPairId == nil)
    }

    private static func makeEnv() -> AppEnvironment {
        let suiteName = "after-peek-\(UUID().uuidString)"
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
