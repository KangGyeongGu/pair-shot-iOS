import CoreLocation

struct SensorSnapshot {
    let pitch: Double    // radians
    let roll: Double     // radians
    let yaw: Double      // radians
    let heading: Double  // degrees, magnetic north
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let timestamp: Date
}

/// SensorManager가 준수해야 하는 인터페이스
/// — 테스트 및 LiDAR 계층 확장 시 Mock 교체 가능하도록 분리
@MainActor
protocol SensorServiceProtocol: AnyObject {
    var currentPitch: Double { get }
    var currentRoll: Double { get }
    var currentYaw: Double { get }
    var currentHeading: Double { get }
    var currentLocation: CLLocationCoordinate2D? { get }
    var isMotionAuthorized: Bool { get }
    var isLocationAuthorized: Bool { get }

    func startUpdates()
    func stopUpdates()
    func captureSnapshot() -> SensorSnapshot
    func requestLocationAuthorization()
}
