import Foundation
@testable import PairShot
import Testing
import UniformTypeIdentifiers

struct TutorialPhotoStoreTests {
    @Test
    func `save 는 tutorial 접두사를 가진 식별자를 반환한다`() async throws {
        let store = makeStore()
        let identifier = try await store.save(data: Data([0x01, 0x02]), utType: .jpeg)
        #expect(identifier.hasPrefix(TutorialPhotoStore.identifierPrefix))
        #expect(TutorialPhotoStore.isTutorialIdentifier(identifier))
    }

    @Test
    func `loadData 는 저장한 원본 바이트를 그대로 반환한다`() async throws {
        let store = makeStore()
        let original = Data([0xAB, 0xCD, 0xEF, 0x10])
        let identifier = try await store.save(data: original, utType: .jpeg)
        let loaded = await store.loadData(localIdentifier: identifier)
        #expect(loaded == original)
    }

    @Test
    func `loadData 는 알 수 없는 식별자에 대해 nil 을 반환한다`() async {
        let store = makeStore()
        let result = await store.loadData(localIdentifier: "tutorial://missing.jpg")
        #expect(result == nil)
    }

    @Test
    func `loadData 는 비튜토리얼 식별자에 대해 nil 을 반환한다`() async {
        let store = makeStore()
        let result = await store.loadData(localIdentifier: "ABCD-EFGH-1234")
        #expect(result == nil)
    }

    @Test
    func `delete 는 지정한 항목만 제거한다`() async throws {
        let store = makeStore()
        let keep = try await store.save(data: Data([0x01]), utType: .jpeg)
        let drop = try await store.save(data: Data([0x02]), utType: .jpeg)
        try store.delete(localIdentifiers: [drop])
        let keptData = await store.loadData(localIdentifier: keep)
        let droppedData = await store.loadData(localIdentifier: drop)
        #expect(keptData == Data([0x01]))
        #expect(droppedData == nil)
    }

    @Test
    func `deleteAll 은 디렉터리 전체를 비운다`() async throws {
        let store = makeStore()
        let firstId = try await store.save(data: Data([0x01]), utType: .jpeg)
        let secondId = try await store.save(data: Data([0x02]), utType: .heic)
        try store.deleteAll()
        let loadedFirst = await store.loadData(localIdentifier: firstId)
        let loadedSecond = await store.loadData(localIdentifier: secondId)
        #expect(loadedFirst == nil)
        #expect(loadedSecond == nil)
    }

    @Test
    func `deleteAll 은 디렉터리가 없어도 throw 하지 않는다`() throws {
        let store = makeStore()
        try store.deleteAll()
    }

    @Test
    func `delete 는 존재하지 않는 식별자도 무시한다`() throws {
        let store = makeStore()
        try store.delete(localIdentifiers: ["tutorial://nothing.jpg", "non-tutorial-id"])
    }

    @Test
    func `isTutorialIdentifier 는 접두사 매칭을 정확히 판정한다`() {
        #expect(TutorialPhotoStore.isTutorialIdentifier("tutorial://abc.jpg"))
        #expect(!TutorialPhotoStore.isTutorialIdentifier(""))
        #expect(!TutorialPhotoStore.isTutorialIdentifier("Tutorial://abc.jpg"))
        #expect(!TutorialPhotoStore.isTutorialIdentifier("ABCD-1234"))
    }

    private func makeStore() -> TutorialPhotoStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TutorialPhotoStoreTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return TutorialPhotoStore(directoryURL: directory)
    }
}
