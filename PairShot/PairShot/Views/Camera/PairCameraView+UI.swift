import AVFoundation
import SwiftUI

extension PairCameraView {
    var cameraPreviewSection: some View {
        GeometryReader { previewGeo in
            ZStack {
                CameraPreviewView(
                    previewLayer: cameraManager.previewLayer,
                    aspectRatio: cameraSettings.currentAspectRatio
                )
                .gesture(pinchGesture)
                GridOverlayView(isGridEnabled: cameraSettings.isGridEnabled)
                LevelIndicatorView(previewWidth: previewGeo.size.width)
                if !cameraManager.isCameraAuthorized, !cameraManager.isSessionRunning {
                    PermissionDeniedView.camera
                }
                if showFocusIndicator, let point = focusPoint {
                    FocusIndicatorView(
                        exposureBias: exposureBias,
                        exposureBiasMax: cameraManager.getExposureBiasRange().max,
                        isDraggingExposure: isDraggingExposure,
                        scale: focusIndicatorScale,
                        opacity: focusIndicatorOpacity
                    )
                    .position(point)
                }
                if !isBefore { afterModeOverlays }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(tapGesture)
            .simultaneousGesture(exposureDragGesture)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .overlay {
            ZoomControlView(
                availableFactors: cameraSettings.availableZoomFactors,
                allFixedFactors: cameraSettings.allFixedFactors,
                focalLengthMap: cameraSettings.focalLengthMap,
                currentFactor: cameraSettings.currentZoomFactor,
                minFactor: cameraSettings.minZoomFactor,
                maxFactor: cameraSettings.maxZoomFactor,
                zoomDivisor: cameraSettings.zoomDivisor,
                onZoomChanged: { factor in
                    cameraManager.setZoom(factor: factor)
                    cameraSettings.currentZoomFactor = factor
                },
                onZoomDrag: { factor in
                    cameraManager.setZoomDirect(factor: factor)
                    cameraSettings.currentZoomFactor = factor
                }
            )
        }
        .clipped()
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .padding(12)
        }
    }

    @ViewBuilder var afterModeOverlays: some View {
        GhostOverlayView(beforeImage: beforeImage, opacity: $ghostOpacity)
        if ghostOpacity > 0 {
            GhostOpacitySlider(opacity: $ghostOpacity) { newValue in
                ghostDefaultOpacity = newValue
            }
        }
        SixDOFGuideView(
            lateralDeltaCm: positionMatcher.lateralDisplacementCm,
            heightDeltaCm: heightDeltaCm,
            distanceDeltaCm: distanceDeltaCm,
            yawDeltaDeg: yawDeltaDeg,
            pitchDeltaDeg: pitchDeltaDeg,
            rollDeltaDeg: rollDeltaDeg,
            hasLiDAR: depthService.isLiDARAvailable,
            positionThresholdCm: 5.0,
            orientationThresholdDeg: 2.0
        )
        .allowsHitTesting(false)
    }

    var pitchDeltaDeg: Double {
        (sensorManager.currentPitch - beforePitch) * (180 / .pi)
    }

    var rollDeltaDeg: Double {
        (sensorManager.currentRoll - beforeRoll) * (180 / .pi)
    }

    var yawDeltaDeg: Double {
        var delta = sensorManager.currentHeading - beforeHeading
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    var heightDeltaCm: Double {
        positionMatcher.verticalDisplacementCm
    }

    var distanceDeltaCm: Double {
        guard depthService.isLiDARAvailable, beforeDepth > 0 else { return 0 }
        return (depthService.centerDepth - beforeDepth) * 100
    }

    var tapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                if !isBefore, ghostAutoActivated {
                    ghostOpacity = ghostOpacity > 0 ? 0.0 : ghostDefaultOpacity
                }
                let location = value.location
                cameraManager.focusAndExpose(at: location)
                focusPoint = location
                showFocusIndicator = true
                focusIndicatorScale = 1.2
                exposureBias = 0
                cameraManager.setExposureBias(0)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    focusIndicatorScale = 1.0
                }
                focusHideTask?.cancel()
                focusHideTask = Task {
                    try? await Task.sleep(for: .seconds(2.0))
                    withAnimation(.easeOut(duration: 0.5)) { focusIndicatorOpacity = 0.3 }
                }
                focusIndicatorOpacity = 1.0
            }
    }

    var exposureDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if !isDraggingExposure {
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    guard showFocusIndicator || focusPoint != nil else { return }
                    isDraggingExposure = true
                    exposureDragStartY = value.startLocation.y
                    exposureBiasAtDragStart = exposureBias
                    showFocusIndicator = true
                    focusIndicatorOpacity = 1.0
                }
                focusHideTask?.cancel()
                let dragDelta = exposureDragStartY - value.location.y
                let range = cameraManager.getExposureBiasRange()
                let deltaEV = Float(dragDelta / 2400.0) * (range.max - range.min)
                let newBias = max(range.min, min(exposureBiasAtDragStart + deltaEV, range.max))
                exposureBias = newBias
                cameraManager.setExposureBias(newBias)
                focusIndicatorOpacity = 1.0
            }
            .onEnded { _ in
                isDraggingExposure = false
                focusHideTask = Task {
                    try? await Task.sleep(for: .seconds(2.0))
                    withAnimation(.easeOut(duration: 0.5)) { focusIndicatorOpacity = 0.3 }
                }
            }
    }

    var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let factor = pinchBaseZoom * value
                cameraManager.setZoomDirect(factor: factor)
                cameraSettings.currentZoomFactor = factor
            }
            .onEnded { _ in pinchBaseZoom = cameraSettings.currentZoomFactor }
    }

    var menuSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                if value.translation.height < -30 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isMenuExpanded = true }
                }
            }
    }

    var torchIndicator: some View {
        HStack(spacing: 4) {
            Circle().fill(.yellow).frame(width: 6, height: 6)
            Text("저조도 보정").font(.system(size: 11)).foregroundStyle(.yellow)
        }
    }

    var captureCountLabel: some View {
        Group {
            if captureCount > 0 {
                Text("\(captureCount)장 촬영")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text(isBefore ? "BEFORE" : "AFTER")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isBefore ? .yellow : .green)
            }
        }
    }

    var thumbnailView: some View {
        Group {
            if let photo = cameraManager.capturedPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
            } else {
                Circle()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 48, height: 48)
            }
        }
    }

    var cameraSwitchButton: some View {
        Button {
            cameraManager.switchCamera()
            cameraSettings.setFrontCamera(!cameraSettings.isUsingFrontCamera)
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    var menuPanel: some View {
        VStack(spacing: 0) {
            Color.black.opacity(0.4)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isMenuExpanded = false }
                }
            CameraControlBar(
                flashMode: Binding(get: { cameraSettings.flashMode }, set: { _ in cameraSettings.cycleFlashMode() }),
                aspectRatio: Binding(
                    get: { cameraSettings.currentAspectRatio },
                    set: { _ in cameraSettings.cycleAspectRatio() }
                ),
                isGridEnabled: Binding(
                    get: { cameraSettings.isGridEnabled },
                    set: { _ in cameraSettings.toggleGrid() }
                ),
                timerDuration: Binding(
                    get: { cameraSettings.timerDuration },
                    set: { _ in cameraSettings.cycleTimer() }
                ),
                onFlashTap: { cameraSettings.cycleFlashMode() },
                onRatioTap: { cameraSettings.cycleAspectRatio() },
                onGridTap: { cameraSettings.toggleGrid() },
                onTimerTap: { cameraSettings.cycleTimer() }
            )
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height > 30 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isMenuExpanded = false
                            }
                        }
                    }
            )
        }
    }

    var timerCountdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            Text("\(timerCountdown)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }
}
