import Foundation

struct ToggleAlbumMembershipUseCase {
    let albumRepo: AlbumRepository

    func callAsFunction(pairId: UUID, albumId: UUID, isIncluded: Bool) async throws {
        if isIncluded {
            try await albumRepo.addPair(pairId: pairId, toAlbum: albumId)
        } else {
            try await albumRepo.removePair(pairId: pairId, fromAlbum: albumId)
        }
    }
}
