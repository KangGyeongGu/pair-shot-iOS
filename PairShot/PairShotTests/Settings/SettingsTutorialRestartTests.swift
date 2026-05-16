import Foundation
@testable import PairShot
import Testing

@MainActor
struct SettingsTutorialRestartTests {
    @Test
    func `튜토리얼 재시작 행 라벨 키 존재`() {
        let label = String(localized: "settings_item_tutorial_restart")
        #expect(!label.isEmpty)
        #expect(label != "settings_item_tutorial_restart")
    }

    @Test
    func `튜토리얼 재시작 confirm dialog 타이틀 키 존재`() {
        let title = String(localized: "settings_tutorial_restart_confirm_title")
        #expect(!title.isEmpty)
        #expect(title != "settings_tutorial_restart_confirm_title")
    }

    @Test
    func `튜토리얼 재시작 confirm dialog 메시지 키 존재`() {
        let message = String(localized: "settings_tutorial_restart_confirm_message")
        #expect(!message.isEmpty)
        #expect(message != "settings_tutorial_restart_confirm_message")
    }

    @Test
    func `튜토리얼 재시작 시 coordinator 가 첫 step 부터 다시 시작`() {
        let coord = TutorialCoordinator()
        coord.complete()
        coord.restart()
        #expect(coord.current == .homeCaptureHighlight)
        #expect(coord.isActive)
    }
}
