import Foundation
@testable import PairShot
import XCTest

/// P6.4 — `QRPayloadParser` decodes the `<code>.<signatureBase64>` token
/// produced by the QR scanner / pasted manually.
final class QRPayloadParserTests: XCTestCase {
    // MARK: - happy

    func testParsesValidToken() throws {
        let payload = try QRPayloadParser.parse("PAIRSHOT-2026.dGVzdA==")
        XCTAssertEqual(payload.code, "PAIRSHOT-2026")
        XCTAssertEqual(payload.signatureBase64, "dGVzdA==")
    }

    func testTrimsLeadingAndTrailingWhitespace() throws {
        let payload = try QRPayloadParser.parse("   CODE.SIG   \n")
        XCTAssertEqual(payload.code, "CODE")
        XCTAssertEqual(payload.signatureBase64, "SIG")
    }

    func testKoreanUnicodeCodeIsParsed() throws {
        let payload = try QRPayloadParser.parse("쿠폰-한글.QUFB")
        XCTAssertEqual(payload.code, "쿠폰-한글")
        XCTAssertEqual(payload.signatureBase64, "QUFB")
    }

    // MARK: - edge / failure

    func testEmptyInputThrows() {
        XCTAssertThrowsError(try QRPayloadParser.parse("")) { error in
            XCTAssertEqual(error as? QRPayloadParseError, .empty)
        }
    }

    func testWhitespaceOnlyInputThrows() {
        XCTAssertThrowsError(try QRPayloadParser.parse("   \n\t ")) { error in
            XCTAssertEqual(error as? QRPayloadParseError, .empty)
        }
    }

    func testMissingSeparatorThrows() {
        XCTAssertThrowsError(try QRPayloadParser.parse("CODE-SIG")) { error in
            XCTAssertEqual(error as? QRPayloadParseError, .wrongSeparatorCount)
        }
    }

    func testTwoSeparatorsThrows() {
        XCTAssertThrowsError(try QRPayloadParser.parse("CODE.SIG.EXTRA")) { error in
            XCTAssertEqual(error as? QRPayloadParseError, .wrongSeparatorCount)
        }
    }

    func testEmptyCodeHalfThrows() {
        XCTAssertThrowsError(try QRPayloadParser.parse(".SIG")) { error in
            XCTAssertEqual(error as? QRPayloadParseError, .emptyCode)
        }
    }

    func testEmptySignatureHalfThrows() {
        XCTAssertThrowsError(try QRPayloadParser.parse("CODE.")) { error in
            XCTAssertEqual(error as? QRPayloadParseError, .emptySignature)
        }
    }

    func testBothHalvesEmptyThrows() {
        // "." → split with omittingEmptySubsequences:false → ["", ""]
        // → first empty-half guard fires (.emptyCode).
        XCTAssertThrowsError(try QRPayloadParser.parse(".")) { error in
            XCTAssertEqual(error as? QRPayloadParseError, .emptyCode)
        }
    }
}
