import AppTrackingTransparency
import Foundation
import Observation

protocol TrackingAuthorizationProviding: Sendable {
    var currentStatus: ATTrackingManager.AuthorizationStatus { get }

    func requestAuthorization() async -> ATTrackingManager.AuthorizationStatus
}

struct SystemTrackingAuthorizationProvider: TrackingAuthorizationProviding {
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

    private let provider: TrackingAuthorizationProviding

    convenience init() {
        self.init(provider: SystemTrackingAuthorizationProvider())
    }

    init(provider: TrackingAuthorizationProviding) {
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
        let result = await provider.requestAuthorization()
        currentStatus = result
        return result
    }

    var isAuthorized: Bool {
        currentStatus == .authorized
    }
}
