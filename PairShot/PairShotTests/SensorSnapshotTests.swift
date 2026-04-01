import Testing
import Foundation
@testable import PairShot

@MainActor
struct SensorSnapshotTests {

    // MARK: - happy path (init 후 모든 프로퍼티 검증)

    @Test func init_happyPath_storedPropertiesMatchInput() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let snapshot = SensorSnapshot(
            pitch: 0.1,
            roll: 0.2,
            yaw: 0.3,
            heading: 90.0,
            latitude: 37.5665,
            longitude: 126.9780,
            altitude: 50.0,
            timestamp: date
        )

        #expect(snapshot.pitch == 0.1)
        #expect(snapshot.roll == 0.2)
        #expect(snapshot.yaw == 0.3)
        #expect(snapshot.heading == 90.0)
        #expect(snapshot.latitude == 37.5665)
        #expect(snapshot.longitude == 126.9780)
        #expect(snapshot.altitude == 50.0)
        #expect(snapshot.timestamp == date)
    }

    @Test func init_happyPath_negativeAnglesArePreserved() {
        let snapshot = SensorSnapshot(
            pitch: -1.5707963,  // -π/2
            roll: -0.7853981,   // -π/4
            yaw: -3.1415926,    // -π
            heading: 270.0,
            latitude: nil,
            longitude: nil,
            altitude: nil,
            timestamp: .now
        )

        #expect(snapshot.pitch == -1.5707963)
        #expect(snapshot.roll == -0.7853981)
        #expect(snapshot.yaw == -3.1415926)
        #expect(snapshot.heading == 270.0)
    }

    // MARK: - boundary

    @Test func init_boundary_zeroAnglesArePreserved() {
        let snapshot = SensorSnapshot(
            pitch: 0.0,
            roll: 0.0,
            yaw: 0.0,
            heading: 0.0,
            latitude: nil,
            longitude: nil,
            altitude: nil,
            timestamp: .now
        )

        #expect(snapshot.pitch == 0.0)
        #expect(snapshot.roll == 0.0)
        #expect(snapshot.yaw == 0.0)
        #expect(snapshot.heading == 0.0)
    }

    @Test func init_boundary_headingMaxValue360IsPreserved() {
        let snapshot = SensorSnapshot(
            pitch: 0.0,
            roll: 0.0,
            yaw: 0.0,
            heading: 360.0,
            latitude: nil,
            longitude: nil,
            altitude: nil,
            timestamp: .now
        )
        #expect(snapshot.heading == 360.0)
    }

    @Test func init_boundary_extremeCoordinatesArePreserved() {
        // 위도 -90 ~ +90, 경도 -180 ~ +180 경계값
        let snapshot = SensorSnapshot(
            pitch: 0.0,
            roll: 0.0,
            yaw: 0.0,
            heading: 0.0,
            latitude: -90.0,
            longitude: 180.0,
            altitude: -428.0, // 사해(Dead Sea) 최저점
            timestamp: .now
        )
        #expect(snapshot.latitude == -90.0)
        #expect(snapshot.longitude == 180.0)
        #expect(snapshot.altitude == -428.0)
    }

    // MARK: - negative (optional 필드 nil 허용 검증)

    @Test func init_negative_allOptionalFieldsCanBeNil() {
        let snapshot = SensorSnapshot(
            pitch: 0.0,
            roll: 0.0,
            yaw: 0.0,
            heading: 0.0,
            latitude: nil,
            longitude: nil,
            altitude: nil,
            timestamp: .now
        )
        #expect(snapshot.latitude == nil)
        #expect(snapshot.longitude == nil)
        #expect(snapshot.altitude == nil)
    }

    @Test func init_negative_latitudeNilWhileLongitudeSet() {
        // 위도만 없고 경도만 있는 비정상 케이스도 구조체 레벨에서 허용됨
        let snapshot = SensorSnapshot(
            pitch: 0.0,
            roll: 0.0,
            yaw: 0.0,
            heading: 0.0,
            latitude: nil,
            longitude: 126.9780,
            altitude: nil,
            timestamp: .now
        )
        #expect(snapshot.latitude == nil)
        #expect(snapshot.longitude == 126.9780)
    }

    @Test func init_negative_altitudeNilDoesNotAffectOtherFields() {
        let snapshot = SensorSnapshot(
            pitch: 1.0,
            roll: 2.0,
            yaw: 3.0,
            heading: 45.0,
            latitude: 37.0,
            longitude: 127.0,
            altitude: nil,
            timestamp: .now
        )
        #expect(snapshot.altitude == nil)
        #expect(snapshot.pitch == 1.0)
        #expect(snapshot.latitude == 37.0)
    }

    // MARK: - error

    @Test func init_error_timestampIsDistinctPerInstance() {
        // 두 인스턴스에 서로 다른 timestamp를 넣으면 독립적으로 저장되어야 한다
        let t1 = Date(timeIntervalSince1970: 0)
        let t2 = Date(timeIntervalSince1970: 1_000_000)
        let s1 = SensorSnapshot(pitch: 0, roll: 0, yaw: 0, heading: 0,
                                latitude: nil, longitude: nil, altitude: nil, timestamp: t1)
        let s2 = SensorSnapshot(pitch: 0, roll: 0, yaw: 0, heading: 0,
                                latitude: nil, longitude: nil, altitude: nil, timestamp: t2)
        #expect(s1.timestamp != s2.timestamp)
    }
}
