import CoreGraphics
import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct PairPreviewViewModelTests {
    @Test
    func `init — pair 보존, default state (zoom 1, no error, no preview)`() {
        let pair = PhotoPair()
        let viewModel = makeViewModel(pair: pair)

        #expect(viewModel.pair.id == pair.id)
        #expect(viewModel.zoomScale == 1.0)
        #expect(viewModel.pinchBaseScale == 1.0)
        #expect(viewModel.panOffset == .zero)
        #expect(viewModel.panBaseOffset == .zero)
        #expect(viewModel.containerSize == .zero)
        #expect(viewModel.livePreviewImage == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isRendering)
    }

    @Test
    func `onPinchChanged — pinchBaseScale × value 가 zoomScale 로 적용 (in range)`() {
        let viewModel = makeViewModel()
        viewModel.pinchBaseScale = 2.0

        viewModel.onPinchChanged(1.5)

        #expect(viewModel.zoomScale == 3.0)
    }

    @Test
    func `onPinchChanged — minZoom 보다 작으면 minZoom 으로 clamp`() {
        let viewModel = makeViewModel()
        viewModel.pinchBaseScale = 1.0

        viewModel.onPinchChanged(0.1)

        #expect(viewModel.zoomScale == PairPreviewViewModel.minZoom)
    }

    @Test
    func `onPinchChanged — maxZoom 보다 크면 maxZoom 으로 clamp`() {
        let viewModel = makeViewModel()
        viewModel.pinchBaseScale = 2.0

        viewModel.onPinchChanged(10.0)

        #expect(viewModel.zoomScale == PairPreviewViewModel.maxZoom)
    }

    @Test
    func `onPinchChanged — pinchBaseScale 자체는 변경 안 됨 (live preview 만)`() {
        let viewModel = makeViewModel()
        viewModel.pinchBaseScale = 2.0

        viewModel.onPinchChanged(1.5)

        #expect(viewModel.pinchBaseScale == 2.0)
        #expect(viewModel.zoomScale == 3.0)
    }

    @Test
    func `onPinchEnded — pinchBaseScale 와 zoomScale 모두 clamp 된 최종값으로 업데이트`() {
        let viewModel = makeViewModel()
        viewModel.pinchBaseScale = 1.5

        viewModel.onPinchEnded(2.0)

        #expect(viewModel.pinchBaseScale == 3.0)
        #expect(viewModel.zoomScale == 3.0)
    }

    @Test
    func `onPinchEnded — clamp 범위 밖 시 두 값 모두 maxZoom`() {
        let viewModel = makeViewModel()
        viewModel.pinchBaseScale = 3.0

        viewModel.onPinchEnded(5.0)

        #expect(viewModel.pinchBaseScale == PairPreviewViewModel.maxZoom)
        #expect(viewModel.zoomScale == PairPreviewViewModel.maxZoom)
    }

    @Test
    func `resetZoom — zoom + pan 양쪽 모두 reset`() {
        let viewModel = makeViewModel()
        viewModel.updateContainerSize(CGSize(width: 200, height: 400))
        viewModel.pinchBaseScale = 3.0
        viewModel.zoomScale = 3.0
        viewModel.panOffset = CGSize(width: 50, height: 100)
        viewModel.panBaseOffset = CGSize(width: 50, height: 100)

        viewModel.resetZoom()

        #expect(viewModel.zoomScale == 1.0)
        #expect(viewModel.pinchBaseScale == 1.0)
        #expect(viewModel.panOffset == .zero)
        #expect(viewModel.panBaseOffset == .zero)
    }

    @Test
    func `updateContainerSize — containerSize 갱신 + scale 1_0 에서 기존 offset 0 으로 clamp`() {
        let viewModel = makeViewModel()
        viewModel.panOffset = CGSize(width: 50, height: 30)
        viewModel.panBaseOffset = CGSize(width: 50, height: 30)

        viewModel.updateContainerSize(CGSize(width: 300, height: 400))

        #expect(viewModel.containerSize == CGSize(width: 300, height: 400))
        #expect(viewModel.panOffset == .zero)
        #expect(viewModel.panBaseOffset == .zero)
    }

    @Test
    func `onDragChanged — pan offset 가 base + translation (범위 내, base 는 불변)`() {
        let viewModel = makeViewModel()
        viewModel.updateContainerSize(CGSize(width: 300, height: 400))
        viewModel.zoomScale = 3.0
        viewModel.pinchBaseScale = 3.0
        viewModel.panBaseOffset = CGSize(width: 10, height: 20)

        viewModel.onDragChanged(translation: CGSize(width: 50, height: 40))

        #expect(viewModel.panOffset == CGSize(width: 60, height: 60))
        #expect(viewModel.panBaseOffset == CGSize(width: 10, height: 20))
    }

    @Test
    func `onDragChanged — 범위 초과 시 maxX maxY 로 clamp`() {
        let viewModel = makeViewModel()
        viewModel.updateContainerSize(CGSize(width: 200, height: 400))
        viewModel.zoomScale = 2.0
        viewModel.pinchBaseScale = 2.0

        viewModel.onDragChanged(translation: CGSize(width: 500, height: 500))

        #expect(viewModel.panOffset == CGSize(width: 100, height: 200))
    }

    @Test
    func `onDragChanged — scale 1_0 시 offset 0 으로 clamp (zoom out 상태 pan 무효)`() {
        let viewModel = makeViewModel()
        viewModel.updateContainerSize(CGSize(width: 300, height: 400))

        viewModel.onDragChanged(translation: CGSize(width: 50, height: 50))

        #expect(viewModel.panOffset == .zero)
    }

    @Test
    func `onDragEnded — panBaseOffset 커밋 (다음 drag 의 시작점)`() {
        let viewModel = makeViewModel()
        viewModel.updateContainerSize(CGSize(width: 300, height: 400))
        viewModel.zoomScale = 2.0
        viewModel.pinchBaseScale = 2.0
        viewModel.panBaseOffset = CGSize(width: 10, height: 0)

        viewModel.onDragEnded(translation: CGSize(width: 20, height: 0))

        #expect(viewModel.panBaseOffset == CGSize(width: 30, height: 0))
        #expect(viewModel.panOffset == CGSize(width: 30, height: 0))
    }

    @Test
    func `onPinchChanged — center anchor + panBaseOffset 0 이면 offset 0 유지`() {
        let viewModel = makeViewModel()
        viewModel.updateContainerSize(CGSize(width: 200, height: 400))
        viewModel.pinchBaseScale = 1.0

        viewModel.onPinchChanged(2.0, anchor: CGPoint(x: 0.5, y: 0.5))

        #expect(viewModel.zoomScale == 2.0)
        #expect(viewModel.panOffset == .zero)
    }

    @Test
    func `onPinchChanged — top-left anchor 줌인 시 anchor 가 화면 고정되도록 offset 이동`() {
        let viewModel = makeViewModel()
        viewModel.updateContainerSize(CGSize(width: 200, height: 400))
        viewModel.pinchBaseScale = 1.0

        viewModel.onPinchChanged(2.0, anchor: CGPoint.zero)

        #expect(viewModel.zoomScale == 2.0)
        #expect(viewModel.panOffset == CGSize(width: 100, height: 200))
    }

    @Test
    func `onPinchEnded — pinchBaseScale + panBaseOffset 모두 커밋`() {
        let viewModel = makeViewModel()
        viewModel.updateContainerSize(CGSize(width: 200, height: 400))
        viewModel.pinchBaseScale = 1.0

        viewModel.onPinchEnded(2.0, anchor: CGPoint.zero)

        #expect(viewModel.pinchBaseScale == 2.0)
        #expect(viewModel.panBaseOffset == CGSize(width: 100, height: 200))
        #expect(viewModel.zoomScale == 2.0)
        #expect(viewModel.panOffset == CGSize(width: 100, height: 200))
    }

    @Test
    func `onPinchChanged — containerSize 0 일 때 NaN 없이 안전 (offset 0)`() {
        let viewModel = makeViewModel()
        viewModel.pinchBaseScale = 1.0

        viewModel.onPinchChanged(2.0, anchor: CGPoint.zero)

        #expect(viewModel.zoomScale == 2.0)
        #expect(viewModel.panOffset == .zero)
    }

    @Test
    func `onPinchChanged — minZoom 으로 clamp 되면 offset 도 0 으로 clamp`() {
        let viewModel = makeViewModel()
        viewModel.updateContainerSize(CGSize(width: 200, height: 400))
        viewModel.pinchBaseScale = 2.0
        viewModel.panBaseOffset = CGSize(width: 80, height: 100)

        viewModel.onPinchChanged(0.1, anchor: CGPoint(x: 0.5, y: 0.5))

        #expect(viewModel.zoomScale == 1.0)
        #expect(viewModel.panOffset == .zero)
    }

    @Test
    func `clearError — errorMessage nil 로 초기화`() {
        let viewModel = makeViewModel()
        viewModel.errorMessage = "fail"

        viewModel.clearError()

        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func `dismiss — events stream 으로 dismiss event yield`() async {
        let viewModel = makeViewModel()

        viewModel.dismiss()

        var iterator = viewModel.events.makeAsyncIterator()
        let event = await iterator.next()
        #expect(event == .dismiss)
    }

    @Test
    func `zoom 범위 상수 — minZoom 1_0, maxZoom 4_0 (UI 핀치 한계)`() {
        #expect(PairPreviewViewModel.minZoom == 1.0)
        #expect(PairPreviewViewModel.maxZoom == 4.0)
    }

    private func makeViewModel(pair: PhotoPair = PhotoPair()) -> PairPreviewViewModel {
        Self.makeEnv().makePairPreviewViewModel(pair: pair)
    }

    private static func makeEnv() -> AppEnvironment {
        let suiteName = "pairpreview-vm-\(UUID().uuidString)"
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
