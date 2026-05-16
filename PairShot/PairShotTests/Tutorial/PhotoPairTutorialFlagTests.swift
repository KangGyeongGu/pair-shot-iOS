import Foundation
@testable import PairShot
import Testing

@MainActor
struct PhotoPairTutorialFlagTests {
    @Test
    func `default init 은 isTutorial false`() {
        let pair = PhotoPair()
        #expect(pair.isTutorial == false)
    }

    @Test
    func `isTutorial true 명시 생성 가능`() {
        let pair = PhotoPair(isTutorial: true)
        #expect(pair.isTutorial == true)
    }
}
