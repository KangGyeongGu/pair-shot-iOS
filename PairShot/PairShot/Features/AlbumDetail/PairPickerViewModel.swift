import Foundation
import Observation

@MainActor
@Observable
final class PairPickerViewModel {
    let albumId: UUID
    let photoLibrary: PhotoLibraryService

    var selection: Set<UUID> = []
    var isConfirming: Bool = false
    var didFinish: Bool = false
    var errorMessage: String?

    private let toggleAlbumMembership: ToggleAlbumMembershipUseCase

    init(
        albumId: UUID,
        toggleAlbumMembership: ToggleAlbumMembershipUseCase,
        photoLibrary: PhotoLibraryService
    ) {
        self.albumId = albumId
        self.toggleAlbumMembership = toggleAlbumMembership
        self.photoLibrary = photoLibrary
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
            errorMessage = String(localized: "pair_picker_error_partial_add_failed")
        } else {
            didFinish = true
        }
    }

    var titleText: String {
        if selection.isEmpty {
            return String(localized: "pair_picker_title")
        }
        let format = String(localized: "pair_picker_selection_count_template")
        return String(format: format, selection.count)
    }

    var buttonLabel: String {
        isConfirming
            ? String(localized: "pair_picker_button_adding")
            : String(localized: "pair_picker_button_add")
    }

    var isConfirmDisabled: Bool {
        selection.isEmpty || isConfirming
    }

    deinit {}
}
