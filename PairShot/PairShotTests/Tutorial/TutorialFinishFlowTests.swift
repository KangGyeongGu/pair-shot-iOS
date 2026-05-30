import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct TutorialFinishFlowTests {
    @Test
    func `finishAndCleanup 은 cleanupService 호출 후 current 를 nil 로 만든다`() async throws {
        let container = try makeContainer()
        let pairRepo = SwiftDataPhotoPairRepository(container: container)
        let tutorialA = PhotoPair(id: UUID(), isTutorial: true)
        let tutorialB = PhotoPair(id: UUID(), isTutorial: true)
        try await pairRepo.add(tutorialA)
        try await pairRepo.add(tutorialB)
        let cleanup = TutorialCleanupService(
            container: container,
            tutorialPhotoStore: makeStore(),
        )
        let coord = TutorialCoordinator(current: .goSettings, cleanupService: cleanup)

        coord.finishAndCleanup()

        try await Task.sleep(nanoseconds: 50_000_000)
        await Task.yield()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(coord.current == nil)
        let remaining = try await pairRepo.fetchAll(tutorialOnly: false)
        #expect(remaining.isEmpty)
    }

    @Test
    func `finishAndCleanup 은 cleanupService 가 nil 이어도 동작한다`() async throws {
        let coord = TutorialCoordinator(current: .goSettings)
        coord.finishAndCleanup()

        #expect(coord.current == .done)

        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(coord.current == nil)
    }

    @Test
    func `cleanupService 는 후속 주입이 가능하다`() throws {
        let container = try makeContainer()
        let cleanup = TutorialCleanupService(
            container: container,
            tutorialPhotoStore: makeStore(),
        )
        let coord = TutorialCoordinator()
        #expect(coord.cleanupService == nil)
        coord.cleanupService = cleanup
        #expect(coord.cleanupService != nil)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeStore() -> TutorialPhotoStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TutorialFinishFlowTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return TutorialPhotoStore(directoryURL: directory)
    }
}
