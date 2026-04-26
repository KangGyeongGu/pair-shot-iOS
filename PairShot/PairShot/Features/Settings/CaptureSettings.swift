import SwiftUI

struct CaptureSettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    @State private var prefixDraft: String = ""

    var body: some View {
        Form {
            qualitySection
            prefixSection
        }
        .navigationTitle(String(localized: "촬영"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prefixDraft = appSettings.fileNamePrefix
        }
    }

    private var qualitySection: some View {
        Section {
            Picker(String(localized: "JPEG 품질"), selection: qualityBinding) {
                ForEach(CaptureQualityPreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(String(localized: "JPEG 품질"))
        } footer: {
            Text(qualityFooter)
        }
    }

    private var qualityBinding: Binding<CaptureQualityPreset> {
        Binding(
            get: { CaptureQualityPreset.nearest(to: appSettings.jpegQuality) },
            set: { appSettings.jpegQuality = $0.rawValue }
        )
    }

    private var qualityFooter: String {
        let preset = CaptureQualityPreset.nearest(to: appSettings.jpegQuality)
        let percent = Int((preset.rawValue * 100).rounded())
        return String(
            format: String(localized: "현재 %@ (%d%%) — 합성 사진 저장 시 적용"),
            preset.label,
            percent
        )
    }

    private var prefixSection: some View {
        Section {
            TextField(
                String(localized: "예: site-A_"),
                text: $prefixDraft
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .onChange(of: prefixDraft) { _, newValue in
                let cleaned = FileNamePrefixValidator.sanitize(newValue)
                if cleaned != newValue {
                    prefixDraft = cleaned
                }
                appSettings.fileNamePrefix = cleaned
            }
        } header: {
            Text(String(localized: "파일명 prefix"))
        } footer: {
            Text(prefixFooter)
        }
    }

    private var prefixFooter: String {
        let safe = FileNamePrefixValidator.sanitize(prefixDraft)
        if safe.isEmpty {
            return String(
                localized:
                "비워두면 \"<UUID>.jpg\" 로 저장됩니다. 슬래시·콜론 등 파일시스템 금지 문자는 자동으로 제거됩니다."
            )
        }
        return String(
            format: String(localized: "예: %@<UUID>.jpg (최대 %d자)"),
            safe,
            FileNamePrefixValidator.maxLength
        )
    }
}

private struct CaptureSettingsViewPreviewWrapper: View {
    var body: some View {
        NavigationStack {
            CaptureSettingsView()
        }
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview-capture") ?? .standard))
    }
}

#Preview {
    CaptureSettingsViewPreviewWrapper()
}
