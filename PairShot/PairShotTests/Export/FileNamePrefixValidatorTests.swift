import Foundation
@testable import PairShot
import Testing

struct FileNamePrefixValidatorTests {
    @Test
    func `빈 문자열은 빈 문자열 그대로 반환`() {
        #expect(FileNamePrefixValidator.sanitize("").isEmpty)
    }

    @Test
    func `앞뒤 공백은 trim 됨`() {
        #expect(FileNamePrefixValidator.sanitize("  Site  ") == "Site")
    }

    @Test
    func `공백만 입력시 빈 문자열로 fallback`() {
        #expect(FileNamePrefixValidator.sanitize("    ").isEmpty)
    }

    @Test
    func `금지문자 (slash, colon, asterisk 등) 는 제거됨`() {
        let sanitized = FileNamePrefixValidator.sanitize("A/B\\C:D?E*F\"G<H>I|J")
        #expect(sanitized == "ABCDEFGHIJ")
    }

    @Test
    func `금지문자만 입력시 빈 문자열로 fallback`() {
        let sanitized = FileNamePrefixValidator.sanitize("///:::***")
        #expect(sanitized.isEmpty)
    }

    @Test
    func `길이 32 자 초과시 prefix 32 자로 trim`() {
        let raw = String(repeating: "A", count: 50)
        let sanitized = FileNamePrefixValidator.sanitize(raw)
        #expect(sanitized.count == FileNamePrefixValidator.maxLength)
        #expect(sanitized == String(repeating: "A", count: 32))
    }

    @Test
    func `한글-숫자-영문 혼합은 모두 허용`() {
        let sanitized = FileNamePrefixValidator.sanitize("현장-Site_007")
        #expect(sanitized == "현장-Site_007")
    }

    @Test
    func `개행 및 control character 는 제거됨`() {
        let sanitized = FileNamePrefixValidator.sanitize("Site\nName\tValue")
        #expect(!sanitized.contains("\n"))
        #expect(!sanitized.contains("\t"))
    }
}
