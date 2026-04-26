import CryptoKit
import Foundation

enum CouponVerificationError: Error, Equatable {
    case malformedSignature
    case malformedPublicKey
    case emptyCode
    case emptySignature
}

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
        code: String,
        signatureBase64: String,
        publicKeyBase64: String = Self.resolvedPublicKeyBase64()
    ) throws -> Bool {
        guard !code.isEmpty else { throw CouponVerificationError.emptyCode }
        guard !signatureBase64.isEmpty else { throw CouponVerificationError.emptySignature }

        guard let signature = Data(base64Encoded: signatureBase64) else {
            throw CouponVerificationError.malformedSignature
        }
        guard !signature.isEmpty else { throw CouponVerificationError.emptySignature }

        guard let keyData = Data(base64Encoded: publicKeyBase64) else {
            throw CouponVerificationError.malformedPublicKey
        }

        let publicKey: Curve25519.Signing.PublicKey
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        } catch {
            throw CouponVerificationError.malformedPublicKey
        }

        let payload = Data(code.utf8)
        return publicKey.isValidSignature(signature, for: payload)
    }
}

struct CouponVerifierAdapter: CouponVerifying {
    let publicKeyBase64: String

    init(publicKeyBase64: String = CouponVerifier.resolvedPublicKeyBase64()) {
        self.publicKeyBase64 = publicKeyBase64
    }

    func verify(code: String, signatureBase64: String) -> CouponVerificationOutcome {
        do {
            let isValid = try CouponVerifier.verify(
                code: code,
                signatureBase64: signatureBase64,
                publicKeyBase64: publicKeyBase64
            )
            return isValid ? .valid : .invalidSignature
        } catch CouponVerificationError.malformedSignature {
            return .malformedSignature
        } catch CouponVerificationError.malformedPublicKey {
            return .malformedPublicKey
        } catch CouponVerificationError.emptyCode {
            return .emptyCode
        } catch CouponVerificationError.emptySignature {
            return .emptySignature
        } catch {
            return .invalidSignature
        }
    }
}
