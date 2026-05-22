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
}
