import CoreLocation
import Foundation

protocol LocationProviding: Sendable {
    func requestSingleLocation() async -> CLLocation?
}

@MainActor
final class CoreLocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestSingleLocation() async -> CLLocation? {
        // Audit-C — concurrent callers used to cancel the in-flight
        // continuation by resuming it with nil, which silently dropped
        // the original caller's location request. Now we short-circuit
        // any second concurrent call instead, returning nil immediately
        // so the original request can finish without interference.
        guard continuation == nil else { return nil }

        return await withCheckedContinuation { (cont: CheckedContinuation<CLLocation?, Never>) in
            self.continuation = cont
            switch self.manager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    self.manager.requestLocation()

                case .notDetermined:
                    self.manager.requestWhenInUseAuthorization()

                case .denied, .restricted:
                    self.finish(with: nil)

                @unknown default:
                    self.finish(with: nil)
            }
        }
    }

    private func finish(with location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    self.manager.requestLocation()

                case .denied, .restricted:
                    finish(with: nil)

                default:
                    break
            }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let first = locations.first
        Task { @MainActor [weak self] in
            self?.finish(with: first)
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        Task { @MainActor [weak self] in
            self?.finish(with: nil)
        }
    }
}
