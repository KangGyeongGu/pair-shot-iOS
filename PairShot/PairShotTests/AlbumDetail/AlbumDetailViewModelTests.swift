import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct AlbumDetailViewModelTests {
    @Test
    func `enterSelectionMode — isSelectionMode true 로 전환, 이미 true 면 no-op (selection 보존)`() {
        let viewModel = makeViewModel()
        let preselected = UUID()
        viewModel.selectedPairIds = [preselected]

        viewModel.enterSelectionMode()
        #expect(viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds == [preselected])

        viewModel.enterSelectionMode()
        #expect(viewModel.selectedPairIds == [preselected])
    }

    @Test
    func `cancelSelection — 모드 OFF + selection 비움`() {
        let viewModel = makeViewModel()
        viewModel.isSelectionMode = true
        viewModel.selectedPairIds = [UUID(), UUID()]

        viewModel.cancelSelection()

        #expect(!viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds.isEmpty)
    }

    @Test
    func `togglePairSelection — 미선택 → 선택 → 미선택 토글`() {
        let viewModel = makeViewModel()
        let id = UUID()

        viewModel.togglePairSelection(id)
        #expect(viewModel.selectedPairIds == [id])

        viewModel.togglePairSelection(id)
        #expect(viewModel.selectedPairIds.isEmpty)
    }

    @Test
    func `selectAllPairs — 전체 선택 ↔ 비선택 토글`() {
        let viewModel = makeViewModel()
        let pairs = [PhotoPair(), PhotoPair(), PhotoPair()]

        viewModel.selectAllPairs(from: pairs)
        #expect(viewModel.selectedPairIds == Set(pairs.map(\.id)))

        viewModel.selectAllPairs(from: pairs)
        #expect(viewModel.selectedPairIds.isEmpty)
    }

    @Test
    func `selectAllPairs — 부분 선택 시 전체 선택으로 채움`() {
        let viewModel = makeViewModel()
        let pairs = [PhotoPair(), PhotoPair()]
        viewModel.togglePairSelection(pairs[0].id)

        viewModel.selectAllPairs(from: pairs)

        #expect(viewModel.selectedPairIds == Set(pairs.map(\.id)))
    }

    @Test
    func `areAllPairsSelected — 빈 배열 false, 부분 false, 전체 true`() {
        let viewModel = makeViewModel()
        let pairs = [PhotoPair(), PhotoPair()]

        #expect(!viewModel.areAllPairsSelected(from: []))

        viewModel.togglePairSelection(pairs[0].id)
        #expect(!viewModel.areAllPairsSelected(from: pairs))

        viewModel.togglePairSelection(pairs[1].id)
        #expect(viewModel.areAllPairsSelected(from: pairs))
    }

    @Test
    func `tapPair — selection 모드일 때는 단지 토글 (다른 분기 무시)`() {
        let viewModel = makeViewModel()
        viewModel.isSelectionMode = true
        let pair = PhotoPair(afterPhotoLocalIdentifier: "after-id")

        viewModel.tapPair(pair, allPairs: [pair])

        #expect(viewModel.selectedPairIds == [pair.id])
        #expect(!viewModel.showBeforeCamera)
        #expect(!viewModel.showAfterCamera)
        #expect(viewModel.pendingPreviewPair == nil)
    }

    @Test
    func `tapPair — afterOnly 상태에서 비-selection 모드는 BeforeCamera open`() {
        let viewModel = makeViewModel()
        let pair = PhotoPair(afterPhotoLocalIdentifier: "after-id")
        #expect(pair.status == .afterOnly)

        viewModel.tapPair(pair, allPairs: [pair])

        #expect(viewModel.showBeforeCamera)
        #expect(viewModel.beforeCameraTargetPairId == pair.id)
    }

    @Test
    func `tapPair — scheduled 상태에서 비-selection 모드는 AfterCamera open`() {
        let viewModel = makeViewModel()
        let pair = PhotoPair()
        #expect(pair.status == .scheduled)

        viewModel.tapPair(pair, allPairs: [pair])

        #expect(viewModel.showAfterCamera)
        #expect(viewModel.afterCameraTargetPairId == pair.id)
    }

    @Test
    func `tapPair — captured 상태에서 비-selection 모드는 preview pending 설정`() {
        let viewModel = makeViewModel()
        let pair = PhotoPair(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: "after-id",
        )
        #expect(pair.status == .captured)

        viewModel.tapPair(pair, allPairs: [pair])

        #expect(viewModel.pendingPreviewPair?.pair.id == pair.id)
        #expect(!viewModel.showBeforeCamera)
        #expect(!viewModel.showAfterCamera)
    }

    @Test
    func `pruneStalePairSelections — currentIds 에 없는 ID 만 제거`() {
        let viewModel = makeViewModel()
        let live = UUID()
        let stale = UUID()
        viewModel.selectedPairIds = [live, stale]

        viewModel.pruneStalePairSelections(currentIds: [live])

        #expect(viewModel.selectedPairIds == [live])
    }

    @Test
    func `pruneStalePairSelections — 변동 없으면 no-op`() {
        let viewModel = makeViewModel()
        let id1 = UUID()
        let id2 = UUID()
        viewModel.selectedPairIds = [id1, id2]

        viewModel.pruneStalePairSelections(currentIds: [id1, id2])

        #expect(viewModel.selectedPairIds == [id1, id2])
    }

    @Test
    func `longPressPair — selection 모드 진입 + 해당 pair 단독 선택`() {
        let viewModel = makeViewModel()
        let pair = PhotoPair()

        viewModel.longPressPair(pair)

        #expect(viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds == [pair.id])
    }

    @Test
    func `longPressPair — 이미 selection 모드 시 no-op (selection 불변)`() {
        let viewModel = makeViewModel()
        let preselected = UUID()
        viewModel.isSelectionMode = true
        viewModel.selectedPairIds = [preselected]
        let other = PhotoPair()

        viewModel.longPressPair(other)

        #expect(viewModel.selectedPairIds == [preselected])
    }

    @Test
    func `beginRename — currentName 으로 renameDraft 초기화 + showRenameAlert true`() {
        let viewModel = makeViewModel()

        viewModel.beginRename(currentName: "원래 이름")

        #expect(viewModel.renameDraft == "원래 이름")
        #expect(viewModel.showRenameAlert)
    }

    @Test
    func `startPairPicker — navigateToPairPicker true 설정`() {
        let viewModel = makeViewModel()

        viewModel.startPairPicker()

        #expect(viewModel.navigateToPairPicker)
    }

    @Test
    func `init — albumId 보존, default state`() {
        let albumId = UUID()
        let viewModel = Self.makeEnv().makeAlbumDetailViewModel(albumId: albumId)

        #expect(viewModel.albumId == albumId)
        #expect(!viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds.isEmpty)
        #expect(!viewModel.albumDeleted)
        #expect(!viewModel.navigateToPairPicker)
    }

    private func makeViewModel() -> AlbumDetailViewModel {
        Self.makeEnv().makeAlbumDetailViewModel(albumId: UUID())
    }

    private static func makeEnv() -> AppEnvironment {
        let suiteName = "albumdetail-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let settings = AppSettings(defaults: defaults)
        return AppEnvironment(
            modelContainer: makeContainer(),
            appSettings: settings,
        )
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("test container failure: \(error)")
        }
    }
}

@MainActor
struct PhotoPairStatusTests {
    @Test
    func `status — before+after 둘 다 있으면 captured`() {
        let pair = PhotoPair(
            beforePhotoLocalIdentifier: "before",
            afterPhotoLocalIdentifier: "after",
        )
        #expect(pair.status == .captured)
    }

    @Test
    func `status — after 만 있으면 afterOnly`() {
        let pair = PhotoPair(afterPhotoLocalIdentifier: "after")
        #expect(pair.status == .afterOnly)
    }

    @Test
    func `status — 둘 다 nil 이면 scheduled`() {
        let pair = PhotoPair()
        #expect(pair.status == .scheduled)
    }

    @Test
    func `status — 빈 문자열 identifier 는 nil 과 동일 취급`() {
        let pair = PhotoPair(beforePhotoLocalIdentifier: "", afterPhotoLocalIdentifier: "")
        #expect(pair.status == .scheduled)
    }

    @Test
    func `status — before 빈 문자열 + after 비어있지 않음 → afterOnly`() {
        let pair = PhotoPair(beforePhotoLocalIdentifier: "", afterPhotoLocalIdentifier: "after")
        #expect(pair.status == .afterOnly)
    }
}
