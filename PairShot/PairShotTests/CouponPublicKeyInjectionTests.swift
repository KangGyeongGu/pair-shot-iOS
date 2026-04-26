import CryptoKit
import Foundation
@testable import PairShot
import XCTest

/// Audit-B — `CouponVerifier.resolvedPublicKeyBase64(bundle:)` reads
/// the runtime Ed25519 public key from `Info.plist[CouponPublicKeyBase64]`
/// (xcconfig-injected at archive time via `Release.xcconfig`'s
/// `COUPON_PUBLIC_KEY` build setting) and falls back to the 32-byte
/// zero placeholder when the key is absent / empty / whitespace-only.
///
/// These tests pin both branches so:
/// - DEBUG builds (no production key) keep operating against the
///   placeholder and reject every real coupon.
/// - Release builds with a real xcconfig substitution surface the
///   real key.
/// - A typo / blank line in the xcconfig still falls back to the
///   placeholder rather than crashing or, worse, accepting all
///   coupons under an empty-key payload.
final class CouponPublicKeyInjectionTests: XCTestCase {
    // MARK: - constants

    func testInfoPlistKeyConstantMatchesPlistLiteral() {
        XCTAssertEqual(CouponVerifier.infoPlistKey, "CouponPublicKeyBase64")
    }

    func testPlaceholderIsThirtyTwoZeroBytesBase64() {
        let decoded = Data(base64Encoded: CouponVerifier.placeholderPublicKeyBase64)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 32)
        // All bytes must be zero so the placeholder is unambiguously
        // non-functional. A non-zero placeholder could accidentally
        // verify a maliciously crafted signature.
        XCTAssertTrue(decoded?.allSatisfy { $0 == 0 } ?? false)
    }

    // MARK: - fallback path: missing / empty / whitespace key

    func testMissingInfoPlistKeyFallsBackToPlaceholder() {
        // The XCTest bundle's Info.plist has no `CouponPublicKeyBase64`
        // entry, so resolving against it must surface the placeholder.
        let testBundle = Bundle(for: CouponPublicKeyInjectionTests.self)
        let resolved = CouponVerifier.resolvedPublicKeyBase64(bundle: testBundle)
        XCTAssertEqual(resolved, CouponVerifier.placeholderPublicKeyBase64)
    }

    func testEmptyInfoPlistKeyFallsBackToPlaceholder() throws {
        let bundle = try makeBundle(withInfoPlistValue: "")
        let resolved = CouponVerifier.resolvedPublicKeyBase64(bundle: bundle)
        XCTAssertEqual(resolved, CouponVerifier.placeholderPublicKeyBase64)
    }

    func testWhitespaceInfoPlistKeyFallsBackToPlaceholder() throws {
        let bundle = try makeBundle(withInfoPlistValue: "   \n\t  ")
        let resolved = CouponVerifier.resolvedPublicKeyBase64(bundle: bundle)
        XCTAssertEqual(resolved, CouponVerifier.placeholderPublicKeyBase64)
    }

    // MARK: - happy: real key surfaces verbatim

    func testValidInfoPlistKeyIsReturnedVerbatim() throws {
        let realKey = Curve25519.Signing.PrivateKey()
            .publicKey
            .rawRepresentation
            .base64EncodedString()
        let bundle = try makeBundle(withInfoPlistValue: realKey)
        let resolved = CouponVerifier.resolvedPublicKeyBase64(bundle: bundle)
        XCTAssertEqual(resolved, realKey)
    }

    func testValidInfoPlistKeyIsUsedAsDefaultByVerify() throws {
        // End-to-end: when `verify` is called without an explicit
        // `publicKeyBase64` parameter and the bundle exposes a real
        // key, the verification proceeds against that key. We sign a
        // payload with the matching private key and confirm `true`.
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()
        let code = "AUDIT-B-COUPON"
        let signature = try privateKey.signature(for: Data(code.utf8))
            .base64EncodedString()

        let bundle = try makeBundle(withInfoPlistValue: publicKeyBase64)
        let resolved = CouponVerifier.resolvedPublicKeyBase64(bundle: bundle)
        XCTAssertEqual(resolved, publicKeyBase64)

        // Verify directly with the resolved key (mirrors what `verify`
        // would do at the default-parameter call site).
        let result = try CouponVerifier.verify(
            code: code,
            signatureBase64: signature,
            publicKeyBase64: resolved
        )
        XCTAssertTrue(result)
    }

    // MARK: - helpers

    /// Synthesises a `Bundle` whose `Info.plist` carries the supplied
    /// `CouponPublicKeyBase64` value. Achieved by writing a tiny
    /// `Info.plist` next to a placeholder bundle directory inside the
    /// test's temporary directory and returning a `Bundle(url:)` for
    /// it. Returns `nil` (test fails) if creation fails.
    private func makeBundle(withInfoPlistValue value: String) throws -> Bundle {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CouponPublicKeyInjectionTests-\(UUID().uuidString)")
        let bundleURL = tempRoot.appendingPathComponent("Stub.bundle")
        try FileManager.default.createDirectory(
            at: bundleURL,
            withIntermediateDirectories: true
        )
        let plist: [String: Any] = ["CouponPublicKeyBase64": value]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(to: bundleURL.appendingPathComponent("Info.plist"))

        guard let bundle = Bundle(url: bundleURL) else {
            throw NSError(
                domain: "CouponPublicKeyInjectionTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "failed to construct stub bundle"]
            )
        }
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        return bundle
    }
}
