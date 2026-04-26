import SwiftData
import SwiftUI

/// P8.1 — top-level settings screen, reachable from `ArchiveView`'s
/// toolbar. Hosts the five sections from the Android v1.1.3 reference:
///
/// 1. **촬영** — JPEG quality + filename prefix (P8.2 — wired today).
/// 2. **합성** — overlay default alpha + composite layout (P8.3).
/// 3. **내보내기** — export defaults (P8.x — TBD; the share sheet
///    currently exposes its own picker).
/// 4. **쿠폰·AdFree** — current entitlement + redeem button (P8.5).
/// 5. **정보** — version / build / privacy.
///
/// Sections 2/3/4 render disabled placeholder rows in this phase so the
/// shape of the UI is locked in but no behaviour changes until their
/// owning phases land. The 정보 section is fully populated.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        NavigationStack {
            List {
                captureSection
                compositionSection
                exportSection
                couponSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "설정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "완료")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var captureSection: some View {
        Section {
            NavigationLink {
                CaptureSettingsView()
            } label: {
                SettingsRow(
                    title: String(localized: "촬영"),
                    subtitle: captureSummary,
                    systemImage: "camera"
                )
            }
        } header: {
            Text(String(localized: "촬영"))
        }
    }

    private var compositionSection: some View {
        Section {
            DisabledSettingsRow(
                title: String(localized: "합성"),
                subtitle: String(localized: "곧 추가됩니다"),
                systemImage: "square.on.square"
            )
        } header: {
            Text(String(localized: "합성"))
        } footer: {
            Text(String(localized: "Overlay 기본 투명도와 합성 레이아웃 (다음 업데이트)"))
        }
    }

    private var exportSection: some View {
        Section {
            DisabledSettingsRow(
                title: String(localized: "내보내기"),
                subtitle: String(localized: "공유 시점에 옵션을 선택합니다"),
                systemImage: "square.and.arrow.up"
            )
        } header: {
            Text(String(localized: "내보내기"))
        }
    }

    private var couponSection: some View {
        Section {
            DisabledSettingsRow(
                title: String(localized: "쿠폰 / 광고 제거"),
                subtitle: String(localized: "곧 추가됩니다"),
                systemImage: "ticket"
            )
        } header: {
            Text(String(localized: "쿠폰·AdFree"))
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Label(String(localized: "버전"), systemImage: "info.circle")
                Spacer()
                Text(Self.appVersionLabel)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Label(String(localized: "빌드"), systemImage: "hammer")
                Spacer()
                Text(Self.buildNumberLabel)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } header: {
            Text(String(localized: "정보"))
        }
    }

    // MARK: - Helpers

    private var captureSummary: String {
        let quality = CaptureQualityPreset.nearest(to: appSettings.jpegQuality)
        let prefix = FileNamePrefixValidator.sanitize(appSettings.fileNamePrefix)
        if prefix.isEmpty {
            return String(format: String(localized: "품질 %@"), quality.label)
        }
        return String(format: String(localized: "품질 %@ · prefix \"%@\""), quality.label, prefix)
    }

    static var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return version ?? "—"
    }

    static var buildNumberLabel: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return build ?? "—"
    }
}

/// Row used by the active 촬영 section. Mirrors `Label` but with a
/// trailing subtitle, which `Label` itself doesn't expose cleanly.
private struct SettingsRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Greyed-out row used for sections whose owning phase hasn't shipped.
/// Marked with `.disabled(true)` so VoiceOver still announces it but
/// taps don't push a placeholder destination.
private struct DisabledSettingsRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsViewPreviewWrapper: View {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Project.self,
        PhotoPair.self,
        Coupon.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        SettingsView()
            .modelContainer(container)
            .environment(AppSettings(defaults: UserDefaults(suiteName: "preview") ?? .standard))
    }
}

#Preview {
    SettingsViewPreviewWrapper()
}
