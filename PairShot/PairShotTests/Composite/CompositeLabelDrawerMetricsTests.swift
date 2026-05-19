import CoreGraphics
import Foundation
@testable import PairShot
import Testing

struct CompositeLabelDrawerMetricsTests {
    @Test
    func `resolveFontSize 는 textSizePercent×0_01×imageHeight 를 반환`() {
        let result = CompositeLabelDrawer.resolveFontSize(textSizePercent: 5, imageHeight: 2000)
        #expect(result == 100)
    }

    @Test
    func `resolveFontSize 는 minFontSize 10 으로 clamp`() {
        let result = CompositeLabelDrawer.resolveFontSize(textSizePercent: 1, imageHeight: 100)
        #expect(result == CompositeLabelDrawer.LabelMetrics.minFontSize)
    }

    @Test
    func `fullWidthLabelRect 는 imageRect 의 전체 width 를 사용 (좌우 가장자리 붙음)`() {
        let imageRect = CGRect(x: 100, y: 200, width: 3000, height: 2000)
        let rect = CompositeLabelDrawer.fullWidthLabelRect(
            imageRect: imageRect,
            fontSize: 100,
            vertical: .top,
        )
        #expect(rect.minX == imageRect.minX)
        #expect(rect.width == imageRect.width)
    }

    @Test
    func `fullWidthLabelRect 의 height 는 fontSize × 1_6 (rectHeightFactor)`() {
        let imageRect = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let rect = CompositeLabelDrawer.fullWidthLabelRect(
            imageRect: imageRect,
            fontSize: 50,
            vertical: .top,
        )
        #expect(rect.height == 50 * CompositeLabelDrawer.LabelMetrics.rectHeightFactor)
        #expect(rect.height == 80)
    }

    @Test
    func `fullWidthLabelRect top 정렬은 imageRect_minY 와 동일`() {
        let imageRect = CGRect(x: 0, y: 500, width: 1000, height: 1000)
        let rect = CompositeLabelDrawer.fullWidthLabelRect(
            imageRect: imageRect,
            fontSize: 40,
            vertical: .top,
        )
        #expect(rect.minY == 500)
    }

    @Test
    func `fullWidthLabelRect middle 정렬은 imageRect_midY 기준 rectHeight 의 절반 차감`() {
        let imageRect = CGRect(x: 0, y: 500, width: 1000, height: 1000)
        let rect = CompositeLabelDrawer.fullWidthLabelRect(
            imageRect: imageRect,
            fontSize: 50,
            vertical: .middle,
        )
        let rectHeight = 50 * CompositeLabelDrawer.LabelMetrics.rectHeightFactor
        #expect(rect.minY == imageRect.midY - rectHeight / 2)
    }

    @Test
    func `fullWidthLabelRect bottom 정렬은 imageRect_maxY 에서 rectHeight 차감`() {
        let imageRect = CGRect(x: 0, y: 500, width: 1000, height: 1000)
        let rect = CompositeLabelDrawer.fullWidthLabelRect(
            imageRect: imageRect,
            fontSize: 50,
            vertical: .bottom,
        )
        let rectHeight = 50 * CompositeLabelDrawer.LabelMetrics.rectHeightFactor
        #expect(rect.minY == imageRect.maxY - rectHeight)
    }

    @Test
    func `anchoredLabelRect width 는 textWidth + hPad × 2 (rectHeight 보다 크면)`() {
        let imageRect = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let fontSize: CGFloat = 100
        let textWidth: CGFloat = 500
        let rect = CompositeLabelDrawer.anchoredLabelRect(
            imageRect: imageRect,
            fontSize: fontSize,
            textWidth: textWidth,
            anchor: CombineSettings.LabelPosition(horizontal: .leading, vertical: .top),
        )
        let hPad = fontSize * CompositeLabelDrawer.LabelMetrics.horizontalPaddingFactor
        #expect(rect.width == textWidth + hPad * 2)
    }

    @Test
    func `anchoredLabelRect width 는 textWidth 가 작을 때 rectHeight 로 clamp (정사각형 최소 보장)`() {
        let imageRect = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let fontSize: CGFloat = 100
        let rect = CompositeLabelDrawer.anchoredLabelRect(
            imageRect: imageRect,
            fontSize: fontSize,
            textWidth: 5,
            anchor: CombineSettings.LabelPosition(horizontal: .leading, vertical: .top),
        )
        let rectHeight = fontSize * CompositeLabelDrawer.LabelMetrics.rectHeightFactor
        #expect(rect.width == rectHeight)
    }

    @Test
    func `anchoredLabelRect height 는 fontSize × 1_6`() {
        let fontSize: CGFloat = 50
        let rect = CompositeLabelDrawer.anchoredLabelRect(
            imageRect: CGRect(x: 0, y: 0, width: 1000, height: 1000),
            fontSize: fontSize,
            textWidth: 200,
            anchor: CombineSettings.LabelPosition(horizontal: .center, vertical: .middle),
        )
        #expect(rect.height == fontSize * CompositeLabelDrawer.LabelMetrics.rectHeightFactor)
    }

    @Test
    func `anchoredLabelRect leading top — imageRect_minXY 에서 margin 만큼 떨어진 위치`() {
        let imageRect = CGRect(x: 100, y: 200, width: 3000, height: 2000)
        let fontSize: CGFloat = 100
        let rect = CompositeLabelDrawer.anchoredLabelRect(
            imageRect: imageRect,
            fontSize: fontSize,
            textWidth: 500,
            anchor: CombineSettings.LabelPosition(horizontal: .leading, vertical: .top),
        )
        let margin = fontSize * CompositeLabelDrawer.LabelMetrics.marginFactor
        #expect(rect.minX == imageRect.minX + margin)
        #expect(rect.minY == imageRect.minY + margin)
    }

