import Foundation
@testable import PairShot
import Testing

struct SensorAlignmentTests {
    // MARK: - delta 계산 (happy path)

    @Test func delta_happyPath_pitchDeltaIsCurrentMinusTarget() {
        let a = SensorAlignment(
            currentPitch: 0.05, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.02, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(abs(a.deltaPitch - 0.03) < 1e-10)
    }

    @Test func delta_happyPath_rollDeltaIsCurrentMinusTarget() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.10, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.04, targetYaw: 0.0
        )
        #expect(abs(a.deltaRoll - 0.06) < 1e-10)
    }

    @Test func delta_happyPath_yawDeltaIsCurrentMinusTarget() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentYaw: 0.15,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.05
        )
        #expect(abs(a.deltaYaw - 0.10) < 1e-10)
    }

    @Test func delta_happyPath_allZeroWhenCurrentEqualsTarget() {
        let a = SensorAlignment(
            currentPitch: 0.1, currentRoll: 0.2, currentYaw: 0.3,
            targetPitch: 0.1, targetRoll: 0.2, targetYaw: 0.3
        )
        #expect(a.deltaPitch == 0.0)
        #expect(a.deltaRoll == 0.0)
        #expect(a.deltaYaw == 0.0)
    }

    // MARK: - delta 계산 (boundary)

    @Test func delta_boundary_negativeDeltaWhenCurrentLessThanTarget() {
        let a = SensorAlignment(
            currentPitch: -0.05, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.02, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.deltaPitch < 0.0)
        #expect(abs(a.deltaPitch - -0.07) < 1e-10)
    }

    @Test func delta_boundary_bothNegativeAngles() {
        let a = SensorAlignment(
            currentPitch: -0.05, currentRoll: -0.03, currentYaw: -0.10,
            targetPitch: -0.02, targetRoll: -0.01, targetYaw: -0.04
        )
        #expect(abs(a.deltaPitch - -0.03) < 1e-10)
        #expect(abs(a.deltaRoll - -0.02) < 1e-10)
        #expect(abs(a.deltaYaw - -0.06) < 1e-10)
    }

    // MARK: - delta 계산 (negative)

    @Test func delta_negative_pitchDeltaDoesNotAffectRollOrYaw() {
        let a = SensorAlignment(
            currentPitch: 0.5, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.deltaRoll == 0.0)
        #expect(a.deltaYaw == 0.0)
    }

    // MARK: - delta 계산 (error)

    @Test func delta_error_largeOppositeSignsDontCancelOut() {
        let a = SensorAlignment(
            currentPitch: 1.0, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: -1.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(abs(a.deltaPitch - 2.0) < 1e-10)
    }

    // MARK: - isAligned (happy path)

    @Test func isAligned_happyPath_trueWhenAllAxesWithinTolerance() {
        // pitch ±0.0349, roll ±0.0349, yaw ±0.0873
        let a = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.01, currentYaw: 0.03,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_happyPath_trueWhenPerfectlyAligned() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_happyPath_trueWithNonZeroTargetWithinTolerance() {
        let a = SensorAlignment(
            currentPitch: 0.10, currentRoll: 0.20, currentYaw: 0.30,
            targetPitch: 0.10, targetRoll: 0.20, targetYaw: 0.30
        )
        #expect(a.isAligned == true)
    }

    // MARK: - isAligned (boundary)

    @Test func isAligned_boundary_trueAtExactPitchTolerance() {
        let tolerance = SensorAlignment.pitchTolerance // 0.0349
        let a = SensorAlignment(
            currentPitch: tolerance, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_boundary_falseJustOutsidePitchTolerance() {
        let tolerance = SensorAlignment.pitchTolerance
        let a = SensorAlignment(
            currentPitch: tolerance + 1e-9, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == false)
    }

    @Test func isAligned_boundary_trueAtExactRollTolerance() {
        let tolerance = SensorAlignment.rollTolerance
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: tolerance, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_boundary_falseJustOutsideRollTolerance() {
        let tolerance = SensorAlignment.rollTolerance
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: tolerance + 1e-9, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == false)
    }

    @Test func isAligned_boundary_trueAtExactYawTolerance() {
        let tolerance = SensorAlignment.yawTolerance // 0.0873
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentYaw: tolerance,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_boundary_falseJustOutsideYawTolerance() {
        let tolerance = SensorAlignment.yawTolerance
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentYaw: tolerance + 1e-9,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == false)
    }

    @Test func isAligned_boundary_trueAtNegativePitchTolerance() {
        let tolerance = SensorAlignment.pitchTolerance
        let a = SensorAlignment(
            currentPitch: -tolerance, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == true)
    }

    @Test func isAligned_boundary_falseJustOutsideNegativePitchTolerance() {
        let tolerance = SensorAlignment.pitchTolerance
        let a = SensorAlignment(
            currentPitch: -(tolerance + 1e-9), currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == false)
    }

    // MARK: - isAligned (negative)

    @Test func isAligned_negative_falseWhenOnlyPitchOutOfRange() {
        let a = SensorAlignment(
            currentPitch: 0.10, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == false)
    }

    @Test func isAligned_negative_falseWhenOnlyRollOutOfRange() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.10, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == false)
    }

    @Test func isAligned_negative_falseWhenOnlyYawOutOfRange() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentYaw: 0.20,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == false)
    }

    // MARK: - isAligned (error)

    @Test func isAligned_error_requiresAllThreeAxesAligned() {
        // pitch/roll는 범위 내지만 yaw만 벗어난 경우 false
        let a = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.01, currentYaw: 0.20,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.isAligned == false)
    }

    // MARK: - alignmentScore (happy path)

    @Test func alignmentScore_happyPath_perfectAlignmentIsOne() {
        let a = SensorAlignment(
            currentPitch: 0.0, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.alignmentScore == 1.0)
    }

    @Test func alignmentScore_happyPath_scoreIsPositiveWhenNearTarget() {
        let a = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.01, currentYaw: 0.03,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.alignmentScore > 0.0)
        #expect(a.alignmentScore <= 1.0)
    }

    @Test func alignmentScore_happyPath_scoreDecreasesAsDeltaGrows() {
        let near = SensorAlignment(
            currentPitch: 0.01, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        let far = SensorAlignment(
            currentPitch: 0.03, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(near.alignmentScore > far.alignmentScore)
    }

    // MARK: - alignmentScore (boundary)

    @Test func alignmentScore_boundary_clampedToZeroWhenFarAway() {
        // delta가 tolerance를 크게 초과하면 score는 0.0으로 클램핑
        let a = SensorAlignment(
            currentPitch: 1.0, currentRoll: 1.0, currentYaw: 1.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(a.alignmentScore == 0.0)
    }

    @Test func alignmentScore_boundary_pitchAtToleranceProducesKnownValue() {
        // pitch만 tolerance 경계일 때: dp=1, dr=0, dy=0
        // weighted = 1*1 + 1*0 + 0.5*0 = 1.0
        // score = max(0, 1 - sqrt(1)) = 0.0
        let a = SensorAlignment(
            currentPitch: SensorAlignment.pitchTolerance, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(abs(a.alignmentScore - 0.0) < 1e-10)
    }

    @Test func alignmentScore_boundary_scoreIsNeverNegative() {
        let cases: [(Double, Double, Double)] = [
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0),
            (0.0, 0.0, 1.0),
            (1.0, 1.0, 1.0),
        ]
        for (p, r, y) in cases {
            let a = SensorAlignment(
                currentPitch: p, currentRoll: r, currentYaw: y,
                targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
            )
            #expect(a.alignmentScore >= 0.0)
        }
    }

    @Test func alignmentScore_boundary_scoreIsNeverAboveOne() {
        let cases: [(Double, Double, Double)] = [
            (0.0, 0.0, 0.0),
            (0.01, 0.0, 0.0),
            (0.0, 0.01, 0.0),
            (0.0, 0.0, 0.01),
        ]
        for (p, r, y) in cases {
            let a = SensorAlignment(
                currentPitch: p, currentRoll: r, currentYaw: y,
                targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
            )
            #expect(a.alignmentScore <= 1.0)
        }
    }

    // MARK: - alignmentScore (negative)

    @Test func alignmentScore_negative_symmetricDeltaGivesSameScore() {
        let pos = SensorAlignment(
            currentPitch: 0.02, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        let neg = SensorAlignment(
            currentPitch: -0.02, currentRoll: 0.0, currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        #expect(abs(pos.alignmentScore - neg.alignmentScore) < 1e-10)
    }

    @Test func alignmentScore_negative_yawWeightIsLowerThanPitch() {
        // yaw weight=0.5, pitch weight=1.0 이므로 같은 normalized delta일 때 yaw 이탈이 더 관대함
        let pitchDeviation = SensorAlignment(
            currentPitch: SensorAlignment.pitchTolerance * 0.5,
            currentRoll: 0.0,
            currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        let yawDeviation = SensorAlignment(
            currentPitch: 0.0,
            currentRoll: 0.0,
            currentYaw: SensorAlignment.yawTolerance * 0.5,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        // pitch deviation(weight=1)이 yaw deviation(weight=0.5)보다 score를 더 낮춤
        #expect(pitchDeviation.alignmentScore < yawDeviation.alignmentScore)
    }

    // MARK: - alignmentScore (error)

    @Test func alignmentScore_error_halfPitchTolerancePlusHalfRollToleranceGivesKnownScore() {
        // dp = 0.5, dr = 0.5, dy = 0
        // weighted = 1*0.25 + 1*0.25 + 0 = 0.5
        // score = max(0, 1 - sqrt(0.5)) ≈ 0.2929
        let a = SensorAlignment(
            currentPitch: SensorAlignment.pitchTolerance * 0.5,
            currentRoll: SensorAlignment.rollTolerance * 0.5,
            currentYaw: 0.0,
            targetPitch: 0.0, targetRoll: 0.0, targetYaw: 0.0
        )
        let expected = 1.0 - sqrt(0.5)
        #expect(abs(a.alignmentScore - expected) < 1e-10)
    }
}
