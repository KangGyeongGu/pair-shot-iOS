import CoreLocation
import Foundation
import OSLog

@MainActor
final class CoreLocationService: NSObject, LocationFetching, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func fetchOnce() async -> DomainLocation? {
        guard let cl = await requestSingleLocation() else { return nil }
        return DomainLocation(latitude: cl.coordinate.latitude, longitude: cl.coordinate.longitude)
    }

    private func requestSingleLocation() async -> CLLocation? {
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

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        let description = error.localizedDescription
        Task { @MainActor [weak self] in
            AppLogger.camera.error("Location request failed: \(description, privacy: .public)")
            self?.finish(with: nil)
        }
    }
}
