import Foundation
@testable import PairShot
import Testing

@MainActor
struct ExportSettingsViewModelStateTests {
    @Test
    func `presetSaveNameInput 12자 초과 시 자동 truncate`() {
        let viewModel = makeViewModel()
        viewModel.presetSaveNameInput = String(repeating: "가", count: 20)
        #expect(viewModel.presetSaveNameInput.count == 12)
    }

    @Test
    func `presetSaveNameInput 12자 이하는 그대로 유지`() {
        let viewModel = makeViewModel()
        viewModel.presetSaveNameInput = "짧은이름"
        #expect(viewModel.presetSaveNameInput == "짧은이름")
    }

    @Test
    func `presetRenameNameInput 12자 초과 시 자동 truncate`() {
        let viewModel = makeViewModel()
        viewModel.presetRenameNameInput = String(repeating: "B", count: 30)
        #expect(viewModel.presetRenameNameInput.count == 12)
    }

    @Test
    func `hasAnyInclude — 모두 false 면 false, 하나라도 true 면 true`() {
        let viewModel = makeViewModel()
        viewModel.preferences.includeCombined = false
        viewModel.preferences.includeBefore = false
        viewModel.preferences.includeAfter = false
        #expect(viewModel.hasAnyInclude == false)

        viewModel.preferences.includeAfter = true
        #expect(viewModel.hasAnyInclude == true)
    }

    @Test
    func `canExecute — 진행 중이면 false`() {
        let viewModel = makeViewModel()
        viewModel.preferences.includeAfter = true
        viewModel.isExporting = true
        #expect(viewModel.canExecute == false)
    }

    @Test
    func `canExecute — pairIds 비어있으면 false`() {
        let viewModel = makeViewModel(pairIds: [])
        viewModel.preferences.includeAfter = true
        #expect(viewModel.canExecute == false)
    }

    @Test
    func `canExecute — include 0건이면 false`() {
        let viewModel = makeViewModel()
        viewModel.preferences.includeCombined = false
        viewModel.preferences.includeBefore = false
        viewModel.preferences.includeAfter = false
        #expect(viewModel.canExecute == false)
    }

    @Test
    func `canExecute — 진행 안 함 + include 있음 + pairIds 있음 → true`() {
        let viewModel = makeViewModel()
        viewModel.preferences.includeAfter = true
        viewModel.isExporting = false
        #expect(viewModel.canExecute == true)
    }

