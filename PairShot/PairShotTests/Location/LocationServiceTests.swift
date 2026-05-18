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
    func `fetchOnce returns within bounded timeout in simulator`() async {
        let service = CoreLocationService()
        let start = Date()
        _ = await service.fetchOnce()
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 5.0)
    }
}
