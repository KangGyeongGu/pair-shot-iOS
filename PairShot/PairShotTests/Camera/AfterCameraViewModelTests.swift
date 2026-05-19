import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct AfterCameraViewModelTests {
    @Test
    func `applyZoomSnapshot — snapshot 값을 ViewModel state 로 정확 매핑`() {
        let viewModel = makeViewModel()
        let snapshot = CameraZoomSnapshot(
            minFactor: 0.5,
            maxFactor: 8,
            currentFactor: 2.0,
            firstSwitchOver: 2.0,
            displayMultiplier: 0.5,
            presets: [],
            exposureBiasRange: nil,
        )

        viewModel.applyZoomSnapshot(snapshot)

        #expect(viewModel.minZoom == 0.5)
        #expect(viewModel.maxZoom == 8)
        #expect(viewModel.currentZoomRatio == 2.0)
        #expect(viewModel.firstSwitchOver == 2.0)
        #expect(viewModel.displayMultiplier == 0.5)
    }

    @Test
    func `applyZoomSnapshot empty — 모든 zoom 값 1 로 reset`() {
        let viewModel = makeViewModel()
        viewModel.minZoom = 5
        viewModel.maxZoom = 20

        viewModel.applyZoomSnapshot(.empty)

        #expect(viewModel.minZoom == 1)
        #expect(viewModel.maxZoom == 1)
        #expect(viewModel.currentZoomRatio == 1)
    }

    @Test
    func `onSelectionChanged — newId 가 nil 이면 currentPair 유지`() {
        let viewModel = makeViewModel()
        let pair1 = PhotoPair()
        viewModel.pairs = [pair1]
        viewModel.currentPair = pair1
        viewModel.selectedPairId = pair1.id

        viewModel.onSelectionChanged(nil)

        #expect(viewModel.currentPair?.id == pair1.id)
    }

    @Test
    func `onSelectionChanged — newId 가 currentPair_id 와 같으면 no-op`() {
        let viewModel = makeViewModel()
        let pair1 = PhotoPair()
        viewModel.pairs = [pair1, PhotoPair()]
        viewModel.currentPair = pair1
        viewModel.selectedPairId = pair1.id
        let initialGhost = viewModel.ghostImageData

        viewModel.onSelectionChanged(pair1.id)

        #expect(viewModel.currentPair?.id == pair1.id)
        #expect(viewModel.ghostImageData == initialGhost)
    }

    @Test
    func `onSelectionChanged — newId 가 pairs 에 없으면 currentPair 변경 없음`() {
        let viewModel = makeViewModel()
        let pair1 = PhotoPair()
        viewModel.pairs = [pair1]
        viewModel.currentPair = pair1

        viewModel.onSelectionChanged(UUID())

        #expect(viewModel.currentPair?.id == pair1.id)
    }

    @Test
    func `onSelectionChanged — newId 매칭 시 adopt 호출 — currentPair 전환 + selectedPairId 갱신`() {
        let viewModel = makeViewModel()
        let pair1 = PhotoPair()
        let pair2 = PhotoPair()
        viewModel.pairs = [pair1, pair2]
        viewModel.currentPair = pair1
        viewModel.selectedPairId = pair1.id

        viewModel.onSelectionChanged(pair2.id)

        #expect(viewModel.currentPair?.id == pair2.id)
        #expect(viewModel.selectedPairId == pair2.id)
    }

    @Test
    func `adopt — pair 변경 시 ghostImageData reset (이전 값 무효화)`() {
        let viewModel = makeViewModel()
        let pair = PhotoPair()
        viewModel.ghostImageData = Data([0x01, 0x02])

        viewModel.adopt(pair: pair)

        #expect(viewModel.currentPair?.id == pair.id)
        #expect(viewModel.ghostImageData == nil)
    }

    @Test
    func `adopt — hasRestoredZoom 을 false 로 reset (새 pair 마다 zoom 재복원 가능)`() {
        let viewModel = makeViewModel()
        viewModel.hasRestoredZoom = true

        viewModel.adopt(pair: PhotoPair())

        #expect(!viewModel.hasRestoredZoom)
    }

    @Test
    func `init — albumId, initialPairId, sortOrder 보존`() {
        let env = Self.makeEnv()
        let albumId = UUID()
        let initialPairId = UUID()

        let viewModel = env.makeAfterCameraViewModel(
            albumId: albumId,
            initialPairId: initialPairId,
            sortOrder: .oldest,
        )

        #expect(viewModel.albumId == albumId)
        #expect(viewModel.initialPairId == initialPairId)
        #expect(viewModel.sortOrder == .oldest)
    }

    private func makeViewModel() -> AfterCameraViewModel {
        Self.makeEnv().makeAfterCameraViewModel(albumId: nil)
    }

    private static func makeEnv() -> AppEnvironment {
        let suiteName = "aftercamera-vm-\(UUID().uuidString)"
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
