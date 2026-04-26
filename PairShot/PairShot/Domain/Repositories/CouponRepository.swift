import Foundation

protocol CouponRepository: Sendable {
    func observeAll() -> AsyncStream<[Coupon]>
    func fetchAll() async throws -> [Coupon]
    func fetchActive(now: Date) async throws -> [Coupon]
    func add(_ coupon: Coupon) async throws
    func updateStatus(id: UUID, status: Coupon.Status) async throws
    func rolloverExpired(now: Date) async throws
}
