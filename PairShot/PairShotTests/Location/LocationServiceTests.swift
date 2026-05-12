@testable import PairShot
import Testing

@MainActor
struct LocationServiceTests {
    @Test("Initial currentLocation is nil before start")
    func initialStateIsNil() {
        let service = CoreLocationService()
        #expect(service.currentLocation == nil)
    }

    @Test("stop without prior start is idempotent")
    func stopWithoutStartIsNoop() {
        let service = CoreLocationService()
        service.stop()
        service.stop()
        #expect(service.currentLocation == nil)
    }

    @Test("start when permission is denied does not crash and leaves cache empty")
    func startWithoutPermissionDoesNotCrash() {
        let service = CoreLocationService()
        service.start()
        #expect(service.currentLocation == nil)
    }

    @Test("fetchOnce without cache returns nil within bounded timeout in simulator")
    func fetchOnceWithoutCacheReturnsNil() async {
        let service = CoreLocationService()
        let result = await service.fetchOnce()
        #expect(result == nil)
    }
}
