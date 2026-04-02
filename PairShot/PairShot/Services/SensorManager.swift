import CoreLocation
import CoreMotion
import Foundation
import Observation

@MainActor
@Observable
final class SensorManager: NSObject, SensorServiceProtocol {
    private enum Constants {
        static let motionUpdateInterval: TimeInterval = 1.0 / 60.0
        static let lowPassAlpha: Double = 0.15
    }

    private(set) var currentPitch: Double = 0.0
    private(set) var currentRoll: Double = 0.0
    private(set) var currentYaw: Double = 0.0
    private(set) var currentHeading: Double = 0.0
    private(set) var currentLocation: CLLocationCoordinate2D?
    private(set) var isMotionAuthorized: Bool = false
    private(set) var isLocationAuthorized: Bool = false

    private var currentAltitude: Double?

    private let motionManager: CMMotionManager = .init()
    private let locationManager: CLLocationManager = .init()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func startUpdates() {
        startMotionUpdates()
        startLocationUpdatesIfAuthorized()
    }

    func stopUpdates() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    func captureSnapshot() -> SensorSnapshot {
        SensorSnapshot(
            pitch: currentPitch,
            roll: currentRoll,
            yaw: currentYaw,
            heading: currentHeading,
            latitude: currentLocation?.latitude,
            longitude: currentLocation?.longitude,
            altitude: currentAltitude,
            timestamp: Date()
        )
    }

    func requestLocationAuthorization() {
        let status = locationManager.authorizationStatus
        switch status {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                isLocationAuthorized = true
                startLocationUpdatesIfAuthorized()
            case .denied, .restricted:
                isLocationAuthorized = false
            @unknown default:
                break
        }
    }

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            // LiDAR 없는 기기에서도 graceful degradation — 기본값 유지, 크래시 없음
            isMotionAuthorized = false
            return
        }

        isMotionAuthorized = true
        motionManager.deviceMotionUpdateInterval = Constants.motionUpdateInterval

        let available = CMMotionManager.availableAttitudeReferenceFrames()
        let referenceFrame: CMAttitudeReferenceFrame =
            available.contains(.xArbitraryCorrectedZVertical)
                ? .xArbitraryCorrectedZVertical
                : .xArbitraryZVertical

        // CMMotionManager는 Sendable이 아니므로 OperationQueue.main 사용
        motionManager.startDeviceMotionUpdates(
            using: referenceFrame,
            to: .main
        ) { [weak self] motion, error in
            guard let self, let motion, error == nil else { return }
            applyLowPassFilter(motion: motion)
        }
    }

    private func applyLowPassFilter(motion: CMDeviceMotion) {
        let alpha = Constants.lowPassAlpha
        let attitude = motion.attitude

        currentPitch = alpha * attitude.pitch + (1.0 - alpha) * currentPitch
        currentRoll = alpha * attitude.roll + (1.0 - alpha) * currentRoll
        currentYaw = alpha * attitude.yaw + (1.0 - alpha) * currentYaw
    }

    private func startLocationUpdatesIfAuthorized() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        isLocationAuthorized = true
        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }
}

extension SensorManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    isLocationAuthorized = true
                    startLocationUpdatesIfAuthorized()
                case .denied, .restricted:
                    isLocationAuthorized = false
                    currentLocation = nil
                    currentAltitude = nil
                case .notDetermined:
                    isLocationAuthorized = false
                @unknown default:
                    break
            }
        }
    }

    nonisolated func locationManager(
        _: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        let coordinate = location.coordinate
        let altitude = location.altitude
        Task { @MainActor [weak self] in
            guard let self else { return }
            currentLocation = coordinate
            currentAltitude = altitude
        }
    }

    nonisolated func locationManager(
        _: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        // headingAccuracy < 0 이면 신뢰할 수 없는 값
        guard newHeading.headingAccuracy >= 0 else { return }
        let magnetic = newHeading.magneticHeading
        Task { @MainActor [weak self] in
            guard let self else { return }
            let alpha = Constants.lowPassAlpha
            // 360도 경계 wraparound 보정: 355→5 전환 시 점프 방지
            var delta = magnetic - currentHeading
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            var updated = (currentHeading + alpha * delta).truncatingRemainder(dividingBy: 360)
            if updated < 0 { updated += 360 }
            currentHeading = updated
        }
    }

    nonisolated func locationManager(
        _: CLLocationManager,
        didFailWithError _: Error
    ) {
        // 권한 거부/센서 없음 등 — 크래시 없이 무시
    }
}
