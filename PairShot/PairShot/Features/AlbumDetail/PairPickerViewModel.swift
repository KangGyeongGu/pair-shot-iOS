import Foundation
import Observation

@MainActor
@Observable
final class PairPickerViewModel {
    let albumId: UUID
    let storage: PhotoStorageService

    var selection: Set<UUID> = []
    var isConfirming: Bool = false
    var didFinish: Bool = false
    var errorMessage: String?

    private let toggleAlbumMembership: ToggleAlbumMembershipUseCase

    init(
        albumId: UUID,
        toggleAlbumMembership: ToggleAlbumMembershipUseCase,
        storage: PhotoStorageService
    ) {
        self.albumId = albumId
        self.toggleAlbumMembership = toggleAlbumMembership
        self.storage = storage
    }

    func toggleSelection(_ pairId: UUID, isAlreadyInAlbum: Bool) {
        guard !isAlreadyInAlbum else { return }
        if selection.contains(pairId) {
            selection.remove(pairId)
        } else {
            selection.insert(pairId)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func confirm() async {
        guard !selection.isEmpty, !isConfirming else { return }
        isConfirming = true
        defer { isConfirming = false }
        var failed = false
        for pairId in selection {
            do {
                try await toggleAlbumMembership(
                    pairId: pairId,
                    albumId: albumId,
                    isIncluded: true
                )
            } catch {
                failed = true
            }
        }
        if failed {
            errorMessage = String(localized: "일부 페어를 추가하지 못했습니다")
        } else {
            didFinish = true
        }
    }

    var titleText: String {
        if selection.isEmpty {
            return String(localized: "페어 선택")
        }
        let format = String(localized: "%lld개 선택")
        return String(format: format, selection.count)
    }

    var buttonLabel: String {
        isConfirming
            ? String(localized: "추가 중…")
            : String(localized: "추가")
    }

    var isConfirmDisabled: Bool {
        selection.isEmpty || isConfirming
    }

    deinit {}
}
