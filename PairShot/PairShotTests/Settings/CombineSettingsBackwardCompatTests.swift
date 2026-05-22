import Foundation
@testable import PairShot
import Testing

struct CombineSettingsBackwardCompatTests {
    @Test
    func `legacy JSON without new keys decodes with default placement and border positions`() throws {
        let legacyJSON = """
        {
            "direction": "vertical",
            "border": {
                "isEnabled": true,
                "thickness": 24,
                "color": {"red": 1, "green": 1, "blue": 1, "alpha": 1}
            },
            "label": {
                "isEnabled": true,
                "beforeText": "X",
                "afterText": "Y",
                "textSizePercent": 5,
                "textColor": {"red": 0, "green": 0, "blue": 0, "alpha": 1}
            },
            "labelMode": "FREE",
            "beforePosition": {"horizontal": "leading", "vertical": "top"},
            "afterPosition": {"horizontal": "leading", "vertical": "top"},
            "fullWidthVertical": "bottom",
            "labelBackground": {
                "isEnabled": true,
                "color": {"red": 0, "green": 0, "blue": 0, "alpha": 1},
                "opacity": 1,
                "cornerRadius": 25,
                "matchBorderColor": true
            }
        }
        """

        let data = try #require(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(CombineSettings.self, from: data)

        #expect(decoded.direction == .vertical)
        #expect(decoded.border.thickness == 24)
        #expect(decoded.label.beforeText == "X")
        #expect(decoded.labelPlacement == .image)
        #expect(decoded.beforeBorderPosition == CombineSettings.BorderLabelPosition(
            horizontal: .leading,
            vertical: .bottom,
        ))
        #expect(decoded.afterBorderPosition == CombineSettings.BorderLabelPosition(
            horizontal: .trailing,
            vertical: .bottom,
        ))
    }

    @Test
    func `라운드트립 — 신규 필드 (.border + custom position) 가 encode → decode 로 보존된다`() throws {
        var settings = CombineSettings()
        settings.labelPlacement = .border
        settings.beforeBorderPosition = CombineSettings.BorderLabelPosition(
            horizontal: .center,
            vertical: .top,
        )
        settings.afterBorderPosition = CombineSettings.BorderLabelPosition(
            horizontal: .leading,
            vertical: .bottom,
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(CombineSettings.self, from: data)

        #expect(decoded.labelPlacement == .border)
        #expect(decoded.beforeBorderPosition.horizontal == .center)
        #expect(decoded.beforeBorderPosition.vertical == .top)
        #expect(decoded.afterBorderPosition.horizontal == .leading)
        #expect(decoded.afterBorderPosition.vertical == .bottom)
    }
}
