import SwiftUI

struct AfterCameraSettingsSheet: View {
    @Bindable var viewModel: AfterCameraViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "화면 보조")) {
                    Toggle(String(localized: "격자"), isOn: gridBinding)
                    Toggle(String(localized: "수평계"), isOn: levelBinding)
                    Toggle(String(localized: "야간모드"), isOn: nightModeBinding)
                }

                Section(String(localized: "플래시")) {
                    Picker(
                        String(localized: "플래시"),
                        selection: flashBinding
                    ) {
                        Text(String(localized: "끔")).tag(CameraFlashMode.off)
                        Text(String(localized: "켬")).tag(CameraFlashMode.on)
                        Text(String(localized: "자동")).tag(CameraFlashMode.auto)
                        Text(String(localized: "토치")).tag(CameraFlashMode.torch)
                    }
                    .pickerStyle(.segmented)
                }

                overlaySection
            }
            .navigationTitle(String(localized: "카메라 설정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showSettingsSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .accessibilityLabel(String(localized: "닫기"))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
    }

    private var overlaySection: some View {
        Section {
            Toggle(String(localized: "오버레이 표시"), isOn: overlayEnabledBinding)
            if viewModel.overlayEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(localized: "투명도"))
                        Spacer()
                        Text(percentLabel)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: alphaBinding,
                        in: GhostOverlayMath.alphaRange
                    )
                    if viewModel.alpha > 0.75 {
                        Label(
                            String(localized: "75% 이하 권장"),
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }
        } header: {
            Text(String(localized: "Before 오버레이"))
        }
    }

    private var percentLabel: String {
        let pct = Int((GhostOverlayMath.clamp(viewModel.alpha) * 100).rounded())
        return "\(pct)%"
    }

    private var gridBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isGridOn },
            set: { newValue in
                if newValue != viewModel.isGridOn { viewModel.toggleGrid() }
            }
        )
    }

    private var levelBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isLevelOn },
            set: { newValue in
                if newValue != viewModel.isLevelOn { viewModel.toggleLevel() }
            }
        )
    }

    private var nightModeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isNightModeOn },
            set: { newValue in
                if newValue != viewModel.isNightModeOn { viewModel.toggleNightMode() }
            }
        )
    }

    private var flashBinding: Binding<CameraFlashMode> {
        Binding(
            get: { viewModel.flashMode },
            set: { viewModel.setFlashMode($0) }
        )
    }

    private var overlayEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.overlayEnabled },
            set: { viewModel.overlayEnabled = $0 }
        )
    }

    private var alphaBinding: Binding<Double> {
        Binding(
            get: { GhostOverlayMath.clamp(viewModel.alpha) },
            set: { viewModel.alpha = GhostOverlayMath.clamp($0) }
        )
    }
}
