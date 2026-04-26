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
/// **Public key resolution (Audit-B)**: callers that don't supply an
/// explicit `publicKeyBase64` get the value resolved by
/// ``resolvedPublicKeyBase64(bundle:)``, which reads
/// `Info.plist[CouponPublicKeyBase64]` (injected by `Release.xcconfig`'s
/// `COUPON_PUBLIC_KEY` build setting at archive time) and falls back to
/// the 32-byte zero placeholder when the key is absent or empty (DEBUG
/// builds, internal TestFlight before the issuer key is minted, CI
/// pipelines without `Release.xcconfig`). The placeholder will reject
/// every real coupon — that's intentional, so a forgotten xcconfig
/// substitution surfaces during QA rather than silently shipping.
enum CouponVerifier {
    /// Info.plist key the verifier consults for the runtime public key.
    /// Must match the literal key declared in `PairShot/Info.plist`.
    static let infoPlistKey = "CouponPublicKeyBase64"

    /// Base64 of a 32-byte zero key — placeholder. Used when the
    /// Info.plist key is absent / empty / still the xcconfig
    /// substitution sentinel. **Production builds will reject every
    /// real coupon until ``resolvedPublicKeyBase64(bundle:)`` returns
    /// the issuer's actual key.**
    static let placeholderPublicKeyBase64 = Data(repeating: 0, count: 32).base64EncodedString()

    /// Resolves the runtime public key. Reads
    /// `Info.plist[CouponPublicKeyBase64]` and falls back to
    /// ``placeholderPublicKeyBase64`` when the value is missing or
    /// empty. Test seam: `bundle` defaults to `.main` in production,
    /// callers in unit tests can pass `Bundle(for:)` of a test class
    /// to exercise the missing-key branch deterministically.
    static func resolvedPublicKeyBase64(bundle: Bundle = .main) -> String {
        guard
            let value = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return placeholderPublicKeyBase64
        }
        return value
    }

    /// Verifies that `signatureBase64` is a valid Ed25519 signature over
    /// the UTF-8 bytes of `code` under `publicKeyBase64`.
    ///
    /// - Parameters:
    ///   - code: The signed payload (the coupon code itself).
    ///   - signatureBase64: Base64-encoded Ed25519 signature.
    ///   - publicKeyBase64: Base64-encoded 32-byte Ed25519 public key.
    ///     Defaults to ``resolvedPublicKeyBase64(bundle:)`` so callers
    ///     can omit it in production.
    /// - Returns: `true` if the signature is valid, `false` if it is
    ///            cryptographically invalid.
    /// - Throws: `CouponVerificationError` for malformed inputs.
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
