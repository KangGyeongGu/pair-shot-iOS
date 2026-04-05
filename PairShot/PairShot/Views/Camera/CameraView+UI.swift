import AVFoundation
import SwiftUI

extension CameraView {
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
                Text("PHOTO")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.yellow)
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isMenuExpanded = false }
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
}
