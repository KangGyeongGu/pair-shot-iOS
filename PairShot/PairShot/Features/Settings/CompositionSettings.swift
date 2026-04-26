import SwiftUI

/// P8.3 — composition-related defaults exposed in the settings UI.
///
/// Three knobs:
/// - **반투명 overlay** (`appSettings.defaultOverlayAlpha`) — alpha used
///   when the After camera adopts a fresh `PhotoPair`. Slider over the
///   full 0.0~1.0 range so the user can dial the field-friendly opacity
///   they prefer; the After view re-clamps on read for safety.
/// - **합성 레이아웃** (`appSettings.defaultCompositeLayout`) — chosen
///   first in `ComparisonView`'s composite menu. Stored as the enum's
///   raw `String`; ``CompositionDefaults/layout(forRawValue:)`` handles
///   migration / corruption.
/// - **워터마크** (`appSettings.watermarkEnabled`) — mirrors the legacy
///   `WatermarkOverlay.userDefaultsKey` so `CompositeRenderer` reads
///   through `WatermarkOverlay.isEnabled` without changes.
///
/// View kept ≤ 200 lines; the slider, picker and toggle each render as
/// their own `Section` so adding a new knob later is mechanical.
struct CompositionSettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        Form {
            overlayAlphaSection
            layoutSection
            watermarkSection
        }
        .navigationTitle(String(localized: "합성"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Overlay alpha

    private var overlayAlphaSection: some View {
        Section {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.tint)
                    Slider(
                        value: alphaBinding,
                        in: CompositionDefaults.alphaRange
                    )
                    Text(percentLabel(appSettings.defaultOverlayAlpha))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
            }
        } header: {
            Text(String(localized: "반투명 overlay"))
        } footer: {
            Text(String(
                localized: "After 카메라 진입 시 시작값으로 사용됩니다. 화면에서 더 미세하게 조정할 수 있습니다."
            ))
        }
    }

    private var alphaBinding: Binding<Double> {
        Binding(
            get: { CompositionDefaults.clampAlpha(appSettings.defaultOverlayAlpha) },
            set: { appSettings.defaultOverlayAlpha = CompositionDefaults.clampAlpha($0) }
        )
    }

    private func percentLabel(_ value: Double) -> String {
        let pct = Int((CompositionDefaults.clampAlpha(value) * 100).rounded())
        return "\(pct)%"
    }

    // MARK: - Composite layout

    private var layoutSection: some View {
        Section {
            Picker(String(localized: "합성 레이아웃"), selection: layoutBinding) {
                ForEach(CompositeLayout.allCases) { layout in
                    Label(layout.label, systemImage: layout.systemImage)
                        .tag(layout)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(String(localized: "합성 레이아웃"))
        } footer: {
            Text(layoutFooter)
        }
    }

    private var layoutBinding: Binding<CompositeLayout> {
        Binding(
            get: { appSettings.defaultCompositeLayout },
            set: { appSettings.defaultCompositeLayout = $0 }
        )
    }

    private var layoutFooter: String {
        switch appSettings.defaultCompositeLayout {
            case .horizontal:
                String(localized: "Before 왼쪽, After 오른쪽으로 이어 붙입니다.")

            case .vertical:
                String(localized: "Before 위, After 아래로 이어 붙입니다.")
        }
    }

    // MARK: - Watermark

    private var watermarkSection: some View {
        Section {
            Toggle(isOn: watermarkBinding) {
                Label(
                    String(localized: "워터마크 표시"),
                    systemImage: "signature"
                )
            }
        } header: {
            Text(String(localized: "워터마크"))
        } footer: {
            Text(String(
                localized: "켜면 합성 사진 우측 하단에 앱 이름과 촬영 시각이 표시됩니다."
            ))
        }
    }

    private var watermarkBinding: Binding<Bool> {
        Binding(
            get: { appSettings.watermarkEnabled },
            set: { appSettings.watermarkEnabled = $0 }
        )
    }
}

private struct CompositionSettingsViewPreviewWrapper: View {
    var body: some View {
        NavigationStack {
            CompositionSettingsView()
        }
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview-composition") ?? .standard))
    }
}

#Preview {
    CompositionSettingsViewPreviewWrapper()
}
