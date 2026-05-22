import Foundation
@testable import PairShot
import Testing

@MainActor
struct LocationServiceTests {
    @Test
    func `Initial currentLocation is nil before start`() {
        let service = CoreLocationService()
        #expect(service.currentLocation == nil)
    }

    @Test
    func `stop without prior start is idempotent`() {
        let service = CoreLocationService()
        service.stop()
        service.stop()
        #expect(service.currentLocation == nil)
    }

    @Test
    func `start when permission is denied does not crash and leaves cache empty`() {
        let service = CoreLocationService()
        service.start()
        #expect(service.currentLocation == nil)
    }

    @Test
    func `fetchOnce — InstantSleeper 주입 시 wait 없이 nil 반환 (시뮬레이터에서 권한_위치 fix 없으면 currentLocation 미설정)`() async {
        let service = CoreLocationService(sleeper: InstantSleeper())
        let result = await service.fetchOnce()
        #expect(result == nil)
    }
}
