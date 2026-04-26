import SwiftData
import SwiftUI

/// P8.1 — top-level settings screen, reachable from `ArchiveView`'s
/// toolbar. Hosts the five sections from the Android v1.1.3 reference:
///
/// 1. **촬영** — JPEG quality + filename prefix (P8.2).
/// 2. **합성** — overlay default alpha + composite layout (P8.3).
/// 3. **저장 공간** — disk usage + cache cleanup (P8.4).
/// 4. **내보내기** — export defaults (the share sheet exposes its own
///    picker; this row stays informational).
/// 5. **쿠폰·AdFree** — current entitlement + redeem button (P8.5).
/// 6. **정보** — version / build / privacy.
///
/// Row helpers (`SettingsRow`, `DisabledSettingsRow`) and the summary
/// string derivations live in `SettingsView+Helpers.swift` so this file
/// stays under the 250-line cap (P8b reviewer advisory).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        NavigationStack {
            List {
                captureSection
                compositionSection
                storageSection
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
                    subtitle: appSettings.captureSummary,
                    systemImage: "camera"
                )
            }
        } header: {
            Text(String(localized: "촬영"))
        }
    }

    private var compositionSection: some View {
        Section {
            NavigationLink {
                // Audit-B (P6.7 wire-up) — wrap the destination in
                // ``CompositionSettingsGate`` so non-AdFree users must
                // watch a rewarded ad before reaching the screen. The
                // gate itself short-circuits to the child view when
                // AdFree is active or the unlock has already been
                // granted this session, so the AdFree path stays
                // identical.
                CompositionSettingsGate {
                    CompositionSettingsView()
                }
            } label: {
                SettingsRow(
                    title: String(localized: "합성"),
                    subtitle: appSettings.compositionSummary,
                    systemImage: "square.on.square"
                )
            }
        } header: {
            Text(String(localized: "합성"))
        } footer: {
            Text(String(localized: "반투명 overlay 기본값·합성 레이아웃·워터마크"))
        }
    }

    private var storageSection: some View {
        Section {
            NavigationLink {
                StorageInfoView()
            } label: {
                SettingsRow(
                    title: String(localized: "저장 공간"),
                    subtitle: String(localized: "사진 폴더 크기 · 캐시 정리"),
                    systemImage: "internaldrive"
                )
            }
        } header: {
            Text(String(localized: "저장 공간"))
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
            NavigationLink {
                AdFreeStatusView()
            } label: {
                SettingsRow(
                    title: String(localized: "쿠폰 / 광고 제거"),
                    subtitle: String(localized: "쿠폰 등록·활성/과거 쿠폰 보기"),
                    systemImage: "ticket"
                )
            }
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

    // MARK: - Bundle metadata

    static var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return version ?? "—"
    }

    static var buildNumberLabel: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return build ?? "—"
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
            .environment(AdFreeStore(context: container.mainContext))
            .environment(RewardedAdManager())
            .environment(\.fullscreenAdCoordinator, FullscreenAdCoordinator())
    }
}

#Preview {
    SettingsViewPreviewWrapper()
}
