import Foundation

@MainActor
extension AfterCameraViewModel {
    func onPinchChanged(_ scale: Double) {
        let target = pinchBaseFactor * scale
        currentZoomRatio = clampedZoom(target)
        activePreset = AfterCameraZoomPresetMatcher.match(target, in: availablePresets)
        zoomDragState.pinchRampTask?.cancel()
        zoomDragState.pinchRampTask = Task { [session] in
            guard !Task.isCancelled else { return }
            await session.ramp(toZoomFactor: target, rate: 6.0)
        }
    }

    func onPinchEnded(_ scale: Double) {
        pinchBaseFactor *= scale
        zoomDragState.pinchRampTask?.cancel()
        zoomDragState.pinchRampTask = nil
    }

    func applyPreset(_ preset: ZoomPresetSpec) {
        activePreset = preset
        pinchBaseFactor = preset.factor
        currentZoomRatio = preset.factor
        Task { await session.ramp(toZoomFactor: preset.factor, rate: 32.0) }
    }

    func onZoomDragChanged(deltaPx: Double) {
        beginZoomDragIfNeeded()
        applyZoomDragDelta(deltaPx)
    }

    func onZoomDragEnded() {
        isDraggingZoom = false
        pinchBaseFactor = currentZoomRatio
        zoomDragState.reset()
        zoomDragState.dragRampTask?.cancel()
        zoomDragState.dragRampTask = nil
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

    func cycleFlash() {
        Task {
            let next = await session.cycleFlashMode()
            flashMode = next
        }
    }

    func toggleOverlay() {
        overlayEnabled.toggle()
    }

    func setAlpha(_ value: Double) {
        alpha = GhostOverlayMath.clamp(value)
    }

    func toggleLens() {
        let next: CameraLensPosition = lensPosition == .back ? .front : .back
        Task {
            await session.switchLens(to: next)
            let snapshot = await session.zoomSnapshot()
            applyZoomSnapshot(snapshot)
            lensPosition = next
            pinchBaseFactor = snapshot.currentFactor
            activePreset = AfterCameraZoomPresetMatcher.match(snapshot.currentFactor, in: availablePresets)
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
        activePreset = AfterCameraZoomPresetMatcher.match(target, in: availablePresets)
        zoomDragState.dragRampTask?.cancel()
        zoomDragState.dragRampTask = Task { [session] in
            guard !Task.isCancelled else { return }
            await session.ramp(toZoomFactor: target, rate: 32.0)
        }
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
        if result.didCrossMinor { hapticService.impact(.light) }
        if result.didCrossMajor { hapticService.impact(.medium) }
    }

    private func clampedZoom(_ value: Double) -> Double {
        max(minZoom, min(value, maxZoom))
    }
}

final class AfterCameraZoomDragState {
    var dragAccumulatorPx: Double = 0
    var dragStartRatio: Double = 1.0
    var lastMinorTickIndex: Int?
    var lastMajorTickIndex: Int?
    var dragRampTask: Task<Void, Never>?
    var pinchRampTask: Task<Void, Never>?

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
}

enum AfterCameraZoomPresetMatcher {
    static func match(_ factor: Double, in presets: [ZoomPresetSpec]) -> ZoomPresetSpec? {
        presets.last { $0.factor <= factor + 0.05 } ?? presets.first
    }
}
