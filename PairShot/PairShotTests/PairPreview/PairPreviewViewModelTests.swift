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
    func `resetZoom — zoom 양쪽을 1로 reset`() {
        let viewModel = makeViewModel()
        viewModel.pinchBaseScale = 3.0
        viewModel.zoomScale = 3.0

        viewModel.resetZoom()

        #expect(viewModel.zoomScale == 1.0)
        #expect(viewModel.pinchBaseScale == 1.0)
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
