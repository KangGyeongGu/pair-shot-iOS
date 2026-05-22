import CoreGraphics
import Foundation
@testable import PairShot
import Testing

struct CompositeLabelDrawerBorderStripTests {
    private static let edges = EdgeBorders(
        top: 60,
        bottom: 60,
        left: 10,
        right: 10,
        middle: 50,
    )

    @Test
    func `horizontal + before_top — strip 은 canvas top 에 paneRect 의 가로폭으로 위치`() {
        let beforeRect = CGRect(x: 10, y: 60, width: 400, height: 300)
        let canvas = CGSize(width: 870, height: 420)
        let rect = CompositeLabelDrawer.borderStripRect(
            position: .init(horizontal: .leading, vertical: .top),
            paneRect: beforeRect,
            edges: Self.edges,
            canvas: canvas,
            layout: .horizontal,
            isBefore: true,
        )
        #expect(rect.minX == beforeRect.minX)
        #expect(rect.minY == 0)
        #expect(rect.width == beforeRect.width)
        #expect(rect.height == Self.edges.top)
    }

    @Test
    func `horizontal + after_bottom — strip 은 canvas bottom 에 paneRect 의 가로폭으로 위치`() {
        let afterRect = CGRect(x: 460, y: 60, width: 400, height: 300)
        let canvas = CGSize(width: 870, height: 420)
        let rect = CompositeLabelDrawer.borderStripRect(
            position: .init(horizontal: .center, vertical: .bottom),
            paneRect: afterRect,
            edges: Self.edges,
            canvas: canvas,
            layout: .horizontal,
            isBefore: false,
        )
        #expect(rect.minX == afterRect.minX)
        #expect(rect.minY == canvas.height - Self.edges.bottom)
        #expect(rect.width == afterRect.width)
        #expect(rect.height == Self.edges.bottom)
    }

    @Test
    func `vertical + before_top — strip 은 canvas top 변 (외곽)`() {
        let beforeRect = CGRect(x: 10, y: 60, width: 400, height: 300)
        let canvas = CGSize(width: 420, height: 770)
        let rect = CompositeLabelDrawer.borderStripRect(
            position: .init(horizontal: .leading, vertical: .top),
            paneRect: beforeRect,
            edges: Self.edges,
            canvas: canvas,
            layout: .vertical,
            isBefore: true,
        )
        #expect(rect.minX == beforeRect.minX)
        #expect(rect.minY == 0)
        #expect(rect.width == beforeRect.width)
        #expect(rect.height == Self.edges.top)
    }

    @Test
    func `vertical + before_bottom — strip 은 middle 분리선 (beforeRect 의 maxY 바로 아래)`() {
        let beforeRect = CGRect(x: 10, y: 60, width: 400, height: 300)
        let canvas = CGSize(width: 420, height: 770)
        let rect = CompositeLabelDrawer.borderStripRect(
            position: .init(horizontal: .center, vertical: .bottom),
            paneRect: beforeRect,
            edges: Self.edges,
            canvas: canvas,
            layout: .vertical,
            isBefore: true,
        )
        #expect(rect.minX == beforeRect.minX)
        #expect(rect.minY == beforeRect.maxY)
        #expect(rect.width == beforeRect.width)
        #expect(rect.height == Self.edges.middle)
    }

    @Test
    func `vertical + after_top — strip 은 middle 분리선 (afterRect 의 minY 바로 위)`() {
        let afterRect = CGRect(x: 10, y: 410, width: 400, height: 300)
        let canvas = CGSize(width: 420, height: 770)
        let rect = CompositeLabelDrawer.borderStripRect(
            position: .init(horizontal: .leading, vertical: .top),
            paneRect: afterRect,
            edges: Self.edges,
            canvas: canvas,
            layout: .vertical,
            isBefore: false,
        )
        #expect(rect.minX == afterRect.minX)
        #expect(rect.minY == afterRect.minY - Self.edges.middle)
        #expect(rect.width == afterRect.width)
        #expect(rect.height == Self.edges.middle)
    }

    @Test
    func `vertical + after_bottom — strip 은 canvas bottom 변 (외곽)`() {
        let afterRect = CGRect(x: 10, y: 410, width: 400, height: 300)
        let canvas = CGSize(width: 420, height: 770)
        let rect = CompositeLabelDrawer.borderStripRect(
            position: .init(horizontal: .trailing, vertical: .bottom),
            paneRect: afterRect,
            edges: Self.edges,
            canvas: canvas,
            layout: .vertical,
            isBefore: false,
        )
        #expect(rect.minX == afterRect.minX)
        #expect(rect.minY == canvas.height - Self.edges.bottom)
        #expect(rect.width == afterRect.width)
        #expect(rect.height == Self.edges.bottom)
    }

    @Test
    func `labelStripPx — fontSize × (rectHeightFactor + marginFactor × 2)`() {
        let strip = CompositeLabelDrawer.labelStripPx(textSizePercent: 5, paneHeight: 2000)
        let fontSize = CompositeLabelDrawer.resolveFontSize(textSizePercent: 5, imageHeight: 2000)
        let expected = fontSize *
            (CompositeLabelDrawer.LabelMetrics.rectHeightFactor +
                CompositeLabelDrawer.LabelMetrics.marginFactor * 2)
        #expect(strip == expected)
    }
}
