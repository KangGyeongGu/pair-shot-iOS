import Foundation
@testable import PairShot
import Testing

@MainActor
struct WatermarkSettingsBlankTests {
    @Test
    func `Text type with empty text is blank`() {
        let settings = WatermarkSettings(type: .text, text: "")
        #expect(settings.isBlank == true)
    }

    @Test
    func `Text type with whitespace-only text is blank`() {
        let settings = WatermarkSettings(type: .text, text: "   \n\t ")
        #expect(settings.isBlank == true)
    }

    @Test
    func `Text type with non-empty text is not blank`() {
        let settings = WatermarkSettings(type: .text, text: "Hello")
        #expect(settings.isBlank == false)
    }

    @Test
    func `Logo type with nil image data is blank`() {
        let settings = WatermarkSettings(type: .logo, logoImageData: nil)
        #expect(settings.isBlank == true)
    }

    @Test
    func `Logo type with image data is not blank`() {
        let bytes = Data([0x01, 0x02, 0x03])
        let settings = WatermarkSettings(type: .logo, logoImageData: bytes)
        #expect(settings.isBlank == false)
    }
}
