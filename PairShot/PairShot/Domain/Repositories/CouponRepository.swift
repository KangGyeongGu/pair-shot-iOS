import Foundation

enum CouponActivationOutcome: Equatable {
    case success(coupon: Coupon, expiresAt: Date)
    case invalidFormat
    case invalidSignature
    case notFound
    case alreadyUsedOnAnotherDevice
    case revoked
    case networkError
    case serverError

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
            case let (.success(lc, le), .success(rc, re)):
                lc.id == rc.id && le == re

            case (.invalidFormat, .invalidFormat),
                 (.invalidSignature, .invalidSignature),
                 (.notFound, .notFound),
                 (.alreadyUsedOnAnotherDevice, .alreadyUsedOnAnotherDevice),
                 (.revoked, .revoked),
                 (.networkError, .networkError),
                 (.serverError, .serverError):
                true

            default:
                false
        }
    }
}

protocol CouponRepository: Sendable {
    func observeAll() -> AsyncStream<[Coupon]>
    func fetchAll() async throws -> [Coupon]
    func fetchActive(now: Date) async throws -> [Coupon]
    func add(_ coupon: Coupon) async throws
    func updateStatus(id: UUID, status: Coupon.Status) async throws
    func rolloverExpired(now: Date) async throws
    func activate(code: String) async -> CouponActivationOutcome
}