    @Test
    func `makeSelection 은 현재 include 플래그 3종을 그대로 담는다`() {
        let viewModel = makeViewModel()
        viewModel.preferences.includeCombined = true
        viewModel.preferences.includeBefore = false
        viewModel.preferences.includeAfter = true

        let selection = viewModel.makeSelection()

        #expect(selection == ExportContents(
            includeCombined: true,
            includeBefore: false,
            includeAfter: true,
        ))
    }

    @Test
    func `makeRenderOptions — 무료 사용자면 isPro false`() {
        let viewModel = makeViewModel()
        viewModel.preferences.applyCombineSettings = true

        let options = viewModel.makeRenderOptions()

        #expect(options.applyCombineSettings == true)
        #expect(options.isPro == false)
    }

    @Test
    func `selectFormat — 무료 사용자가 individualImages 로 전환 시 그대로 적용 + paywall 미발생`() {
        let viewModel = makeViewModel(format: .zip)
        viewModel.appSettings.watermarkEnabled = false

        viewModel.selectFormat(.individualImages)

        #expect(viewModel.format == .individualImages)
        #expect(viewModel.showPaywall == false)
    }

    @Test
    func `cleanupPendingZip 은 pendingZipURL 을 nil 로 되돌리고 파일도 제거한다`() throws {
        let viewModel = makeViewModel()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cleanup-\(UUID().uuidString).zip")
        try Data("payload".utf8).write(to: tempURL)
        viewModel.pendingZipURL = tempURL

        viewModel.cleanupPendingZip()

        #expect(viewModel.pendingZipURL == nil)
        #expect(FileManager.default.fileExists(atPath: tempURL.path) == false)
    }

    @Test
    func `cleanupPendingZip — pendingZipURL nil 이면 no-op`() {
        let viewModel = makeViewModel()
        viewModel.pendingZipURL = nil
        viewModel.cleanupPendingZip()
        #expect(viewModel.pendingZipURL == nil)
    }

    @Test
    func `clearShareItems 은 shareItems 를 nil 로 + completed·dismiss 이벤트 yield`() async {
        let viewModel = makeViewModel()
        viewModel.shareItems = ExportShareItems(values: ["x"])

        var events: [ExportSettingsViewModel.Event] = []
        let collector = Task { @MainActor in
            for await event in viewModel.events {
                events.append(event)
                if events.count == 2 { break }
            }
        }

        viewModel.clearShareItems()
        await collector.value

        #expect(viewModel.shareItems == nil)
        #expect(events.contains(.completed))
        #expect(events.contains(.dismiss))
    }

    @Test
    func `handleZipExportCompleted true — 진행 완료 알림 + completed·dismiss 이벤트`() async {
        let viewModel = makeViewModel()
        viewModel.zipExportItem = DocumentExporterItem(
            url: FileManager.default.temporaryDirectory.appendingPathComponent("dummy.zip"),
        )
        let handle = viewModel.snackbarQueue.enqueueProgress(
            .prepareZipExport,
            token: "tok-\(UUID().uuidString)",
            initialValue: 0,
        )
        viewModel.zipSaveProgress = handle

        var events: [ExportSettingsViewModel.Event] = []
        let collector = Task { @MainActor in
            for await event in viewModel.events {
                events.append(event)
                if events.count == 2 { break }
            }
        }

        viewModel.handleZipExportCompleted(true)
        await collector.value

        #expect(viewModel.zipExportItem == nil)
        #expect(viewModel.zipSaveProgress == nil)
        #expect(events.contains(.completed))
        #expect(events.contains(.dismiss))
    }

    @Test
    func `handleZipExportCompleted false — 진행 취소 + 이벤트 yield 없음`() {
        let viewModel = makeViewModel()
        viewModel.zipExportItem = DocumentExporterItem(
            url: FileManager.default.temporaryDirectory.appendingPathComponent("dummy.zip"),
        )
        let handle = viewModel.snackbarQueue.enqueueProgress(
            .prepareZipExport,
            token: "tok-\(UUID().uuidString)",
            initialValue: 0,
        )
        viewModel.zipSaveProgress = handle

        viewModel.handleZipExportCompleted(false)

        #expect(viewModel.zipExportItem == nil)
        #expect(viewModel.zipSaveProgress == nil)
    }

    @Test
    func `cancelPendingExport — 진행 핸들 있으면 snackbar 취소`() {
        let viewModel = makeViewModel()
        let handle = viewModel.snackbarQueue.enqueueProgress(
            .share,
            token: "tok-\(UUID().uuidString)",
            initialValue: 0,
        )
        viewModel.zipSaveProgress = handle

        viewModel.cancelPendingExport()

        #expect(viewModel.zipSaveProgress == nil)
    }

    @Test
    func `canAccessSlot — 인덱스 0,1 은 무료 접근 가능`() {
        let viewModel = makeViewModel()
        #expect(viewModel.canAccessSlot(index: 0) == true)
        #expect(viewModel.canAccessSlot(index: 1) == true)
    }

    @Test
    func `canAccessSlot — 인덱스 2,3 은 무료에서 Pro 잠금`() {
        let viewModel = makeViewModel()
        #expect(viewModel.canAccessSlot(index: 2) == false)
        #expect(viewModel.canAccessSlot(index: 3) == false)
    }

    @Test
    func `defaultPresetName — 인덱스 + 1 이 이름에 포함된다`() {
        let viewModel = makeViewModel()
        #expect(viewModel.defaultPresetName(forSlot: 0).contains("1"))
        #expect(viewModel.defaultPresetName(forSlot: 2).contains("3"))
    }

    @Test
    func `cancelPresetSave — pending 상태와 입력값 초기화`() {
        let viewModel = makeViewModel()
        viewModel.pendingPresetSaveSlotIndex = 2
        viewModel.presetSaveNameInput = "draft"

        viewModel.cancelPresetSave()

        #expect(viewModel.pendingPresetSaveSlotIndex == nil)
        #expect(viewModel.presetSaveNameInput.isEmpty)
    }

    @Test
    func `cancelPresetRename — pending 상태와 입력값 초기화`() {
        let viewModel = makeViewModel()
        viewModel.pendingPresetRenameSlotIndex = 1
        viewModel.presetRenameNameInput = "draft"

        viewModel.cancelPresetRename()

        #expect(viewModel.pendingPresetRenameSlotIndex == nil)
        #expect(viewModel.presetRenameNameInput.isEmpty)
    }

    @Test
    func `beginPresetDelete — index 저장 + action sheet 닫기`() {
        let viewModel = makeViewModel()
        viewModel.pendingPresetActionSheetSlotIndex = 1

        viewModel.beginPresetDelete(at: 1)

        #expect(viewModel.pendingPresetDeleteSlotIndex == 1)
        #expect(viewModel.pendingPresetActionSheetSlotIndex == nil)
    }

    @Test
    func `cancelPresetDelete — pending 인덱스 초기화`() {
        let viewModel = makeViewModel()
        viewModel.pendingPresetDeleteSlotIndex = 2

        viewModel.cancelPresetDelete()

        #expect(viewModel.pendingPresetDeleteSlotIndex == nil)
    }

    private func makeViewModel(
        format: ExportFormat = .individualImages,
        pairIds: [UUID] = [UUID()],
    ) -> ExportSettingsViewModel {
        ExportSettingsViewModelTestSupport.makeViewModel(
            format: format,
            pairIds: pairIds,
        )
    }
}
