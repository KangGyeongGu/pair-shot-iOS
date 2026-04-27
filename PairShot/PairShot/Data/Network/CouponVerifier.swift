import CryptoKit
import Foundation
import OSLog

enum CouponVerifier {
    static let infoPlistKey = "CouponPublicKeyBase64"

    static let placeholderPublicKeyBase64 = Data(repeating: 0, count: 32).base64EncodedString()

    static func resolvedPublicKeyBase64(bundle: Bundle = .main) -> String {
        guard
            let value = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return placeholderPublicKeyBase64
        }
        return value
    }

    static func verify(
        payloadJSON: Data,
        signatureBase64: String,
        publicKeyBase64: String = Self.resolvedPublicKeyBase64()
    ) -> CouponVerificationOutcome {
        guard !payloadJSON.isEmpty else { return .invalidPayload }
        let trimmedSignature = signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSignature.isEmpty else { return .malformedKeyOrSignature }

        let payload: CouponPayload
        do {
            payload = try CouponPayloadDecoder.makeJSONDecoder().decode(CouponPayload.self, from: payloadJSON)
        } catch {
            return .invalidPayload
        }

        guard payload.version == CouponPayload.currentVersion else { return .invalidVersion }
        guard let kind = CouponKind(rawString: payload.kind) else { return .invalidKind }

        guard let signatureData = Data(base64Encoded: trimmedSignature), !signatureData.isEmpty else {
            return .malformedKeyOrSignature
        }
        guard let publicKeyData = Data(base64Encoded: publicKeyBase64) else {
            return .malformedKeyOrSignature
        }

        let publicKey: Curve25519.Signing.PublicKey
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        } catch {
            return .malformedKeyOrSignature
        }

        guard publicKey.isValidSignature(signatureData, for: payloadJSON) else {
            AppLogger.coupon.error("Coupon signature verification failed")
            return .signatureInvalid
        }

        return .verified(code: payload.code, kind: kind, issuedAt: payload.issuedAt)
    }
}

struct CouponVerifierAdapter: CouponVerifying {
    let publicKeyBase64: String

    init(publicKeyBase64: String = CouponVerifier.resolvedPublicKeyBase64()) {
        self.publicKeyBase64 = publicKeyBase64
    }

    func verify(payloadJSON: Data, signatureBase64: String) -> CouponVerificationOutcome {
        CouponVerifier.verify(
            payloadJSON: payloadJSON,
            signatureBase64: signatureBase64,
            publicKeyBase64: publicKeyBase64
        )
    }
}
