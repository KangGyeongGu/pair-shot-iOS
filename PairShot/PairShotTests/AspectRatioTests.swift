import Testing
import CoreFoundation
import CoreGraphics
@testable import PairShot

@MainActor
struct AspectRatioTests {

    // MARK: - cropRect happy path

    @Test func cropRect_4_3_isFullRect() {
        let rect = AspectRatio.ratio4_3.cropRect
        #expect(rect.origin.x == 0.0)
        #expect(rect.origin.y == 0.0)
        #expect(rect.width == 1.0)
        #expect(rect.height == 1.0)
    }

    @Test func cropRect_16_9_yOffsetIs0_125() {
        // (1 - 3/4) / 2 = 0.125
        let rect = AspectRatio.ratio16_9.cropRect
        #expect(rect.origin.y == 0.125)
    }

    @Test func cropRect_16_9_heightIs0_75() {
        let rect = AspectRatio.ratio16_9.cropRect
        #expect(rect.height == 0.75)
    }

    @Test func cropRect_1_1_xOffsetIs0_125() {
        // (1 - 3/4) / 2 = 0.125
        let rect = AspectRatio.ratio1_1.cropRect
        #expect(rect.origin.x == 0.125)
    }

    // MARK: - cropRect boundary

    @Test func cropRect_16_9_xIsZeroAndWidthIsOne() {
        let rect = AspectRatio.ratio16_9.cropRect
        #expect(rect.origin.x == 0.0)
        #expect(rect.width == 1.0)
    }

    @Test func cropRect_1_1_yIsZeroAndHeightIsOne() {
        let rect = AspectRatio.ratio1_1.cropRect
        #expect(rect.origin.y == 0.0)
        #expect(rect.height == 1.0)
    }

    @Test func cropRect_1_1_widthIs0_75() {
        let rect = AspectRatio.ratio1_1.cropRect
        #expect(rect.width == 0.75)
    }

    // MARK: - cropRect negative (수학적 보존 검증)

    @Test func cropRect_16_9_topPlusHeightEqualsOne() {
        let rect = AspectRatio.ratio16_9.cropRect
        // yOffset + height == 1 이어야 센서 경계 밖으로 나가지 않는다
        #expect(rect.origin.y + rect.height <= 1.0)
        #expect(rect.origin.y >= 0.0)
    }

    @Test func cropRect_1_1_leftPlusWidthEqualsOne() {
        let rect = AspectRatio.ratio1_1.cropRect
        #expect(rect.origin.x + rect.width <= 1.0)
        #expect(rect.origin.x >= 0.0)
    }

    // MARK: - displayName happy path

    @Test func displayName_4_3_returns4Colon3() {
        #expect(AspectRatio.ratio4_3.displayName == "4:3")
    }

    @Test func displayName_16_9_returns16Colon9() {
        #expect(AspectRatio.ratio16_9.displayName == "16:9")
    }

    @Test func displayName_1_1_returns1Colon1() {
        #expect(AspectRatio.ratio1_1.displayName == "1:1")
    }

    // MARK: - displayName boundary

    @Test func displayName_allCases_areNonEmpty() {
        for ratio in AspectRatio.allCases {
            #expect(ratio.displayName.isEmpty == false)
        }
    }

    // MARK: - displayName negative

    @Test func displayName_allCasesAreDistinct() {
        let names = AspectRatio.allCases.map { $0.displayName }
        let unique = Set(names)
        #expect(unique.count == AspectRatio.allCases.count)
    }
}
