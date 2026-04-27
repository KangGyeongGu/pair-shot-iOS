import Foundation
import OSLog

struct ActivateCouponUseCase {
    enum Outcome: Equatable {
        case success(couponId: UUID, expiresAt: Date)
        case duplicate(existingId: UUID)
        case invalidFormat
        case signatureMismatch
        case repositoryError
    }

    // swiftformat:disable:next numberFormatting
    static let unlimitedDurationFallbackDays: Int = 36_500

    let couponRepo: CouponRepository
    let verifier: CouponVerifying
    let now: @Sendable () -> Date

    init(
        couponRepo: CouponRepository,
        verifier: CouponVerifying,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.couponRepo = couponRepo
        self.verifier = verifier
        self.now = now
    }

    static func durationDays(for kind: CouponKind) -> Int {
        switch kind {
            case let .timed(days):
                days

            case .unlimited:
                unlimitedDurationFallbackDays
        }
    }

    func callAsFunction(payloadJSON: Data, signatureBase64: String) async -> Outcome {
        let trimmedSignature = signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payloadJSON.isEmpty, !trimmedSignature.isEmpty else {
            return .invalidFormat
        }

        let outcome = verifier.verify(payloadJSON: payloadJSON, signatureBase64: trimmedSignature)
        let verifiedCode: String
        let verifiedKind: CouponKind
        let verifiedIssuedAt: Date
        switch outcome {
            case let .verified(code, kind, issuedAt):
                verifiedCode = code
                verifiedKind = kind
                verifiedIssuedAt = issuedAt

            case .invalidPayload, .invalidVersion, .invalidKind, .malformedKeyOrSignature:
                return .invalidFormat

            case .signatureInvalid:
                return .signatureMismatch
        }

        let timestamp = now()
        do {
            let existing = try await couponRepo.fetchAll()
            if let duplicate = existing.first(where: { $0.code == verifiedCode }) {
                AppLogger.coupon.info("Coupon activation duplicate detected")
                return .duplicate(existingId: duplicate.id)
            }
            let durationDays = Self.durationDays(for: verifiedKind)
            let coupon = Coupon(
                code: verifiedCode,
                activatedAt: timestamp,
                durationDays: durationDays,
                signatureBase64: trimmedSignature,
                status: .active,
                kindRawString: verifiedKind.rawString,
                payloadVersion: CouponPayload.currentVersion,
                issuedAt: verifiedIssuedAt
            )
            try await couponRepo.add(coupon)
            AppLogger.coupon.info("Coupon activated successfully")
            return .success(couponId: coupon.id, expiresAt: coupon.expirationDate)
        } catch {
            AppLogger.coupon.error(
                "Coupon activation repository error: \(error.localizedDescription, privacy: .public)"
            )
            return .repositoryError
        }
    }
}
