import Foundation

struct DeletePairsUseCase {
    enum Mode: Equatable {
        case wholePair
        case combinedOnly
    }

    let pairRepo: PhotoPairRepository
    let storage: PhotoStoring

    func callAsFunction(ids: Set<UUID>, mode: Mode) async throws {
        guard !ids.isEmpty else { return }
        switch mode {
            case .wholePair:
                try await deleteWholePairs(ids: ids)

            case .combinedOnly:
                try await deleteCombinedOnly(ids: ids)
        }
    }

    private func deleteWholePairs(ids: Set<UUID>) async throws {
        for id in ids {
            guard let pair = try await pairRepo.fetch(id: id) else { continue }
            storage.deletePhotosForPair(
                beforeFileName: pair.beforeFileName,
                afterFileName: pair.afterFileName,
                combinedFileName: pair.combinedFileName
            )
        }
        try await pairRepo.delete(ids: ids)
    }

    private func deleteCombinedOnly(ids: Set<UUID>) async throws {
        for id in ids {
            guard let pair = try await pairRepo.fetch(id: id) else { continue }
            storage.deletePhotosForPair(
                beforeFileName: nil,
                afterFileName: nil,
                combinedFileName: pair.combinedFileName
            )
            pair.combinedFileName = nil
            pair.updatedAt = .now
            try await pairRepo.update(pair)
        }
    }
}
