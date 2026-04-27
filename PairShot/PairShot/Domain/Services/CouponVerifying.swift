import Foundation

enum CouponVerificationOutcome: Equatable {
    case verified(code: String, kind: CouponKind, issuedAt: Date)
    case invalidPayload
    case invalidVersion
    case invalidKind
    case malformedKeyOrSignature
    case signatureInvalid
}

protocol CouponVerifying: Sendable {
    func verify(payloadJSON: Data, signatureBase64: String) -> CouponVerificationOutcome
}
