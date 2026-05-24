@testable import PairShot
import Testing

struct TutorialMotionGuideTests {
    @Test
    func `roll 0도는 portrait`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: 0) == .portrait)
    }

    @Test
    func `roll 24도는 portrait (경계 안쪽)`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: 24) == .portrait)
    }

    @Test
    func `roll 음수 24도는 portrait (경계 안쪽)`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: -24) == .portrait)
    }

    @Test
    func `roll 25도는 portrait 가 아니다 (경계 바깥)`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: 25) != .portrait)
    }

    @Test
    func `roll 음수 90도는 leftLandscape`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: -90) == .leftLandscape)
    }

    @Test
    func `roll 음수 60도는 leftLandscape (경계 안쪽)`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: -60) == .leftLandscape)
    }

    @Test
    func `roll 음수 120도는 leftLandscape (경계 안쪽)`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: -120) == .leftLandscape)
    }

    @Test
    func `roll 음수 54도는 leftLandscape 가 아니다 (경계 바깥)`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: -54) != .leftLandscape)
    }

    @Test
    func `roll 양수 90도는 rightLandscape`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: 90) == .rightLandscape)
    }

    @Test
    func `roll 양수 60도는 rightLandscape`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: 60) == .rightLandscape)
    }

    @Test
    func `roll 양수 120도는 rightLandscape`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: 120) == .rightLandscape)
    }

    @Test
    func `roll 50도는 unknown (분류 영역 사이)`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: 50) == .unknown)
    }

    @Test
    func `roll 180도는 unknown`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: 180) == .unknown)
    }

    @Test
    func `nan roll 은 unknown`() {
        #expect(TutorialMotionGuide.posture(forRollDegrees: .nan) == .unknown)
    }

    @Test
    func `matches portrait step + portrait posture`() {
        #expect(TutorialMotionGuide.matches(step: .captureGuidePortrait, posture: .portrait))
    }

    @Test
    func `matches portrait step + left posture false`() {
        #expect(!TutorialMotionGuide.matches(step: .captureGuidePortrait, posture: .leftLandscape))
    }

    @Test
    func `matches left step + left posture`() {
        #expect(TutorialMotionGuide.matches(step: .captureGuideLeft, posture: .leftLandscape))
    }

    @Test
    func `matches right step + right posture`() {
        #expect(TutorialMotionGuide.matches(step: .captureGuideRight, posture: .rightLandscape))
    }

    @Test
    func `matches 다른 step 들은 항상 false`() {
        for step in TutorialStep.allCases {
            switch step {
                case .captureGuidePortrait, .captureGuideLeft, .captureGuideRight: continue

                default:
                    for posture in [TutorialPosture.portrait, .leftLandscape, .rightLandscape, .unknown] {
                        #expect(!TutorialMotionGuide.matches(step: step, posture: posture))
                    }
            }
        }
    }

    @Test
    func `postureRequiringStep 은 capture 3 step 에서만 true`() {
        #expect(TutorialMotionGuide.postureRequiringStep(.captureGuidePortrait))
        #expect(TutorialMotionGuide.postureRequiringStep(.captureGuideLeft))
        #expect(TutorialMotionGuide.postureRequiringStep(.captureGuideRight))
    }

    @Test
    func `postureRequiringStep 은 다른 step 에서 false`() {
        for step in TutorialStep.allCases {
            switch step {
                case .captureGuidePortrait, .captureGuideLeft, .captureGuideRight: continue

                default:
                    #expect(!TutorialMotionGuide.postureRequiringStep(step))
            }
        }
    }
}
