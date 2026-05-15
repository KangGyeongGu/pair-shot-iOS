import Foundation

extension BeforeCameraViewModel {
    func toggleLens() {
        let next: CameraLensPosition = lensPosition == .back ? .front : .back
        Task {
            await session.switchLens(to: next)
            let snapshot = await session.zoomSnapshot()
            lensPosition = next
            applyZoomSnapshot(snapshot)
            pinchBaseFactor = snapshot.currentFactor
            activePreset = matchingPreset(for: pinchBaseFactor)
        }
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

    func cycleFlash() {
        Task {
            let next = await session.cycleFlashMode()
            flashMode = next
        }
    }

    func cycleAspect() {
        let next = currentAspect.next
        currentAspect = next
        appSettings.cameraAspectRatio = next
        Task { await session.setAspectRatio(next) }
    }

    func onTapFocus(devicePoint: CGPoint) {
        Task { await session.focus(at: devicePoint) }
    }

    func onExposureBias(_ bias: Float) {
        Task { await session.setExposureBias(bias) }
    }
}
