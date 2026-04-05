import Foundation
@testable import PairShot
import Testing

struct SensorAlignmentTests {
    // MARK: - delta 계산 (happy path)

    @Test func delta_happyPath_pitchDeltaIsCurrentMinusTarget() {
        let a = SensorAlignment(
            currentPitch: 0.05, currentRoll: 0.0, currentHeading: 0.0,
            targetPitch: 0.02, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(abs(a.deltaPitch - 0.03) < 1e-10)
    }

    @Test func delta_happyPath_rollDeltaIsCurrentMinusTarget() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.10, currentHeading: 0.0,
            targetPitch: 0.0, targetRoll: 0.04, targetHeading: 0.0
        )
        #expect(abs(a.deltaRoll - 0.06) < 1e-10)
    }

    @Test func delta_happyPath_headingDeltaIsCurrentMinusTarget() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentHeading: 96.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(abs(a.deltaHeading - 6.0) < 1e-10)
    }

    @Test func delta_happyPath_allZeroWhenCurrentEqualsTarget() {
        let a = SensorAlignment(
            currentPitch: 0.1, currentRoll: 0.2, currentHeading: 90.0,
            targetPitch: 0.1, targetRoll: 0.2, targetHeading: 90.0
        )
        #expect(a.deltaPitch == 0.0)
        #expect(a.deltaRoll == 0.0)
        #expect(a.deltaHeading == 0.0)
    }

    // MARK: - delta 계산 (boundary)

    @Test func delta_boundary_negativeDeltaWhenCurrentLessThanTarget() {
        let a = SensorAlignment(
            currentPitch: -0.05, currentRoll: 0.0, currentHeading: 0.0,
            targetPitch: 0.02, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.deltaPitch < 0.0)
        #expect(abs(a.deltaPitch - -0.07) < 1e-10)
    }

    @Test func delta_boundary_bothNegativeAngles() {
        let a = SensorAlignment(
            currentPitch: -0.05, currentRoll: -0.03, currentHeading: 84.0,
            targetPitch: -0.02, targetRoll: -0.01, targetHeading: 90.0
        )
        #expect(abs(a.deltaPitch - -0.03) < 1e-10)
        #expect(abs(a.deltaRoll - -0.02) < 1e-10)
        #expect(abs(a.deltaHeading - -6.0) < 1e-10)
    }

    // MARK: - delta 계산 (negative)

    @Test func delta_negative_pitchDeltaDoesNotAffectRollOrHeading() {
        let a = SensorAlignment(
            currentPitch: 0.5, currentRoll: 0.0, currentHeading: 90.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.deltaRoll == 0.0)
        #expect(a.deltaHeading == 0.0)
    }

    // MARK: - delta 계산 (error)

    @Test func delta_error_largeOppositeSignsDontCancelOut() {
        let a = SensorAlignment(
            currentPitch: 1.0, currentRoll: 0.0, currentHeading: 0.0,
            targetPitch: -1.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(abs(a.deltaPitch - 2.0) < 1e-10)
    }

    // MARK: - isAligned (happy path)

    @Test func isAligned_happyPath_trueWhenAllAxesWithinTolerance() {
        // pitch ±0.0349 rad, roll ±0.0349 rad, heading ±5°
        let a = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.01, currentHeading: 92.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_happyPath_trueWhenPerfectlyAligned() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentHeading: 90.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_happyPath_trueWithNonZeroTargetWithinTolerance() {
        let a = SensorAlignment(
            currentPitch: 0.10, currentRoll: 0.20, currentHeading: 45.0,
            targetPitch: 0.10, targetRoll: 0.20, targetHeading: 45.0
        )
        #expect(a.isAligned == true)
    }

    // MARK: - isAligned (boundary)

    @Test func isAligned_boundary_trueAtExactPitchTolerance() {
        let tolerance = SensorAlignment.pitchTolerance // 0.0349
        let a = SensorAlignment(
            currentPitch: tolerance, currentRoll: 0.0, currentHeading: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_boundary_falseJustOutsidePitchTolerance() {
        let tolerance = SensorAlignment.pitchTolerance
        let a = SensorAlignment(
            currentPitch: tolerance + 1e-9, currentRoll: 0.0, currentHeading: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.isAligned == false)
    }

    @Test func isAligned_boundary_trueAtExactRollTolerance() {
        let tolerance = SensorAlignment.rollTolerance
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: tolerance, currentHeading: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_boundary_falseJustOutsideRollTolerance() {
        let tolerance = SensorAlignment.rollTolerance
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: tolerance + 1e-9, currentHeading: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.isAligned == false)
    }

    @Test func isAligned_boundary_trueAtExactHeadingTolerance() {
        let tolerance = SensorAlignment.headingTolerance // 5.0°
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentHeading: tolerance,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_boundary_falseJustOutsideHeadingTolerance() {
        let tolerance = SensorAlignment.headingTolerance
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentHeading: tolerance + 1e-9,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.isAligned == false)
    }

    @Test func isAligned_boundary_trueAtNegativePitchTolerance() {
        let tolerance = SensorAlignment.pitchTolerance
        let a = SensorAlignment(
            currentPitch: -tolerance, currentRoll: 0.0, currentHeading: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_boundary_falseJustOutsideNegativePitchTolerance() {
        let tolerance = SensorAlignment.pitchTolerance
        let a = SensorAlignment(
            currentPitch: -(tolerance + 1e-9), currentRoll: 0.0, currentHeading: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.isAligned == false)
    }

    // MARK: - isAligned (negative)

    @Test func isAligned_negative_falseWhenOnlyPitchOutOfRange() {
        let a = SensorAlignment(
            currentPitch: 0.10, currentRoll: 0.0, currentHeading: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.isAligned == false)
    }

    @Test func isAligned_negative_falseWhenOnlyRollOutOfRange() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.10, currentHeading: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(a.isAligned == false)
    }

    @Test func isAligned_negative_falseWhenOnlyHeadingOutOfRange() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentHeading: 102.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.isAligned == false)
    }

    // MARK: - isAligned (error)

    @Test func isAligned_error_requiresAllThreeAxesAligned() {
        // pitch/roll는 범위 내지만 heading만 벗어난 경우 false
        let a = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.01, currentHeading: 102.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.isAligned == false)
    }

    // MARK: - alignmentScore (happy path)

    @Test func alignmentScore_happyPath_perfectAlignmentIsOne() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentHeading: 90.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.alignmentScore == 1.0)
    }

    @Test func alignmentScore_happyPath_scoreIsPositiveWhenNearTarget() {
        let a = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.01, currentHeading: 92.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.alignmentScore > 0.0)
        #expect(a.alignmentScore <= 1.0)
    }

    @Test func alignmentScore_happyPath_scoreDecreasesAsDeltaGrows() {
        let near = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.0, currentHeading: 90.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        let far = SensorAlignment(
            currentPitch: 0.03, currentRoll: 0.0, currentHeading: 90.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(near.alignmentScore > far.alignmentScore)
    }

    // MARK: - alignmentScore (boundary)

    @Test func alignmentScore_boundary_clampedToZeroWhenFarAway() {
        // delta가 tolerance를 크게 초과하면 score는 0.0으로 클램핑
        let a = SensorAlignment(
            currentPitch: 1.0, currentRoll: 1.0, currentHeading: 150.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.alignmentScore == 0.0)
    }

    @Test func alignmentScore_boundary_pitchAtToleranceProducesKnownValue() {
        // pitch만 tolerance 경계일 때: dp=1, dr=0, dh=0
        // weighted = 1*1 + 1*0 + 0.5*0 = 1.0
        // score = max(0, 1 - sqrt(1)) = 0.0
        let a = SensorAlignment(
            currentPitch: SensorAlignment.pitchTolerance, currentRoll: 0.0, currentHeading: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 0.0
        )
        #expect(abs(a.alignmentScore - 0.0) < 1e-10)
    }

    @Test func alignmentScore_boundary_scoreIsNeverNegative() {
        let pitchRollCases: [(Double, Double)] = [
            (1.0, 0.0),
            (0.0, 1.0),
            (1.0, 1.0),
        ]
        for (p, r) in pitchRollCases {
            let a = SensorAlignment(
                currentPitch: p, currentRoll: r, currentHeading: 150.0,
                targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
            )
            #expect(a.alignmentScore >= 0.0)
        }
        let zeroCase = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentHeading: 150.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(zeroCase.alignmentScore >= 0.0)
    }

    @Test func alignmentScore_boundary_scoreIsNeverAboveOne() {
        let cases: [(Double, Double, Double, Double)] = [
            (0.0, 0.0, 90.0, 90.0),
            (0.01, 0.0, 90.0, 90.0),
            (0.0, 0.01, 90.0, 90.0),
            (0.0, 0.0, 91.0, 90.0),
        ]
        for (p, r, h, th) in cases {
            let a = SensorAlignment(
                currentPitch: p, currentRoll: r, currentHeading: h,
                targetPitch: 0.0, targetRoll: 0.0, targetHeading: th
            )
            #expect(a.alignmentScore <= 1.0)
        }
    }

    // MARK: - alignmentScore (negative)

    @Test func alignmentScore_negative_symmetricDeltaGivesSameScore() {
        let pos = SensorAlignment(
            currentPitch: 0.02, currentRoll: 0.0, currentHeading: 90.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        let neg = SensorAlignment(
            currentPitch: -0.02, currentRoll: 0.0, currentHeading: 90.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(abs(pos.alignmentScore - neg.alignmentScore) < 1e-10)
    }

    @Test func alignmentScore_negative_headingWeightIsLowerThanPitch() {
        // heading weight=0.5, pitch weight=1.0 이므로 같은 normalized delta일 때 heading 이탈이 더 관대함
        let pitchDeviation = SensorAlignment(
            currentPitch: SensorAlignment.pitchTolerance * 0.5,
            currentRoll: 0.0,
            currentHeading: 90.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        let headingDeviation = SensorAlignment(
            currentPitch: 0.0,
            currentRoll: 0.0,
            currentHeading: 90.0 + SensorAlignment.headingTolerance * 0.5,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        // pitch deviation(weight=1)이 heading deviation(weight=0.5)보다 score를 더 낮춤
        #expect(pitchDeviation.alignmentScore < headingDeviation.alignmentScore)
    }

    // MARK: - alignmentScore (error)

    @Test func alignmentScore_error_halfPitchTolerancePlusHalfRollToleranceGivesKnownScore() {
        // dp = 0.5, dr = 0.5, dh = 0
        // weighted = 1*0.25 + 1*0.25 + 0 = 0.5
        // score = max(0, 1 - sqrt(0.5)) ≈ 0.2929
        let a = SensorAlignment(
            currentPitch: SensorAlignment.pitchTolerance * 0.5,
            currentRoll: SensorAlignment.rollTolerance * 0.5,
            currentHeading: 90.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        let expected = 1.0 - sqrt(0.5)
        #expect(abs(a.alignmentScore - expected) < 1e-10)
    }

    // GuidanceStage tests

    @Test func stage_locating_whenAllAxesFarFromTarget() {
        // pitch/roll 0.5 rad (>10°), heading delta 30° (>10°)
        let a = SensorAlignment(
            currentPitch: 0.5, currentRoll: 0.5, currentHeading: 120.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.stage == .locating)
    }

    @Test func stage_positioning_whenAllWithin10Degrees() {
        // pitch/roll 0.10 rad (~5.7°, <10°), heading delta 8° (<10°)
        let a = SensorAlignment(
            currentPitch: 0.10, currentRoll: 0.10, currentHeading: 98.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.stage == .positioning)
    }

    @Test func stage_positioning_boundaryAtExact10Degrees() {
        let thresholdRad = SensorAlignment.positioningThresholdRad // 0.1745
        let thresholdDeg = SensorAlignment.positioningThresholdDeg // 10.0
        let a = SensorAlignment(
            currentPitch: thresholdRad, currentRoll: thresholdRad, currentHeading: 90.0 + thresholdDeg,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.stage == .positioning)
    }

    @Test func stage_locating_justOutside10Degrees() {
        let threshold = SensorAlignment.positioningThresholdRad
        let a = SensorAlignment(
            currentPitch: threshold + 0.001, currentRoll: 0.0, currentHeading: 90.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.stage == .locating)
    }

    @Test func stage_aligning_whenPitchRollWithin2DegAndHeadingWithin5Deg() {
        // pitch/roll 0.01 rad (~0.57°, <2°), heading delta 2° (<5°)
        let a = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.01, currentHeading: 92.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.stage == .aligning)
    }

    @Test func stage_aligning_boundaryAtExactThresholds() {
        let a = SensorAlignment(
            currentPitch: 0.0349, currentRoll: 0.0349, currentHeading: 90.0 + SensorAlignment.headingTolerance,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.stage == .aligning)
    }

    @Test func stage_positioning_whenPitchRollWithin2ButHeadingOutside5() {
        // heading delta 6° (>5°) → positioning
        let a = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.01, currentHeading: 96.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.stage == .positioning)
    }

    @Test func stage_isPositioning_trueForPositioningStage() {
        let a = SensorAlignment(
            currentPitch: 0.10, currentRoll: 0.10, currentHeading: 98.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.isPositioning == true)
    }

    @Test func stage_isPositioning_trueForAligningStage() {
        let a = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.01, currentHeading: 92.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.isPositioning == true)
    }

    @Test func stage_isPositioning_falseForLocatingStage() {
        let a = SensorAlignment(
            currentPitch: 0.5, currentRoll: 0.5, currentHeading: 120.0,
            targetPitch: 0.0, targetRoll: 0.0, targetHeading: 90.0
        )
        #expect(a.isPositioning == false)
    }
}
