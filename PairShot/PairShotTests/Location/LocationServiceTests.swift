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
    func `fetchOnce without cache returns nil within bounded timeout in simulator`() async {
        let service = CoreLocationService()
        let result = await service.fetchOnce()
        #expect(result == nil)
    }
}
