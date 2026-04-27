import SwiftUI

struct AfterCameraSettingsSheet: View {
    @Bindable var viewModel: AfterCameraViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "camera_settings_section_screen_aid")) {
                    Toggle(String(localized: "camera_settings_grid"), isOn: gridBinding)
                    Toggle(String(localized: "camera_settings_level"), isOn: levelBinding)
                    Toggle(String(localized: "camera_settings_night_mode"), isOn: nightModeBinding)
                }

                Section(String(localized: "camera_settings_section_flash")) {
                    Picker(
                        String(localized: "camera_settings_section_flash"),
                        selection: flashBinding
                    ) {
                        Text(String(localized: "camera_flash_off")).tag(CameraFlashMode.off)
                        Text(String(localized: "camera_flash_on")).tag(CameraFlashMode.on)
                        Text(String(localized: "camera_flash_auto")).tag(CameraFlashMode.auto)
                        Text(String(localized: "camera_flash_torch")).tag(CameraFlashMode.torch)
                    }
                    .pickerStyle(.segmented)
                }

                overlaySection
            }
            .navigationTitle(String(localized: "camera_desc_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showSettingsSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .accessibilityLabel(String(localized: "common_button_close"))
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
            Toggle(String(localized: "camera_settings_overlay_show"), isOn: overlayEnabledBinding)
            if viewModel.overlayEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(localized: "camera_settings_overlay_opacity"))
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
                            String(localized: "camera_settings_overlay_opacity_hint"),
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }
        } header: {
            Text(String(localized: "camera_settings_section_overlay"))
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