    @Test
    func `anchoredLabelRect trailing bottom — imageRect_maxXY 에서 rect 와 margin 차감`() {
        let imageRect = CGRect(x: 100, y: 200, width: 3000, height: 2000)
        let fontSize: CGFloat = 100
        let textWidth: CGFloat = 500
        let rect = CompositeLabelDrawer.anchoredLabelRect(
            imageRect: imageRect,
            fontSize: fontSize,
            textWidth: textWidth,
            anchor: CombineSettings.LabelPosition(horizontal: .trailing, vertical: .bottom),
        )
        let hPad = fontSize * CompositeLabelDrawer.LabelMetrics.horizontalPaddingFactor
        let rectWidth = textWidth + hPad * 2
        let rectHeight = fontSize * CompositeLabelDrawer.LabelMetrics.rectHeightFactor
        let margin = fontSize * CompositeLabelDrawer.LabelMetrics.marginFactor
        #expect(rect.maxX == imageRect.maxX - margin)
        #expect(rect.maxY == imageRect.maxY - margin)
        #expect(rect.minX == imageRect.maxX - rectWidth - margin)
        #expect(rect.minY == imageRect.maxY - rectHeight - margin)
    }

    @Test
    func `anchoredLabelRect center middle — imageRect 정중앙 정렬`() {
        let imageRect = CGRect(x: 100, y: 200, width: 3000, height: 2000)
        let fontSize: CGFloat = 100
        let textWidth: CGFloat = 500
        let rect = CompositeLabelDrawer.anchoredLabelRect(
            imageRect: imageRect,
            fontSize: fontSize,
            textWidth: textWidth,
            anchor: CombineSettings.LabelPosition(horizontal: .center, vertical: .middle),
        )
        #expect(rect.midX == imageRect.midX)
        #expect(rect.midY == imageRect.midY)
    }

    @Test
    func `computeLabelRect — labelMode_free 는 isBefore 면 beforePosition, 아니면 afterPosition 적용`() {
        let imageRect = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        var settings = CombineSettings()
        settings.labelMode = .free
        settings.beforePosition = CombineSettings.LabelPosition(horizontal: .leading, vertical: .top)
        settings.afterPosition = CombineSettings.LabelPosition(horizontal: .trailing, vertical: .bottom)
        let fontSize: CGFloat = 100
        let textWidth: CGFloat = 300

        let beforeRect = CompositeLabelDrawer.computeLabelRect(
            imageRect: imageRect,
            settings: settings,
            isFree: true,
            isBefore: true,
            fontSize: fontSize,
            textWidth: textWidth,
        )
        let margin = fontSize * CompositeLabelDrawer.LabelMetrics.marginFactor
        #expect(beforeRect.minX == imageRect.minX + margin)
        #expect(beforeRect.minY == imageRect.minY + margin)

        let afterRect = CompositeLabelDrawer.computeLabelRect(
            imageRect: imageRect,
            settings: settings,
            isFree: true,
            isBefore: false,
            fontSize: fontSize,
            textWidth: textWidth,
        )
        #expect(afterRect.maxX == imageRect.maxX - margin)
        #expect(afterRect.maxY == imageRect.maxY - margin)
    }

    @Test
    func `computeLabelRect — labelMode_fullWidth 는 fullWidthVertical 적용 + position 무시`() {
        let imageRect = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        var settings = CombineSettings()
        settings.labelMode = .fullWidth
        settings.fullWidthVertical = .bottom
        settings.beforePosition = CombineSettings.LabelPosition(horizontal: .leading, vertical: .top)
        settings.afterPosition = CombineSettings.LabelPosition(horizontal: .center, vertical: .middle)
        let fontSize: CGFloat = 100

        let rect = CompositeLabelDrawer.computeLabelRect(
            imageRect: imageRect,
            settings: settings,
            isFree: false,
            isBefore: true,
            fontSize: fontSize,
            textWidth: 200,
        )
        let rectHeight = fontSize * CompositeLabelDrawer.LabelMetrics.rectHeightFactor
        #expect(rect.minX == imageRect.minX)
        #expect(rect.width == imageRect.width)
        #expect(rect.minY == imageRect.maxY - rectHeight)
    }

    @Test
    func `LabelMetrics 상수값 정공 — rectHeightFactor=1_6, hPaddingFactor=0_75, marginFactor=0_4, minFontSize=10`() {
        #expect(CompositeLabelDrawer.LabelMetrics.rectHeightFactor == 1.6)
        #expect(CompositeLabelDrawer.LabelMetrics.horizontalPaddingFactor == 0.75)
        #expect(CompositeLabelDrawer.LabelMetrics.marginFactor == 0.4)
        #expect(CompositeLabelDrawer.LabelMetrics.minFontSize == 10)
    }

    @Test
    func `cornerRadius_rectHeight 비율은 fontSize 와 무관 — CombinePreview 정합 invariant`() {
        let cornerRadiusValue: Double = 25
        let scaleFactor: CGFloat = 2.95

        let smallFont: CGFloat = 50
        let smallRectHeight = smallFont * CompositeLabelDrawer.LabelMetrics.rectHeightFactor
        let smallCornerRadius = CGFloat(cornerRadiusValue) * scaleFactor
        let smallRatio = smallCornerRadius / smallRectHeight

        let largeFont: CGFloat = 200
        let largeRectHeight = largeFont * CompositeLabelDrawer.LabelMetrics.rectHeightFactor
        let largeCornerRadius = CGFloat(cornerRadiusValue) * scaleFactor
        let largeRatio = largeCornerRadius / largeRectHeight

        #expect(smallRatio != largeRatio)
    }
}
