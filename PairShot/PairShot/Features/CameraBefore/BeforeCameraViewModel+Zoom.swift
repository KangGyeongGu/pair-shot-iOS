import Foundation

extension BeforeCameraViewModel {
    func onPinchChanged(_ scale: Double) {
        let target = pinchBaseFactor * scale
        currentZoomRatio = clampZoom(target)
        activePreset = matchingPreset(for: target)
        pinchRampTask?.cancel()
        pinchRampTask = Task { [session] in
            guard !Task.isCancelled else { return }
            await session.ramp(toZoomFactor: target, rate: 6.0)
        }
    }

    func onPinchEnded(_ scale: Double) {
        pinchBaseFactor *= scale
        pinchRampTask?.cancel()
        pinchRampTask = nil
    }

    func applyPreset(_ preset: ZoomPresetSpec) {
        activePreset = preset
        pinchBaseFactor = preset.factor
        currentZoomRatio = preset.factor
        Task { await session.ramp(toZoomFactor: preset.factor, rate: 32.0) }
    }

    func onZoomDragBegan() {
        if !isDraggingZoom {
            dragAccumulatorPx = 0
            dragStartRatio = currentZoomRatio
            lastMinorTickIndex = Int((currentZoomRatio * 10).rounded())
            lastMajorTickIndex = Int(currentZoomRatio.rounded())
            isDraggingZoom = true
        }
    }

    func onZoomDragChanged(deltaPx: Double) {
        onZoomDragBegan()
        dragAccumulatorPx = deltaPx
        let span = max(maxZoom - minZoom, 0.0001)
        let pxPerZoom = ZoomDialMetrics.dragRangeSpanPt / span
        let zoomDelta = dragAccumulatorPx / pxPerZoom
        let target = clampZoom(dragStartRatio + zoomDelta)
        currentZoomRatio = target
        activePreset = matchingPreset(for: target)
        zoomRampTask?.cancel()
        zoomRampTask = Task { [session] in
            guard !Task.isCancelled else { return }
            await session.ramp(toZoomFactor: target, rate: 32.0)
        }
        emitTickHaptics(for: target)
    }

    func onZoomDragEnded() {
        isDraggingZoom = false
        pinchBaseFactor = currentZoomRatio
        lastMinorTickIndex = nil
        lastMajorTickIndex = nil
        zoomRampTask?.cancel()
        zoomRampTask = nil
    }

    func clampZoom(_ value: Double) -> Double {
        max(minZoom, min(value, maxZoom))
    }

    func matchingPreset(for factor: Double) -> ZoomPresetSpec? {
        availablePresets.last { $0.factor <= factor + 0.05 } ?? availablePresets.first
    }

    func emitTickHaptics(for ratio: Double) {
        let minorIndex = Int((ratio * 10).rounded())
        if minorIndex != lastMinorTickIndex {
            lastMinorTickIndex = minorIndex
            hapticService.impact(.light)
        }
        let majorIndex = Int(ratio.rounded())
        if abs(ratio - Double(majorIndex)) < 0.05, majorIndex != lastMajorTickIndex {
            lastMajorTickIndex = majorIndex
            hapticService.impact(.medium)
        }
    }
}
