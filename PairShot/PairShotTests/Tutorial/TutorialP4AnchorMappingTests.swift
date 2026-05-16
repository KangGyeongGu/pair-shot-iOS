@testable import PairShot
import Testing

@MainActor
struct TutorialP4AnchorMappingTests {
    @Test
    func `P4 AnchorID 상수들은 고유 문자열`() {
        let ids = [
            TutorialAnchorID.homeSelectionToggle,
            TutorialAnchorID.homeSettings,
            TutorialAnchorID.selectionShare,
            TutorialAnchorID.selectionSave,
            TutorialAnchorID.selectionDelete,
            TutorialAnchorID.selectionExport,
        ]
        #expect(Set(ids).count == ids.count)
        for id in ids {
            #expect(!id.isEmpty)
        }
    }

    @Test
    func `P4 AnchorID 는 namespace 형식`() {
        #expect(TutorialAnchorID.homeSelectionToggle == "home.selectionToggle")
        #expect(TutorialAnchorID.homeSettings == "home.settings")
        #expect(TutorialAnchorID.selectionShare == "selection.share")
        #expect(TutorialAnchorID.selectionSave == "selection.save")
        #expect(TutorialAnchorID.selectionDelete == "selection.delete")
        #expect(TutorialAnchorID.selectionExport == "selection.export")
    }

    @Test
    func `P4 step copy 는 모두 비어있지 않음`() {
        let p4Steps: [TutorialStep] = [
            .enterSelectionMode,
            .selectionShare,
            .selectionSave,
            .selectionDelete,
            .selectionExport,
            .saveToDevice,
            .goSettings,
            .done,
        ]
        for step in p4Steps {
            #expect(!TutorialStepCopy.text(for: step).isEmpty)
        }
    }

    @Test
    func `시나리오 6~9 step 순서 확인 (enterSelectionMode → done)`() throws {
        let coord = TutorialCoordinator(current: .enterSelectionMode)
        let expected: [TutorialStep] = [
            .enterSelectionMode,
            .selectionShare,
            .selectionSave,
            .selectionDelete,
            .selectionExport,
            .saveToDevice,
            .goSettings,
            .done,
        ]
        var actual: [TutorialStep] = []
        try actual.append(#require(coord.current))
        for _ in 0 ..< (expected.count - 1) {
            coord.advance()
            try actual.append(#require(coord.current))
        }
        #expect(actual == expected)
    }
}
