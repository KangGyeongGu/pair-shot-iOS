import SwiftUI

struct CameraSettingsSheet: View {
    @Bindable var viewModel: BeforeCameraViewModel

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
}
