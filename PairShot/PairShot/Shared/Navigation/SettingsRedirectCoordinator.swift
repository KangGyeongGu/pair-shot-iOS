import Foundation
import Observation

enum SettingsPulseTarget: Equatable {
    case watermark
    case combine
}

@MainActor
@Observable
final class SettingsRedirectCoordinator {
    var pendingPulse: SettingsPulseTarget?

    init() {}

    func request(_ target: SettingsPulseTarget) {
        pendingPulse = target
    }

    func consume() -> SettingsPulseTarget? {
        let value = pendingPulse
        pendingPulse = nil
        return value
    }

    deinit {}
}
