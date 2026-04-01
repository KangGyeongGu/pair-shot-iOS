import AVFoundation
import SwiftUI
import UIKit

struct CameraView: View {
    @State private var cameraManager = CameraManager()
    @State private var cameraSettings = CameraSettings()
    @State private var lowLightManager = LowLightManager()

    @State private var captureCount: Int = 0
    @State private var timerCountdown: Int = 0
    @State private var isTimerRunning: Bool = false
    @State private var isMenuExpanded: Bool = false
    @State private var pinchBaseZoom: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    CameraPreviewView(
                        previewLayer: cameraManager.previewLayer,
                        aspectRatio: cameraSettings.currentAspectRatio
                    )
                    .gesture(pinchGesture)

                    GridOverlayView(isGridEnabled: cameraSettings.isGridEnabled)

                    if !cameraManager.isCameraAuthorized, !cameraManager.isSessionRunning {
                        PermissionDeniedView.camera
                    }
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipped()
                .overlay(alignment: .bottom) {
                    ZoomControlView(
                        availableFactors: cameraSettings.availableZoomFactors,
                        currentFactor: cameraSettings.currentZoomFactor,
                        minFactor: cameraSettings.minZoomFactor,
                        maxFactor: cameraSettings.maxZoomFactor,
                        zoomDivisor: cameraSettings.zoomDivisor,
                        onZoomChanged: { factor in
                            // 버튼 탭: ramp 애니메이션
                            cameraManager.setZoom(factor: factor)
                            cameraSettings.currentZoomFactor = factor
                        },
                        onZoomDrag: { factor in
                            // 드래그: 즉각 반응
                            cameraManager.setZoomDirect(factor: factor)
                            cameraSettings.currentZoomFactor = factor
                        }
                    )
                    .padding(.bottom, 12)
                }

                // 셔터 버튼: 프리뷰 바로 아래, 자기 크기만큼만
                VStack(spacing: 0) {
                    if lowLightManager.isTorchActive {
                        torchIndicator.padding(.top, 4)
                    }

                    ShutterButton { handleShutterTap() }
                        .padding(.vertical, 12)
                }
                .background(Color.black)

                // 최하단 행: safe area 하단에 고정
                HStack {
                    thumbnailView
                    Spacer()
                    captureCountLabel
                    Spacer()
                    cameraSwitchButton
                }
                .padding(.horizontal, 40)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color.black)
            }
        }
        .statusBarHidden(true)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height < -30 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMenuExpanded = true
                        }
                    }
                }
        )
        .overlay {
            if isMenuExpanded {
                menuPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if isTimerRunning, timerCountdown > 0 {
                timerCountdownOverlay
            }
        }
        .task {
            await startCamera()
        }
        .onChange(of: cameraManager.isSessionRunning) { _, running in
            if running {
                let info = cameraManager.getZoomInfo()
                // 줌 버튼: min + 렌즈 전환점 + 2x 크롭 등 네이티브 포인트
                var factors = [info.minFactor] + info.switchOverFactors + info.secondaryNativeResolutionZoomFactors
                factors = Array(Set(factors)).sorted()
                cameraSettings.availableZoomFactors = factors
                cameraSettings.currentZoomFactor = info.defaultFactor
                // displayVideoZoomFactorMultiplier: Apple 시스템 UI와 동일한 표시 계산
                cameraSettings.zoomDivisor = info.displayMultiplier
                cameraSettings.minZoomFactor = info.minFactor
                // 실용 줌 한도: 15x 또는 기기 max 중 작은 값
                cameraSettings.maxZoomFactor = min(info.maxFactor, info.defaultFactor * 15.0)
            }
        }
        .onDisappear { cameraManager.stopSession() }
        .onChange(of: cameraManager.capturedPhoto) { _, newPhoto in
            if newPhoto != nil { captureCount += 1 }
        }
    }

    private var torchIndicator: some View {
        HStack(spacing: 4) {
            Circle().fill(.yellow).frame(width: 6, height: 6)
            Text("저조도 보정").font(.system(size: 11)).foregroundStyle(.yellow)
        }
    }

    private var captureCountLabel: some View {
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

    private var thumbnailView: some View {
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

    private var cameraSwitchButton: some View {
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

    private var menuPanel: some View {
        VStack(spacing: 0) {
            Color.black.opacity(0.4)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isMenuExpanded = false
                    }
                }

            CameraControlBar(
                flashMode: Binding(get: { cameraSettings.flashMode }, set: { _ in cameraSettings.cycleFlashMode() }),
                aspectRatio: Binding(get: { cameraSettings.currentAspectRatio }, set: { _ in cameraSettings.cycleAspectRatio() }),
                isGridEnabled: Binding(get: { cameraSettings.isGridEnabled }, set: { _ in cameraSettings.toggleGrid() }),
                timerDuration: Binding(get: { cameraSettings.timerDuration }, set: { _ in cameraSettings.cycleTimer() }),
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

    private var timerCountdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            Text("\(timerCountdown)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                _ = pinchBaseZoom * value
            }
            .onEnded { _ in
                pinchBaseZoom = cameraSettings.currentZoomFactor
            }
    }

    private func startCamera() async {
        let granted = await cameraManager.requestAuthorization()
        guard granted else { return }
        cameraManager.startSession()
    }

    private func handleShutterTap() {
        if cameraSettings.timerDuration == .off {
            cameraManager.capturePhoto(projectId: UUID(), pairId: UUID())
        } else {
            startTimerCapture()
        }
    }

    private func startTimerCapture() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        timerCountdown = cameraSettings.timerDuration.seconds

        Task {
            while timerCountdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                withAnimation { timerCountdown -= 1 }
            }
            cameraManager.capturePhoto(projectId: UUID(), pairId: UUID())
            isTimerRunning = false
        }
    }
}

#Preview {
    CameraView()
}
