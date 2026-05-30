import Foundation
@testable import PairShot
import Testing

@MainActor
struct ExportSettingsViewModelPresetActionsTests {
    @Test
    func `handleSlotTap — exportPresetStore 미주입 시 paywall 발생 안 함`() {
        let viewModel = makeViewModel()
        #expect(viewModel.exportPresetStore == nil)

        viewModel.handleSlotTap(at: 3)

        #expect(viewModel.showPaywall == false)
    }

    @Test
    func `handleSlotTap — 빈 슬롯이면 save sheet pending + 이름 입력 초기화`() {
        let viewModel = makeViewModel(withPresetStore: true)

        viewModel.handleSlotTap(at: 0)

        #expect(viewModel.pendingPresetSaveSlotIndex == 0)
        #expect(viewModel.presetSaveNameInput.isEmpty)
    }

    @Test
    func `handleSlotTap — 무료 사용자가 잠금 슬롯 탭 시 paywall`() {
        let viewModel = makeViewModel(withPresetStore: true)

        viewModel.handleSlotTap(at: 2)

        #expect(viewModel.showPaywall == true)
        #expect(viewModel.pendingPresetSaveSlotIndex == nil)
    }

    @Test
    func `handleSlotTap — 활성 슬롯 재탭은 no-op`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.exportPresetStore?.seedDefaultIfNeeded(name: "기본")
        #expect(viewModel.exportPresetStore?.activeIndex == 0)

        viewModel.handleSlotTap(at: 0)

        #expect(viewModel.exportPresetStore?.activeIndex == 0)
        #expect(viewModel.pendingPresetSaveSlotIndex == nil)
    }

    @Test
    func `handleSlotTap — 비활성 채워진 슬롯 탭 시 활성 전환`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.exportPresetStore?.seedDefaultIfNeeded(name: "기본")
        viewModel.exportPresetStore?.save(at: 1, name: "다른")
        #expect(viewModel.exportPresetStore?.activeIndex == 0)

        viewModel.handleSlotTap(at: 1)

        #expect(viewModel.exportPresetStore?.activeIndex == 1)
    }

    @Test
    func `handleSlotLongPress — 빈 슬롯이면 action sheet 안 뜸`() {
        let viewModel = makeViewModel(withPresetStore: true)

        viewModel.handleSlotLongPress(at: 1)

        #expect(viewModel.pendingPresetActionSheetSlotIndex == nil)
    }

    @Test
    func `handleSlotLongPress — 채워진 슬롯이면 action sheet 인덱스 설정`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.exportPresetStore?.seedDefaultIfNeeded(name: "기본")

        viewModel.handleSlotLongPress(at: 0)

        #expect(viewModel.pendingPresetActionSheetSlotIndex == 0)
    }

    @Test
    func `handleSlotLongPress — 무료 잠금 슬롯이면 action sheet 안 뜸`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.exportPresetStore?.seedDefaultIfNeeded(name: "기본")
        viewModel.exportPresetStore?.save(at: 2, name: "Pro")

        viewModel.handleSlotLongPress(at: 2)

        #expect(viewModel.pendingPresetActionSheetSlotIndex == nil)
    }

    @Test
    func `confirmPresetSave — 빈 이름이면 기본 이름 (인덱스+1) 사용`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.pendingPresetSaveSlotIndex = 1
        viewModel.presetSaveNameInput = "   "

        viewModel.confirmPresetSave()

        let saved = viewModel.exportPresetStore?.presets[1]?.name ?? ""
        #expect(saved.contains("2"))
        #expect(viewModel.exportPresetStore?.activeIndex == 1)
        #expect(viewModel.pendingPresetSaveSlotIndex == nil)
    }

    @Test
    func `confirmPresetSave — 양쪽 공백 trim 후 저장`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.pendingPresetSaveSlotIndex = 0
        viewModel.presetSaveNameInput = "  공유용프리셋  "

        viewModel.confirmPresetSave()

        #expect(viewModel.exportPresetStore?.presets[0]?.name == "공유용프리셋")
    }

    @Test
    func `confirmPresetSave — pending 인덱스 없으면 no-op`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.pendingPresetSaveSlotIndex = nil
        viewModel.presetSaveNameInput = "이름"

        viewModel.confirmPresetSave()

        #expect(viewModel.exportPresetStore?.presets[0] == nil)
    }

    @Test
    func `beginPresetRename — 현재 프리셋 이름 preload + action sheet 닫기`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.exportPresetStore?.seedDefaultIfNeeded(name: "기본")
        viewModel.pendingPresetActionSheetSlotIndex = 0

        viewModel.beginPresetRename(at: 0)

        #expect(viewModel.pendingPresetRenameSlotIndex == 0)
        #expect(viewModel.presetRenameNameInput == "기본")
        #expect(viewModel.pendingPresetActionSheetSlotIndex == nil)
    }

    @Test
    func `beginPresetRename — 빈 슬롯이면 no-op`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.pendingPresetActionSheetSlotIndex = 1

        viewModel.beginPresetRename(at: 1)

        #expect(viewModel.pendingPresetRenameSlotIndex == nil)
        #expect(viewModel.pendingPresetActionSheetSlotIndex == 1)
    }

    @Test
    func `confirmPresetRename — 공백만 입력이면 cancel 과 동등`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.exportPresetStore?.seedDefaultIfNeeded(name: "기본")
        viewModel.pendingPresetRenameSlotIndex = 0
        viewModel.presetRenameNameInput = "   "

        viewModel.confirmPresetRename()

        #expect(viewModel.exportPresetStore?.presets[0]?.name == "기본")
        #expect(viewModel.pendingPresetRenameSlotIndex == nil)
        #expect(viewModel.presetRenameNameInput.isEmpty)
    }

    @Test
    func `confirmPresetRename — 정상 이름 적용 + 12자 clip`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.exportPresetStore?.seedDefaultIfNeeded(name: "기본")
        viewModel.pendingPresetRenameSlotIndex = 0
        viewModel.presetRenameNameInput = "새이름인데너무길어서잘려야함"

        viewModel.confirmPresetRename()

        let renamed = viewModel.exportPresetStore?.presets[0]?.name ?? ""
        #expect(renamed.count == 12)
        #expect(renamed.hasPrefix("새이름"))
        #expect(viewModel.pendingPresetRenameSlotIndex == nil)
    }

    @Test
    func `confirmPresetDelete — store.delete 호출 + pending 초기화`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.exportPresetStore?.seedDefaultIfNeeded(name: "기본")
        viewModel.exportPresetStore?.save(at: 1, name: "B")
        viewModel.pendingPresetDeleteSlotIndex = 1

        viewModel.confirmPresetDelete()

        #expect(viewModel.exportPresetStore?.presets[1] == nil)
        #expect(viewModel.pendingPresetDeleteSlotIndex == nil)
    }

    @Test
    func `confirmPresetDelete — pending 인덱스 없으면 no-op`() {
        let viewModel = makeViewModel(withPresetStore: true)
        viewModel.exportPresetStore?.seedDefaultIfNeeded(name: "기본")
        viewModel.pendingPresetDeleteSlotIndex = nil

        viewModel.confirmPresetDelete()

        #expect(viewModel.exportPresetStore?.presets[0] != nil)
    }

    private func makeViewModel(
        withPresetStore: Bool = false,
    ) -> ExportSettingsViewModel {
        ExportSettingsViewModelTestSupport.makeViewModel(
            withPresetStore: withPresetStore,
        )
    }
}
