import Foundation
@testable import PairShot
import Testing

@MainActor
struct PairPickerViewModelTests {
    @Test
    func `confirm — 모든 addPair 성공 시 errorMessage nil + didFinish true`() async {
        let repo = StubAlbumRepository()
        let viewModel = makeViewModel(repo: repo)
        let pairA = UUID()
        let pairB = UUID()
        viewModel.selection = [pairA, pairB]

        await viewModel.confirm()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.didFinish)
        #expect(viewModel.selection == [pairA, pairB])
        #expect(!viewModel.isConfirming)
        #expect(repo.addPairCalls.count == 2)
    }

    @Test
    func `confirm — 하나라도 throw 시 errorMessage 세팅 + didFinish false + selection 보존`() async {
        let repo = StubAlbumRepository()
        let failingPair = UUID()
        repo.failingPairIds = [failingPair]
        let viewModel = makeViewModel(repo: repo)
        let okPair = UUID()
        viewModel.selection = [failingPair, okPair]

        await viewModel.confirm()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage == String(localized: "pair_picker_error_partial_add_failed"))
        #expect(!viewModel.didFinish)
        #expect(viewModel.selection == [failingPair, okPair])
        #expect(!viewModel.isConfirming)
    }

    @Test
    func `confirm — 빈 selection 은 no-op (repo 호출 안 됨)`() async {
        let repo = StubAlbumRepository()
        let viewModel = makeViewModel(repo: repo)

        await viewModel.confirm()

        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.didFinish)
        #expect(repo.addPairCalls.isEmpty)
    }

    @Test
    func `clearError — errorMessage nil 로 초기화`() {
        let repo = StubAlbumRepository()
        let viewModel = makeViewModel(repo: repo)
        viewModel.errorMessage = "error"

        viewModel.clearError()

        #expect(viewModel.errorMessage == nil)
    }

    private func makeViewModel(repo: AlbumRepository) -> PairPickerViewModel {
        PairPickerViewModel(
            albumId: UUID(),
            albumRepo: repo,
            photoLibrary: PhotoLibraryService(),
        )
    }
}

@MainActor
private final class StubAlbumRepository: AlbumRepository, @unchecked Sendable {
    struct AddPairFailure: Error {}

    var failingPairIds: Set<UUID> = []
    private(set) var addPairCalls: [(pairId: UUID, albumId: UUID)] = []

    func add(_: Album) async throws {}
    func update(_: Album) async throws {}
    func delete(id _: UUID) async throws {}

    func addPair(pairId: UUID, toAlbum albumId: UUID) async throws {
        addPairCalls.append((pairId, albumId))
        if failingPairIds.contains(pairId) {
            throw AddPairFailure()
        }
    }

    func removePair(pairId _: UUID, fromAlbum _: UUID) async throws {}
}
