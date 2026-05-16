import Foundation
@testable import PairShot
import Testing

@MainActor
struct EffectiveProGatingTests {
    @Test
    func `Watermark Pro user with logo type keeps logo`() {
        let settings = WatermarkSettings(type: .logo)
        let result = settings.effective(isPro: true)
        #expect(result.type == .logo)
    }

    @Test
    func `Watermark Pro user with text type keeps text`() {
        let settings = WatermarkSettings(type: .text)
        let result = settings.effective(isPro: true)
        #expect(result.type == .text)
    }

    @Test
    func `Watermark Free user with logo type is forced to text`() {
        let settings = WatermarkSettings(type: .logo)
        let result = settings.effective(isPro: false)
        #expect(result.type == .text)
    }

    @Test
    func `Watermark Free user with text type stays text`() {
        let settings = WatermarkSettings(type: .text)
        let result = settings.effective(isPro: false)
        #expect(result.type == .text)
    }

    @Test
    func `Watermark Free user with logo type preserves logo-related fields`() {
        let logoData = Data([0x01, 0x02, 0x03, 0x04])
        let settings = WatermarkSettings(
            type: .logo,
            logoImageData: logoData,
            logoFileName: "company.png",
            logoPosition: .bottomRight,
            logoWidthRatio: 0.7,
            logoAlpha: 0.8,
        )
        let result = settings.effective(isPro: false)
        #expect(result.type == .text)
        #expect(result.logoImageData == logoData)
        #expect(result.logoFileName == "company.png")
        #expect(result.logoPosition == .bottomRight)
        #expect(result.logoWidthRatio == 0.7)
        #expect(result.logoAlpha == 0.8)
    }

    @Test
    func `Watermark Pro user with logo type preserves all fields including text fields`() {
        let logoData = Data([0xFF, 0xEE])
        let settings = WatermarkSettings(
            type: .logo,
            text: "Sample",
            opacity: 0.7,
            lineCount: 5,
            repeatCount: 2.0,
            textSizeRatio: 0.04,
            logoImageData: logoData,
            logoFileName: "brand.png",
            logoPosition: .topLeft,
            logoWidthRatio: 0.6,
            logoAlpha: 0.9,
        )
        let result = settings.effective(isPro: true)
        #expect(result == settings)
    }

    @Test
    func `Combine Pro user with label enabled keeps label enabled`() {
        let settings = CombineSettings(label: CombineSettings.Label(isEnabled: true))
        let result = settings.effective(isPro: true)
        #expect(result.label.isEnabled == true)
    }

    @Test
    func `Combine Pro user with label disabled keeps label disabled`() {
        let settings = CombineSettings(label: CombineSettings.Label(isEnabled: false))
        let result = settings.effective(isPro: true)
        #expect(result.label.isEnabled == false)
    }

    @Test
    func `Combine Free user with label enabled is forced to disabled`() {
        let settings = CombineSettings(label: CombineSettings.Label(isEnabled: true))
        let result = settings.effective(isPro: false)
        #expect(result.label.isEnabled == false)
    }

    @Test
    func `Combine Free user with label disabled stays disabled`() {
        let settings = CombineSettings(label: CombineSettings.Label(isEnabled: false))
        let result = settings.effective(isPro: false)
        #expect(result.label.isEnabled == false)
    }

    @Test
    func `Combine Free user with label enabled preserves label text and style fields`() {
        let label = CombineSettings.Label(
            isEnabled: true,
            beforeText: "전",
            afterText: "후",
            textSizePercent: 7.5,
            textColor: ColorRGBA(red: 0.2, green: 0.4, blue: 0.6),
        )
        let settings = CombineSettings(label: label)
        let result = settings.effective(isPro: false)
        #expect(result.label.isEnabled == false)
        #expect(result.label.beforeText == "전")
        #expect(result.label.afterText == "후")
        #expect(result.label.textSizePercent == 7.5)
        #expect(result.label.textColor.red == 0.2)
        #expect(result.label.textColor.green == 0.4)
        #expect(result.label.textColor.blue == 0.6)
    }

    @Test
    func `Combine Free user with label enabled preserves direction border and positions`() {
        let border = CombineSettings.Border(
            isEnabled: true,
            thickness: 24.0,
            color: ColorRGBA(red: 1, green: 0, blue: 0),
        )
        let beforePos = CombineSettings.LabelPosition(horizontal: .trailing, vertical: .bottom)
        let afterPos = CombineSettings.LabelPosition(horizontal: .leading, vertical: .top)
        let background = CombineSettings.LabelBackground(
            isEnabled: true,
            color: ColorRGBA(red: 0, green: 1, blue: 0),
            opacity: 0.75,
            cornerRadius: 12.0,
            matchBorderColor: false,
        )
        let settings = CombineSettings(
            direction: .vertical,
            border: border,
            label: CombineSettings.Label(isEnabled: true),
            labelMode: .fullWidth,
            beforePosition: beforePos,
            afterPosition: afterPos,
            fullWidthVertical: .middle,
            labelBackground: background,
        )
        let result = settings.effective(isPro: false)
        #expect(result.label.isEnabled == false)
        #expect(result.direction == .vertical)
        #expect(result.border == border)
        #expect(result.labelMode == .fullWidth)
        #expect(result.beforePosition == beforePos)
        #expect(result.afterPosition == afterPos)
        #expect(result.fullWidthVertical == .middle)
        #expect(result.labelBackground == background)
    }

    @Test
    func `Combine Pro user with label enabled preserves entire struct`() {
        let settings = CombineSettings(
            direction: .vertical,
            label: CombineSettings.Label(isEnabled: true, beforeText: "B", afterText: "A"),
        )
        let result = settings.effective(isPro: true)
        #expect(result == settings)
    }
}
