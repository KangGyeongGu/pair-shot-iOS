import CoreGraphics
import Foundation
@testable import PairShot
import Testing

struct CompositeRendererEdgeBordersTests {
    private static let paneSize = CGSize(width: 800, height: 600)
    private static let scaleFactor: CGFloat = 1.0
    private static let paneSizes = PaneScaledSizes(before: paneSize, after: paneSize)

    @Test
    func `placement_image 는 모든 변이 base 와 동일 (strip 두께 무시)`() {
        let settings = Self.makeSettings(labelPlacement: .image)
        let edges = EdgeBorders.compute(
            paneSizes: Self.paneSizes,
            layout: .horizontal,
            settings: settings,
            scaleFactor: Self.scaleFactor,
        )
        let base: CGFloat = 10
        #expect(edges.top == base)
        #expect(edges.bottom == base)
        #expect(edges.left == base)
        #expect(edges.right == base)
        #expect(edges.middle == base)
    }

    @Test
    func `placement_border + label off 면 strip 무시 (label off 일 때 변 두께는 base)`() {
        let settings = Self.makeSettings(labelEnabled: false, labelPlacement: .border)
        let edges = EdgeBorders.compute(
            paneSizes: Self.paneSizes,
            layout: .horizontal,
            settings: settings,
            scaleFactor: Self.scaleFactor,
        )
        let base: CGFloat = 10
        #expect(edges.top == base)
        #expect(edges.bottom == base)
        #expect(edges.middle == base)
    }

    @Test
    func `horizontal + before_top + after_bottom — top 과 bottom 두 변 모두 strip, 좌우중 = base`() {
        let settings = Self.makeSettings(
            beforeBorderPosition: .init(horizontal: .leading, vertical: .top),
            afterBorderPosition: .init(horizontal: .trailing, vertical: .bottom),
        )
        let strip = CompositeLabelDrawer.labelStripPx(textSizePercent: 5, paneHeight: 600)
        let edges = EdgeBorders.compute(
            paneSizes: Self.paneSizes,
            layout: .horizontal,
            settings: settings,
            scaleFactor: Self.scaleFactor,
        )
        let base: CGFloat = 10
        #expect(edges.top == max(base, strip))
        #expect(edges.bottom == max(base, strip))
        #expect(edges.left == base)
        #expect(edges.right == base)
        #expect(edges.middle == base)
    }

    @Test
    func `horizontal + before_top + after_top — top 만 strip, bottom 은 base`() {
        let settings = Self.makeSettings(
            beforeBorderPosition: .init(horizontal: .leading, vertical: .top),
            afterBorderPosition: .init(horizontal: .trailing, vertical: .top),
        )
        let strip = CompositeLabelDrawer.labelStripPx(textSizePercent: 5, paneHeight: 600)
        let edges = EdgeBorders.compute(
            paneSizes: Self.paneSizes,
            layout: .horizontal,
            settings: settings,
            scaleFactor: Self.scaleFactor,
        )
        let base: CGFloat = 10
        #expect(edges.top == max(base, strip))
        #expect(edges.bottom == base)
    }

    @Test
    func `vertical + before_bottom + after_top — middle 분리선만 strip (외곽 top_bottom = base)`() {
        let settings = Self.makeSettings(
            beforeBorderPosition: .init(horizontal: .leading, vertical: .bottom),
            afterBorderPosition: .init(horizontal: .leading, vertical: .top),
        )
        let strip = CompositeLabelDrawer.labelStripPx(textSizePercent: 5, paneHeight: 600)
        let edges = EdgeBorders.compute(
            paneSizes: Self.paneSizes,
            layout: .vertical,
            settings: settings,
            scaleFactor: Self.scaleFactor,
        )
        let base: CGFloat = 10
        #expect(edges.top == base)
        #expect(edges.bottom == base)
        #expect(edges.middle == max(base, strip))
    }

    @Test
    func `vertical + before_top + after_bottom — 외곽 top_bottom 두 변 모두 strip, middle = base`() {
        let settings = Self.makeSettings(
            beforeBorderPosition: .init(horizontal: .leading, vertical: .top),
            afterBorderPosition: .init(horizontal: .leading, vertical: .bottom),
        )
        let strip = CompositeLabelDrawer.labelStripPx(textSizePercent: 5, paneHeight: 600)
        let edges = EdgeBorders.compute(
            paneSizes: Self.paneSizes,
            layout: .vertical,
            settings: settings,
            scaleFactor: Self.scaleFactor,
        )
        let base: CGFloat = 10
        #expect(edges.top == max(base, strip))
        #expect(edges.bottom == max(base, strip))
        #expect(edges.middle == base)
    }

    @Test
    func `border off + placement_border + label on — base 는 0, 레이블 변만 strip`() {
        let settings = Self.makeSettings(
            borderEnabled: false,
            beforeBorderPosition: .init(horizontal: .leading, vertical: .top),
            afterBorderPosition: .init(horizontal: .trailing, vertical: .bottom),
        )
        let strip = CompositeLabelDrawer.labelStripPx(textSizePercent: 5, paneHeight: 600)
        let edges = EdgeBorders.compute(
            paneSizes: Self.paneSizes,
            layout: .horizontal,
            settings: settings,
            scaleFactor: Self.scaleFactor,
        )
        #expect(edges.top == strip)
        #expect(edges.bottom == strip)
        #expect(edges.left == 0)
        #expect(edges.right == 0)
        #expect(edges.middle == 0)
    }

    @Test
    func `scaleFactor 는 base 두께에만 배율 적용 (strip 은 paneHeight 기반이라 무관)`() {
        let settings = Self.makeSettings(borderThickness: 10)
        let edges1 = EdgeBorders.compute(
            paneSizes: Self.paneSizes,
            layout: .horizontal,
            settings: settings,
            scaleFactor: 1.0,
        )
        let edges2 = EdgeBorders.compute(
            paneSizes: Self.paneSizes,
            layout: .horizontal,
            settings: settings,
            scaleFactor: 2.0,
        )
        #expect(edges1.left == 10)
        #expect(edges2.left == 20)
    }

    private static func makeSettings(
        borderEnabled: Bool = true,
        borderThickness: Double = 10,
        labelEnabled: Bool = true,
        labelPlacement: CombineSettings.LabelPlacement = .border,
        beforeBorderPosition: CombineSettings.BorderLabelPosition = .init(horizontal: .leading, vertical: .top),
        afterBorderPosition: CombineSettings.BorderLabelPosition = .init(horizontal: .trailing, vertical: .bottom),
        textSizePercent: Double = 5,
    ) -> CombineSettings {
        var settings = CombineSettings()
        settings.border = CombineSettings.Border(
            isEnabled: borderEnabled,
            thickness: borderThickness,
            color: .white,
        )
        settings.label = CombineSettings.Label(
            isEnabled: labelEnabled,
            textSizePercent: textSizePercent,
        )
        settings.labelPlacement = labelPlacement
        settings.beforeBorderPosition = beforeBorderPosition
        settings.afterBorderPosition = afterBorderPosition
        return settings
    }
}
