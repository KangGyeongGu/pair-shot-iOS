import Foundation
import Observation

@MainActor
@Observable
final class CouponRegistrationViewModel {
    var inputToken: String = ""
    private(set) var isSubmitting: Bool = false
    var lastError: CouponRegistrationError?
    private(set) var lastSuccessExpiration: Date?

    private let activate: ActivateCouponUseCase
    private let couponRepo: CouponRepository
    private let store: AdFreeStore
    private let now: @Sendable () -> Date

    init(
        activate: ActivateCouponUseCase,
        couponRepo: CouponRepository,
        store: AdFreeStore,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.activate = activate
        self.couponRepo = couponRepo
        self.store = store
        self.now = now
    }

    func acceptScannedToken(_ raw: String) async {
        inputToken = raw
        await submit()
    }

    func submit() async {
        guard !isSubmitting else { return }
        let trimmed = inputToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = .invalidFormat
            return
        }

        let token: CouponSignedToken
        do {
            token = try CouponSignedTokenParser.parse(trimmed)
        } catch {
            lastError = .invalidFormat
            return
        }

        let payload: CouponPayload
        do {
            payload = try CouponPayloadDecoder.makeJSONDecoder().decode(
                CouponPayload.self,
                from: token.payloadJSON
            )
        } catch {
            lastError = .invalidFormat
            return
        }

        let timestamp = now()
        if await isDuplicateActiveCoupon(code: payload.code, at: timestamp) {
            lastError = .duplicate
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let outcome = await activate(
            payloadJSON: token.payloadJSON,
            signatureBase64: token.signatureBase64
        )
        applyOutcome(outcome, at: timestamp)
    }

    private func applyOutcome(_ outcome: ActivateCouponUseCase.Outcome, at timestamp: Date) {
        switch outcome {
            case let .success(_, expiresAt):
                store.refresh(now: timestamp)
                lastSuccessExpiration = expiresAt

            case .duplicate:
                lastError = .duplicate

            case .invalidFormat:
                lastError = .invalidFormat

            case .signatureMismatch:
                lastError = .registrationFailed

            case .repositoryError:
                lastError = .persistFailed
        }
    }

    private func isDuplicateActiveCoupon(code: String, at timestamp: Date) async -> Bool {
        let all = await (try? couponRepo.fetchAll()) ?? []
        return all.contains { existing in
            existing.code == code && existing.isCurrentlyActive(now: timestamp)
        }
    }

    deinit {}
}
