import SwiftUI

struct SettingsGeneralSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            SettingsValueRow(
                title: String(localized: "언어"),
                value: viewModel.languageDisplayText
            )
            .onTapGesture { viewModel.showLanguagePicker = true }

            SettingsValueRow(
                title: String(localized: "테마"),
                value: viewModel.themeDisplayText
            )
            .onTapGesture { viewModel.showThemePicker = true }
        } header: {
            Text(String(localized: "일반"))
        }
    }
}

struct SettingsCaptureFileSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            NavigationLink {
                CaptureSettingsView()
            } label: {
                SettingsRow(
                    title: String(localized: "촬영 및 파일"),
                    subtitle: viewModel.captureSummary,
                    systemImage: "camera"
                )
            }
            NavigationLink {
                CompositionSettingsView()
            } label: {
                SettingsRow(
                    title: String(localized: "오버레이"),
                    subtitle: viewModel.compositionSummary,
                    systemImage: "circle.lefthalf.filled"
                )
            }
        } header: {
            Text(String(localized: "촬영 및 파일"))
        } footer: {
            Text(String(localized: "이미지 품질·파일명 접두어·overlay 기본값"))
        }
    }
}

struct SettingsWatermarkSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            HighlightableCard(isHighlighted: viewModel.shouldPulseWatermark) {
                Toggle(isOn: Binding(
                    get: { viewModel.watermarkEnabled },
                    set: { viewModel.watermarkEnabled = $0 }
                )) {
                    Label(
                        String(localized: "워터마크 사용"),
                        systemImage: "signature"
                    )
                }
            }
            if viewModel.watermarkEnabled {
                NavigationLink(value: Route.watermarkSettings) {
                    HStack {
                        Text(String(localized: "세부설정"))
                        Spacer()
                        if viewModel.watermarkSettingsBlank {
                            Text(String(localized: "필수"))
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        } header: {
            Text(String(localized: "워터마크"))
        }
    }
}

struct SettingsCombineSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            HighlightableCard(isHighlighted: viewModel.shouldPulseCombine) {
                NavigationLink(value: Route.combineSettings) {
                    Label(
                        String(localized: "세부설정"),
                        systemImage: "square.on.square"
                    )
                }
            }
        } header: {
            Text(String(localized: "합성"))
        }
    }
}

struct SettingsCouponSection: View {
    let adFreeStore: AdFreeStore

    var body: some View {
        Section {
            NavigationLink {
                AdFreeStatusView()
            } label: {
                SettingsRow(
                    title: String(localized: "쿠폰 / 광고 제거"),
                    subtitle: couponSummary,
                    systemImage: "ticket"
                )
            }
        } header: {
            Text(String(localized: "쿠폰"))
        }
    }

    private var couponSummary: String {
        adFreeStore.isAdFree
            ? String(localized: "광고 제거 활성")
            : String(localized: "비활성")
    }
}

struct SettingsStorageInfoSection: View {
    @Bindable var viewModel: SettingsViewModel
    let openURL: OpenURLAction

    var body: some View {
        Section {
            SettingsValueRow(
                title: String(localized: "사진 저장공간"),
                value: viewModel.photoStorageText
            )
            SettingsValueRow(
                title: String(localized: "캐시"),
                value: viewModel.cacheText
            )
            .onTapGesture { viewModel.showCacheClearConfirm = true }
            SettingsValueRow(
                title: String(localized: "앱 버전"),
                value: viewModel.appVersionText
            )
            NavigationLink(value: Route.license) {
                Text(String(localized: "라이선스"))
            }
            HStack {
                Text(String(localized: "개인정보처리방침"))
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { openURL(SettingsExternalLinks.privacyPolicy) }
        } header: {
            Text(String(localized: "저장공간 및 앱정보"))
        }
    }
}

enum SettingsExternalLinks {
    static let privacyPolicy: URL = .init(string: "https://kanggyeonggu.github.io/pairshot/privacy.html")
        ?? URL(string: "https://example.com/privacy")!
}
