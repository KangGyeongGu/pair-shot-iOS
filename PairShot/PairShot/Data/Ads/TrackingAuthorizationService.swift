import AppTrackingTransparency
import Foundation
import Observation
import OSLog

struct SystemTrackingAuthorizationProvider {
    var currentStatus: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    func requestAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

@MainActor
@Observable
final class TrackingAuthorizationService {
    private(set) var currentStatus: ATTrackingManager.AuthorizationStatus

    private let provider: SystemTrackingAuthorizationProvider

    init(provider: SystemTrackingAuthorizationProvider = SystemTrackingAuthorizationProvider()) {
        self.provider = provider
        currentStatus = provider.currentStatus
    }

    func refresh() {
        currentStatus = provider.currentStatus
    }

    @discardableResult
    func requestIfUndetermined() async -> ATTrackingManager.AuthorizationStatus {
        let snapshot = provider.currentStatus
        guard snapshot == .notDetermined else {
            currentStatus = snapshot
            return snapshot
        }
        AppLogger.ads.debug("ATT prompt requested")
        let result = await provider.requestAuthorization()
        currentStatus = result
        AppLogger.ads.debug("ATT prompt result rawValue=\(result.rawValue, privacy: .public)")
        return result
    }

    var isAuthorized: Bool {
        currentStatus == .authorized
    }
}
