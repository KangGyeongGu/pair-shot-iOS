import CryptoKit
import Foundation

/// Errors thrown by `CouponVerifier`.
enum CouponVerificationError: Error, Equatable {
    /// `signatureBase64` could not be decoded as base64.
    case malformedSignature
    /// `publicKeyBase64` could not be decoded as base64 or is not a valid
    /// 32-byte Ed25519 public key.
    case malformedPublicKey
    /// The supplied `code` was empty — payload must have at least one byte.
    case emptyCode
    /// The supplied signature was empty after decoding.
    case emptySignature
}

/// Verifies coupon codes signed off-line by the issuer (apricity) using
/// Ed25519 (`CryptoKit.Curve25519.Signing.PublicKey`).
///
/// The android client uses the same key and same scheme — payload =
/// `code.utf8`, signature = Ed25519 over that payload, encoded as base64.
///
/// **Public key**: must be the same 32-byte Ed25519 public key the
/// android app embeds. The placeholder below is a 32-byte zero key so the
/// project compiles in CI without leaking the real key into a public repo
/// — replace via xcconfig (P10.5) or with a build-time constant in a
/// future task. **Production builds will reject every coupon until this
/// is replaced.**
enum CouponVerifier {
    /// Base64 of a 32-byte zero key — placeholder. Replace with the real
    /// apricity public key before TestFlight (see roadmap P10.5).
    /// TODO(P6c): swap to real key via xcconfig-injected Info.plist key.
    static let placeholderPublicKeyBase64 = Data(repeating: 0, count: 32).base64EncodedString()

    /// Verifies that `signatureBase64` is a valid Ed25519 signature over
    /// the UTF-8 bytes of `code` under `publicKeyBase64`.
    ///
    /// - Parameters:
    ///   - code: The signed payload (the coupon code itself).
    ///   - signatureBase64: Base64-encoded Ed25519 signature.
    ///   - publicKeyBase64: Base64-encoded 32-byte Ed25519 public key.
    /// - Returns: `true` if the signature is valid, `false` if it is
    ///            cryptographically invalid.
    /// - Throws: `CouponVerificationError` for malformed inputs.
    static func verify(
        code: String,
        signatureBase64: String,
        publicKeyBase64: String = placeholderPublicKeyBase64
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
