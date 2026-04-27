import Foundation
import OSLog

struct ActivateCouponUseCase {
    enum Outcome: Equatable {
        case success(couponId: UUID, expiresAt: Date)
        case invalidFormat
        case invalidSignature
        case notFound
        case alreadyUsedOnAnotherDevice
        case revoked
        case networkError
        case serverError
    }

    let couponRepo: CouponRepository

    func callAsFunction(code: String) async -> Outcome {
        let outcome = await couponRepo.activate(code: code)
        switch outcome {
            case let .success(coupon, expiresAt):
                AppLogger.coupon.info("Coupon activated successfully")
                return .success(couponId: coupon.id, expiresAt: expiresAt)

            case .invalidFormat:
                return .invalidFormat

            case .invalidSignature:
                return .invalidSignature

            case .notFound:
                return .notFound

            case .alreadyUsedOnAnotherDevice:
                return .alreadyUsedOnAnotherDevice

            case .revoked:
                return .revoked

            case .networkError:
                return .networkError

            case .serverError:
                return .serverError
        }
    }
}
