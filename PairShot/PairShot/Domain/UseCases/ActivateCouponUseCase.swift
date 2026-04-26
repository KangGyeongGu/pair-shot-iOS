import Foundation

struct ActivateCouponUseCase {
    enum Outcome: Equatable {
        case success(couponId: UUID, expiresAt: Date)
        case duplicate(existingId: UUID)
        case invalidFormat
        case signatureMismatch
        case repositoryError
    }

    let couponRepo: CouponRepository
    let verifier: CouponVerifying
    let now: @Sendable () -> Date
    let defaultDurationDays: Int

    init(
        couponRepo: CouponRepository,
        verifier: CouponVerifying,
        now: @escaping @Sendable () -> Date = { .now },
        defaultDurationDays: Int = 30
    ) {
        self.couponRepo = couponRepo
        self.verifier = verifier
        self.now = now
        self.defaultDurationDays = defaultDurationDays
    }

    func callAsFunction(code: String, signatureBase64: String) async -> Outcome {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSignature = signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty, !trimmedSignature.isEmpty else {
            return .invalidFormat
        }

        let outcome = verifier.verify(code: trimmedCode, signatureBase64: trimmedSignature)
        switch outcome {
            case .valid: break

            case .emptyCode, .emptySignature, .malformedSignature, .malformedPublicKey:
                return .invalidFormat

            case .invalidSignature:
                return .signatureMismatch
        }

        let timestamp = now()
        do {
            let existing = try await couponRepo.fetchAll()
            if let duplicate = existing.first(where: { $0.code == trimmedCode }) {
                return .duplicate(existingId: duplicate.id)
            }
            let coupon = Coupon(
                code: trimmedCode,
                activatedAt: timestamp,
                durationDays: defaultDurationDays,
                signatureBase64: trimmedSignature,
                status: .active
            )
            try await couponRepo.add(coupon)
            return .success(couponId: coupon.id, expiresAt: coupon.expirationDate)
        } catch {
            return .repositoryError
        }
    }
}
