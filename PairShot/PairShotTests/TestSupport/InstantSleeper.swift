import Foundation
@testable import PairShot

struct InstantSleeper: AsyncSleeper {
    func sleep(seconds _: TimeInterval) async throws {}
}
