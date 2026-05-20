import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct SwiftDataAlbumRepositoryTests {
    @Test
    func `add 후 동일 id 로 조회하면 도메인 필드가 그대로 영속화된다`() async throws {
        let context = try makeContext()
        let repository = SwiftDataAlbumRepository(container: context.container)
        let album = Album(
            name: "현장 A",
            id: UUID(),
            latitude: 37.5,
            longitude: 127.0,
            locationLabel: "서울",
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
        )

        try await repository.add(album)

        let fetched = try context.fetchAlbumEntity(id: album.id)
        #expect(fetched != nil)
        #expect(fetched?.name == "현장 A")
        #expect(fetched?.latitude == 37.5)
        #expect(fetched?.longitude == 127.0)
        #expect(fetched?.locationLabel == "서울")
        #expect(fetched?.createdAt == Date(timeIntervalSinceReferenceDate: 100))
    }

    @Test
    func `update 시 이름과 위치 라벨이 반영되고 updatedAt 이 갱신된다`() async throws {
        let context = try makeContext()
        let repository = SwiftDataAlbumRepository(container: context.container)
        let originalCreatedAt = Date(timeIntervalSinceReferenceDate: 100)
        let album = Album(
            name: "초기 이름",
            id: UUID(),
            locationLabel: "초기 위치",
            createdAt: originalCreatedAt,
        )
        try await repository.add(album)

        let beforeUpdate = try context.fetchAlbumEntity(id: album.id)?.updatedAt
        var renamed = album
        renamed.name = "변경된 이름"
        renamed.locationLabel = "변경된 위치"
        try await repository.update(renamed)

        let updated = try context.fetchAlbumEntity(id: album.id)
        #expect(updated?.name == "변경된 이름")
        #expect(updated?.locationLabel == "변경된 위치")
        if let beforeUpdate, let afterUpdatedAt = updated?.updatedAt {
            #expect(afterUpdatedAt >= beforeUpdate)
        }
    }

    @Test
    func `addPair 호출 시 해당 페어가 album 의 pairs 에 등록된다`() async throws {
        let context = try makeContext()
        let albumRepository = SwiftDataAlbumRepository(container: context.container)
        let pairRepository = SwiftDataPhotoPairRepository(container: context.container)
        let album = Album(name: "A", id: UUID())
        let pair = PhotoPair(id: UUID())
        try await albumRepository.add(album)
        try await pairRepository.add(pair)

        try await albumRepository.addPair(pairId: pair.id, toAlbum: album.id)

        let entity = try context.fetchAlbumEntity(id: album.id)
        #expect(entity?.pairs.map(\.id) == [pair.id])
        #expect(entity?.toDomain().pairIds == [pair.id])
    }

    @Test
    func `addPair 를 같은 페어 id 로 두 번 호출해도 단 한 번만 등록된다`() async throws {
        let context = try makeContext()
        let albumRepository = SwiftDataAlbumRepository(container: context.container)
        let pairRepository = SwiftDataPhotoPairRepository(container: context.container)
        let album = Album(name: "A", id: UUID())
        let pair = PhotoPair(id: UUID())
        try await albumRepository.add(album)
        try await pairRepository.add(pair)

        try await albumRepository.addPair(pairId: pair.id, toAlbum: album.id)
        try await albumRepository.addPair(pairId: pair.id, toAlbum: album.id)

        let entity = try context.fetchAlbumEntity(id: album.id)
        #expect(entity?.pairs.count == 1)
        #expect(entity?.pairs.first?.id == pair.id)
    }

    @Test
    func `removePair 호출 시 album 의 pairs 에서 해당 페어가 빠진다`() async throws {
        let context = try makeContext()
        let albumRepository = SwiftDataAlbumRepository(container: context.container)
        let pairRepository = SwiftDataPhotoPairRepository(container: context.container)
        let album = Album(name: "A", id: UUID())
        let pairA = PhotoPair(id: UUID())
        let pairB = PhotoPair(id: UUID())
        try await albumRepository.add(album)
        try await pairRepository.add(pairA)
        try await pairRepository.add(pairB)
        try await albumRepository.addPair(pairId: pairA.id, toAlbum: album.id)
        try await albumRepository.addPair(pairId: pairB.id, toAlbum: album.id)

        try await albumRepository.removePair(pairId: pairA.id, fromAlbum: album.id)

        let entity = try context.fetchAlbumEntity(id: album.id)
        #expect(entity?.pairs.map(\.id) == [pairB.id])
    }

    @Test
    func `delete 호출 후에는 같은 id 로 더 이상 조회되지 않는다`() async throws {
        let context = try makeContext()
        let repository = SwiftDataAlbumRepository(container: context.container)
        let album = Album(name: "삭제 대상", id: UUID())
        try await repository.add(album)

        try await repository.delete(id: album.id)

        let fetched = try context.fetchAlbumEntity(id: album.id)
        #expect(fetched == nil)
    }

    @Test
    func `PhotoPairRepository delete 가 일어나면 album pairs 에서 자동으로 정합된다`() async throws {
        let context = try makeContext()
        let albumRepository = SwiftDataAlbumRepository(container: context.container)
        let pairRepository = SwiftDataPhotoPairRepository(container: context.container)
        let album = Album(name: "A", id: UUID())
        let pair = PhotoPair(id: UUID())
        try await albumRepository.add(album)
        try await pairRepository.add(pair)
        try await albumRepository.addPair(pairId: pair.id, toAlbum: album.id)

        try await pairRepository.delete(ids: [pair.id])

        let entity = try context.fetchAlbumEntity(id: album.id)
        #expect(entity?.pairs.isEmpty == true)
        #expect(entity?.toDomain().pairIds.isEmpty == true)
    }

    @Test
    func `존재하지 않는 album id 로 update 해도 크래시 없이 무시된다`() async throws {
        let context = try makeContext()
        let repository = SwiftDataAlbumRepository(container: context.container)
        let phantom = Album(name: "유령", id: UUID())

        try await repository.update(phantom)

        let fetched = try context.fetchAlbumEntity(id: phantom.id)
        #expect(fetched == nil)
    }

    @Test
    func `존재하지 않는 album id 로 addPair removePair 해도 크래시 없이 무시된다`() async throws {
        let context = try makeContext()
        let albumRepository = SwiftDataAlbumRepository(container: context.container)
        let pairRepository = SwiftDataPhotoPairRepository(container: context.container)
        let pair = PhotoPair(id: UUID())
        try await pairRepository.add(pair)
        let missingAlbumId = UUID()

        try await albumRepository.addPair(pairId: pair.id, toAlbum: missingAlbumId)
        try await albumRepository.removePair(pairId: pair.id, fromAlbum: missingAlbumId)

        let fetched = try context.fetchAlbumEntity(id: missingAlbumId)
        #expect(fetched == nil)
    }

    @Test
    func `존재하지 않는 pair id 로 addPair 호출해도 album pairs 는 변하지 않는다`() async throws {
        let context = try makeContext()
        let albumRepository = SwiftDataAlbumRepository(container: context.container)
        let album = Album(name: "A", id: UUID())
        try await albumRepository.add(album)
        let missingPairId = UUID()

        try await albumRepository.addPair(pairId: missingPairId, toAlbum: album.id)

        let entity = try context.fetchAlbumEntity(id: album.id)
        #expect(entity?.pairs.isEmpty == true)
    }

    private func makeContext() throws -> AlbumRepositoryTestContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return AlbumRepositoryTestContext(container: container)
    }
}

@MainActor
private struct AlbumRepositoryTestContext {
    let container: ModelContainer

    func fetchAlbumEntity(id: UUID) throws -> AlbumEntity? {
        let descriptor = FetchDescriptor<AlbumEntity>(
            predicate: #Predicate { $0.id == id },
        )
        return try container.mainContext.fetch(descriptor).first
    }
}
