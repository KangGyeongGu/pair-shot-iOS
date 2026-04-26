import CryptoKit
import Foundation
@testable import PairShot
import XCTest

/// P6.3 — Ed25519 signature verification for coupon redemption.
final class CouponVerifierTests: XCTestCase {
    /// A freshly-generated key pair, scoped to a single test, used to
    /// sign a payload we then ask `CouponVerifier` to validate.
    private struct TestKeys {
        let privateKey: Curve25519.Signing.PrivateKey
        let publicKeyBase64: String

        init() {
            let pk = Curve25519.Signing.PrivateKey()
            privateKey = pk
            publicKeyBase64 = pk.publicKey.rawRepresentation.base64EncodedString()
        }

        func sign(_ code: String) throws -> String {
            let signature = try privateKey.signature(for: Data(code.utf8))
            return signature.base64EncodedString()
        }
    }

    // MARK: - happy paths

    func testValidSignatureVerifies() throws {
        let keys = TestKeys()
        let code = "PAIRSHOT-FREE-2026"
        let signature = try keys.sign(code)

        let result = try CouponVerifier.verify(
            code: code,
            signatureBase64: signature,
            publicKeyBase64: keys.publicKeyBase64
        )

        XCTAssertTrue(result)
    }

    func testValidSignatureForKoreanCodeVerifies() throws {
        let keys = TestKeys()
        let code = "쿠폰-한국어-1234"
        let signature = try keys.sign(code)

        XCTAssertTrue(try CouponVerifier.verify(
            code: code,
            signatureBase64: signature,
            publicKeyBase64: keys.publicKeyBase64
        ))
    }

    // MARK: - edge / failure paths

    func testTamperedCodeFailsVerification() throws {
        let keys = TestKeys()
        let signature = try keys.sign("ORIGINAL-CODE")

        let result = try CouponVerifier.verify(
            code: "TAMPERED-CODE",
            signatureBase64: signature,
            publicKeyBase64: keys.publicKeyBase64
        )

        XCTAssertFalse(result)
    }

    func testTamperedSignatureFailsVerification() throws {
        let keys = TestKeys()
        let code = "VALID-CODE"
        var signatureData = try Data(
            base64Encoded: try keys.sign(code)
        ) ?? Data()
        XCTAssertFalse(signatureData.isEmpty)
        // Flip the first byte to corrupt the signature.
        signatureData[0] ^= 0xFF
        let tampered = signatureData.base64EncodedString()

        let result = try CouponVerifier.verify(
            code: code,
            signatureBase64: tampered,
            publicKeyBase64: keys.publicKeyBase64
        )

        XCTAssertFalse(result)
    }

    func testWrongPublicKeyFailsVerification() throws {
        let issuer = TestKeys()
        let attacker = TestKeys()
        let code = "X"
        let signature = try issuer.sign(code)

        let result = try CouponVerifier.verify(
            code: code,
            signatureBase64: signature,
            publicKeyBase64: attacker.publicKeyBase64
        )

        XCTAssertFalse(result)
    }

    func testEmptyCodeThrows() {
        XCTAssertThrowsError(
            try CouponVerifier.verify(
                code: "",
                signatureBase64: "AA==",
                publicKeyBase64: TestKeys().publicKeyBase64
            )
        ) { error in
            XCTAssertEqual(error as? CouponVerificationError, .emptyCode)
        }
    }

    func testEmptySignatureThrows() {
        XCTAssertThrowsError(
            try CouponVerifier.verify(
                code: "X",
                signatureBase64: "",
                publicKeyBase64: TestKeys().publicKeyBase64
            )
        ) { error in
            XCTAssertEqual(error as? CouponVerificationError, .emptySignature)
        }
    }

    func testMalformedSignatureBase64Throws() {
        XCTAssertThrowsError(
            try CouponVerifier.verify(
                code: "X",
                signatureBase64: "@@@not-base64@@@",
                publicKeyBase64: TestKeys().publicKeyBase64
            )
        ) { error in
            XCTAssertEqual(error as? CouponVerificationError, .malformedSignature)
        }
    }

    func testMalformedPublicKeyBase64Throws() throws {
        let keys = TestKeys()
        let signature = try keys.sign("CODE")
        XCTAssertThrowsError(
            try CouponVerifier.verify(
                code: "CODE",
                signatureBase64: signature,
                publicKeyBase64: "@@@not-base64@@@"
            )
        ) { error in
            XCTAssertEqual(error as? CouponVerificationError, .malformedPublicKey)
        }
    }

    func testWrongLengthPublicKeyThrows() throws {
        let keys = TestKeys()
        let signature = try keys.sign("CODE")
        // 16 zero bytes — too short for Curve25519 public key (needs 32).
        let shortKey = Data(repeating: 0, count: 16).base64EncodedString()
        XCTAssertThrowsError(
            try CouponVerifier.verify(
                code: "CODE",
                signatureBase64: signature,
                publicKeyBase64: shortKey
            )
        ) { error in
            XCTAssertEqual(error as? CouponVerificationError, .malformedPublicKey)
        }
    }
}
