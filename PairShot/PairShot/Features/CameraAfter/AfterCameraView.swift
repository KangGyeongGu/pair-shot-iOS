@preconcurrency import AVFoundation
import SwiftData
import SwiftUI
import UIKit

/// Top-level After-capture screen.
///
/// Behaviour (P3):
/// - On entry, loads the oldest `pendingAfter` pair in `project` and shows it.
/// - Renders the Before image as a semi-transparent overlay above the live
///   preview (`GhostOverlayView`) with an alpha slider 0.0~1.0. **No
///   auto-alignment** — plain `.opacity(...)` only (CLAUDE.md hard rule).
/// - Restores the pair's `beforeZoomFactor` on the active device so framing
///   matches; the user can still pinch to override (P2.2 ZoomControl reused).
/// - On capture, transitions the pair to `.complete` and auto-advances to the
///   next `pendingAfter` pair. When none remain, dismisses.
struct AfterCameraView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var appSettings

    @State private var sessionHolder = CameraSessionHolder()
    @State private var currentPair: PhotoPair?
    @State private var ghostImage: UIImage?
    /// Seeded from `appSettings.defaultOverlayAlpha` on first appear (P8.3).
    /// Remains a `@State` rather than a derived binding so the user can
    /// nudge it per-pair without their nudge being clobbered by the
    /// stored default.
    @State private var alpha: Double = GhostOverlayMath.defaultAlpha
    @State private var activePreset: ZoomPreset? = .wide
    @State private var isCapturing: Bool = false
    @State private var pinchBaseFactor: Double = 1.0
    @State private var hasRestoredZoom: Bool = false
    @State private var previewView: CameraPreviewView?

    private let storage = PhotoStorageService()

    private var coordinator: AfterCaptureCoordinator {
        AfterCaptureCoordinator(
            session: sessionHolder.session,
            storage: storage,
            fileNamePrefix: FileNamePrefixValidator.sanitize(appSettings.fileNamePrefix)
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AfterCameraPreviewLayer(
                session: sessionHolder.session.captureSession,
                onMakeView: { view in previewView = view }
            )
            .ignoresSafeArea()

            GhostOverlayView(image: ghostImage, alpha: alpha)
                .ignoresSafeArea()

            // Pinch zoom override (P3.3). Tap area covers the full preview.
            Color.clear
                .contentShape(Rectangle())
                .gesture(pinchGesture)
                .ignoresSafeArea()

            VStack {
                AfterCameraTopBar(
                    pendingCount: pendingPairCount,
                    completedCount: completedPairCount
                )

                Spacer()

                GhostOverlayAlphaSlider(alpha: $alpha)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                ZoomControl(
                    activePreset: activePreset,
                    isSupported: sessionHolder.isPresetSupported(_:),
                    onSelect: applyPreset
                )
                .padding(.bottom, 12)

                AfterCameraShutterRow(
                    isCapturing: isCapturing,
                    enabled: currentPair != nil,
                    action: shutter
                )
                .padding(.bottom, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "닫기")) { dismiss() }
                    .tint(.white)
            }
        }
        .task {
            await onEnterScreen()
        }
        .onDisappear {
            Task { await sessionHolder.session.stop() }
        }
    }

    // MARK: - Computed properties (counts + gestures)

    private var pendingPairCount: Int {
        AfterCameraPairLoader.pendingPairs(in: project).count
    }

    private var completedPairCount: Int {
        project.pairs.count(where: { $0.status == .complete })
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let target = pinchBaseFactor * Double(value)
                Task { await sessionHolder.session.ramp(toZoomFactor: target, rate: 6.0) }
                activePreset = matchingPreset(for: target)
            }
            .onEnded { value in
                pinchBaseFactor *= Double(value)
            }
    }

    // MARK: - Lifecycle

    private func onEnterScreen() async {
        // Seed the slider from the persisted default before the first pair
        // is adopted so the very first frame already shows the user's
        // preferred starting opacity.
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)
        await sessionHolder.session.start()
        await sessionHolder.refreshCapabilities()
        loadFirstPendingOrDismiss()
    }

    private func loadFirstPendingOrDismiss() {
        guard let pair = AfterCameraPairLoader.firstPendingPair(in: project) else {
            dismiss()
            return
        }
        adopt(pair: pair)
    }

    private func adopt(pair: PhotoPair) {
        currentPair = pair
        ghostImage = GhostOverlayLoader.loadImage(relativePath: pair.beforePath, storage: storage)
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)
        hasRestoredZoom = false
        Task { await restoreZoom(for: pair) }
    }

    private func restoreZoom(for pair: PhotoPair) async {
        guard !hasRestoredZoom else { return }
        let target = pair.beforeZoomFactor
        await sessionHolder.session.setZoomFactor(target)
        let actual = await sessionHolder.session.currentZoomFactor
        await MainActor.run {
            pinchBaseFactor = actual
            activePreset = matchingPreset(for: actual)
            hasRestoredZoom = true
        }
    }

    private func matchingPreset(for factor: Double) -> ZoomPreset? {
        let tolerance = 0.05
        return ZoomPreset.allCases.first { abs($0.factor - factor) <= tolerance }
    }

    // MARK: - Actions

    private func applyPreset(_ preset: ZoomPreset) {
        activePreset = preset
        pinchBaseFactor = preset.factor
        Task { await sessionHolder.session.setZoomFactor(preset.factor) }
    }

    private func shutter() {
        guard !isCapturing, let pair = currentPair else { return }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            do {
                let outcome = try await coordinator.captureAfter(for: pair, into: modelContext)
                CaptureHaptics.success()
                await MainActor.run {
                    if let next = outcome.nextPendingPair {
                        adopt(pair: next)
                    } else {
                        currentPair = nil
                        ghostImage = nil
                        dismiss()
                    }
                }
            } catch {
                // P9.4 will own user-visible error UI. For now fail silently so
                // the user can retry the shutter without us tearing down state.
            }
        }
    }
}

/// Header strip showing how many pairs are still pending vs completed.
/// Pure presentation; no interaction.
private struct AfterCameraTopBar: View {
    let pendingCount: Int
    let completedCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            badge(
                label: String(localized: "남은 페어"),
                value: pendingCount,
                tint: .yellow
            )
            badge(
                label: String(localized: "완료"),
                value: completedCount,
                tint: .green
            )
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }

    private func badge(label: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white)
            Text("\(value)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.5)))
    }
}

/// Shutter row reused in After flow. Same layout as Before, but with no
/// thumbnail well (the ghost overlay tells the user what they just shot).
private struct AfterCameraShutterRow: View {
    let isCapturing: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Color.clear.frame(width: 56, height: 56).padding(.leading, 24)
            Spacer()
            CaptureShutterButton(isCapturing: isCapturing, action: action)
                .opacity(enabled ? 1.0 : 0.4)
                .disabled(!enabled)
            Spacer()
            Color.clear.frame(width: 56, height: 56).padding(.trailing, 24)
        }
    }
}

/// Mirror of `BeforeCameraPreviewLayer`. We keep a separate type so the
/// Feature directory boundary in `audit-arch` stays clean (CameraAfter must
/// not import CameraBefore).
private struct AfterCameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession
    let onMakeView: (CameraPreviewView) -> Void

    func makeUIView(context _: Context) -> CameraPreviewView {
        let view = CameraPreviewView(session: session)
        Task { @MainActor in onMakeView(view) }
        return view
    }

    func updateUIView(_: CameraPreviewView, context _: Context) {}
}
