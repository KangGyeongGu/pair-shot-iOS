import Foundation

enum CouponVerificationOutcome: Equatable {
    case valid
    case invalidSignature
    case malformedSignature
    case malformedPublicKey
    case emptyCode
    case emptySignature
}

protocol CouponVerifying: Sendable {
    func verify(code: String, signatureBase64: String) -> CouponVerificationOutcome
}
