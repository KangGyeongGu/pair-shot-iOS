import Foundation

@MainActor
extension AfterCameraViewModel {
    func onPinchChanged(_ scale: Double) {
        let target = pinchBaseFactor * scale
        Task { await session.ramp(toZoomFactor: target, rate: 6.0) }
        currentZoomRatio = clampedZoom(target)
        activePreset = AfterCameraZoomPresetMatcher.match(target)
    }

    func onPinchEnded(_ scale: Double) {
        pinchBaseFactor *= scale
    }

    func applyPreset(_ preset: ZoomPreset) {
        activePreset = preset
        pinchBaseFactor = preset.factor
        currentZoomRatio = preset.factor
        Task { await session.setZoomFactor(preset.factor) }
    }

    func onZoomDragChanged(deltaPx: Double) {
        beginZoomDragIfNeeded()
        applyZoomDragDelta(deltaPx)
    }

    func onZoomDragEnded() {
        isDraggingZoom = false
        pinchBaseFactor = currentZoomRatio
        zoomDragState.reset()
    }

    func toggleGrid() {
        isGridOn.toggle()
    }

    func toggleLevel() {
        isLevelOn.toggle()
    }

    func toggleNightMode() {
        isNightModeOn.toggle()
        let enabled = isNightModeOn
        Task { await session.setLowLightBoost(enabled: enabled) }
    }

    func setFlashMode(_ mode: CameraFlashMode) {
        guard mode != flashMode else { return }
        flashMode = mode
        Task { await session.setFlashMode(mode) }
    }

    func toggleLens() {
        let next: CameraLensPosition = lensPosition == .back ? .front : .back
        Task {
            await session.switchLens(to: next)
            await refreshLensCapabilities(next: next)
        }
    }

    private func beginZoomDragIfNeeded() {
        guard !isDraggingZoom else { return }
        zoomDragState.begin(currentRatio: currentZoomRatio)
        isDraggingZoom = true
    }

    private func applyZoomDragDelta(_ deltaPx: Double) {
        zoomDragState.dragAccumulatorPx = deltaPx
        let span = max(maxZoom - minZoom, 0.0001)
        let pxPerZoom = ZoomDialMetrics.dragRangeSpanPt / span
        let zoomDelta = deltaPx / pxPerZoom
        let target = clampedZoom(zoomDragState.dragStartRatio + zoomDelta)
        currentZoomRatio = target
        activePreset = AfterCameraZoomPresetMatcher.match(target)
        Task { await session.ramp(toZoomFactor: target, rate: 6.0) }
        emitTickHaptics(for: target)
    }

    private func emitTickHaptics(for ratio: Double) {
        let result = AfterCameraZoomHaptics.evaluate(
            ratio: ratio,
            lastMinorIndex: zoomDragState.lastMinorTickIndex,
            lastMajorIndex: zoomDragState.lastMajorTickIndex
        )
        zoomDragState.lastMinorTickIndex = result.minorIndex
        zoomDragState.lastMajorTickIndex = result.majorIndex
        if result.didCrossMinor { HapticService.shared.impact(.light) }
        if result.didCrossMajor { HapticService.shared.impact(.medium) }
    }

    private func refreshLensCapabilities(next: CameraLensPosition) async {
        await refreshCapabilities()
        lensPosition = next
        minZoom = await session.minZoomFactor
        maxZoom = await session.maxZoomFactor
        pinchBaseFactor = await session.currentZoomFactor
        currentZoomRatio = pinchBaseFactor
        activePreset = AfterCameraZoomPresetMatcher.match(pinchBaseFactor) ?? .wide
    }

    private func clampedZoom(_ value: Double) -> Double {
        max(minZoom, min(value, maxZoom))
    }
}

@MainActor
final class AfterCameraZoomDragState {
    var dragAccumulatorPx: Double = 0
    var dragStartRatio: Double = 1.0
    var lastMinorTickIndex: Int?
    var lastMajorTickIndex: Int?

    func begin(currentRatio: Double) {
        dragAccumulatorPx = 0
        dragStartRatio = currentRatio
        lastMinorTickIndex = Int((currentRatio * 10).rounded())
        lastMajorTickIndex = Int(currentRatio.rounded())
    }

    func reset() {
        lastMinorTickIndex = nil
        lastMajorTickIndex = nil
    }

    deinit {}
}

enum AfterCameraZoomPresetMatcher {
    static func match(_ factor: Double) -> ZoomPreset? {
        let tolerance = 0.05
        return ZoomPreset.allCases.first { abs($0.factor - factor) <= tolerance }
    }
}
