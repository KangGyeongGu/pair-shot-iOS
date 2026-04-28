import Foundation
import Observation
import UIKit

enum PermissionGateBlockingReason: String, Identifiable, CaseIterable {
    case camera
    case photoLibrary

    var id: String {
        rawValue
    }
}

@MainActor
@Observable
final class PermissionGateViewModel {
    private let permissionStatusService: PermissionStatusService

    var blockingReasons: [PermissionGateBlockingReason] {
        var reasons: [PermissionGateBlockingReason] = []
        if permissionStatusService.isCameraBlocked {
            reasons.append(.camera)
        }
        if permissionStatusService.isPhotoLibraryBlocked {
            reasons.append(.photoLibrary)
        }
        return reasons
    }

    init(permissionStatusService: PermissionStatusService) {
        self.permissionStatusService = permissionStatusService
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func refresh() async {
        await permissionStatusService.refreshAll()
    }

    deinit {}
}
