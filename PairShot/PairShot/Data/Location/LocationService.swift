import CoreLocation
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class CoreLocationService: NSObject {
    private(set) var currentLocation: DomainLocation?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var isUpdating = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        guard !isUpdating else { return }
        switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()

            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
                isUpdating = true

            case .denied, .restricted:
                return

            @unknown default:
                return
        }
    }

    func stop() {
        guard isUpdating else { return }
        manager.stopUpdatingLocation()
        isUpdating = false
    }

    func fetchOnce() async -> DomainLocation? {
        if let cached = currentLocation { return cached }
        start()
        try? await Task.sleep(for: .seconds(2))
        return currentLocation
    }
}

extension CoreLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor [weak self] in
            self?.applyLocation(latest)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    if !isUpdating {
                        self.manager.startUpdatingLocation()
                        isUpdating = true
                    }

                default:
                    return
            }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        let description = error.localizedDescription
        Task { @MainActor in
            AppLogger.camera.error("Location update failed: \(description, privacy: .public)")
        }
    }

    @MainActor
    private func applyLocation(_ location: CLLocation?) {
        guard let location else { return }
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= 1000 else { return }
        guard location.timestamp.timeIntervalSinceNow > -5 else { return }
        currentLocation = DomainLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
        )
    }
}
