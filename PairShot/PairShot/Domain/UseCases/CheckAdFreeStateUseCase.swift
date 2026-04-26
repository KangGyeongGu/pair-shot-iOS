import Foundation

struct CheckAdFreeStateUseCase {
    struct State: Equatable {
        let isAdFree: Bool
        let expiresAt: Date?
    }

    let couponRepo: CouponRepository
    let now: @Sendable () -> Date

    init(
        couponRepo: CouponRepository,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.couponRepo = couponRepo
        self.now = now
    }

    func callAsFunction() async throws -> State {
        let timestamp = now()
        let active = try await couponRepo.fetchActive(now: timestamp)
        guard !active.isEmpty else {
            return State(isAdFree: false, expiresAt: nil)
        }
        let latest = active.map(\.expirationDate).max()
        return State(isAdFree: true, expiresAt: latest)
    }
}
