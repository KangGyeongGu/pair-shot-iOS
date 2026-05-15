import Foundation
@testable import PairShot
import Testing

@MainActor
struct WatermarkSettingsBlankTests {
    @Test("Text type with empty text is blank")
    func textEmptyIsBlank() {
        let settings = WatermarkSettings(type: .text, text: "")
        #expect(settings.isBlank == true)
    }

    @Test("Text type with whitespace-only text is blank")
    func textWhitespaceIsBlank() {
        let settings = WatermarkSettings(type: .text, text: "   \n\t ")
        #expect(settings.isBlank == true)
    }

    @Test("Text type with non-empty text is not blank")
    func textWithContentIsNotBlank() {
        let settings = WatermarkSettings(type: .text, text: "Hello")
        #expect(settings.isBlank == false)
    }

    @Test("Logo type with nil image data is blank")
    func logoNilIsBlank() {
        let settings = WatermarkSettings(type: .logo, logoImageData: nil)
        #expect(settings.isBlank == true)
    }

    @Test("Logo type with image data is not blank")
    func logoWithDataIsNotBlank() {
        let bytes = Data([0x01, 0x02, 0x03])
        let settings = WatermarkSettings(type: .logo, logoImageData: bytes)
        #expect(settings.isBlank == false)
    }
}
