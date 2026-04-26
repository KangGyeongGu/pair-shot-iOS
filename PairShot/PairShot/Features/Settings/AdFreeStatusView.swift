import SwiftData
import SwiftUI

/// P8.5 — AdFree entitlement readout + coupon registration entry point
/// + active / past coupon ledger.
///
/// Sections (each conditionally visible):
/// 1. **현재 상태** — headline produced by
///    ``AdFreeStatusFormatter/headline(isAdFree:latestExpiration:now:)``.
/// 2. **쿠폰 등록** — sheet-presents ``CouponRegistrationView``; on
///    dismiss we re-`refresh()` defensively (the registration view also
///    refreshes on success — second call is idempotent).
/// 3. **활성 / 과거 쿠폰** — visible only when non-empty. Codes are
///    masked to the last 4 characters via
///    ``AdFreeStatusFormatter/maskCode(_:)``.
///
/// View stays ≤ 250 lines; formatter math lives in
/// ``AdFreeStatusFormatter`` so it's testable without driving SwiftUI.
struct AdFreeStatusView: View {
    @Environment(AdFreeStore.self) private var adFreeStore
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingRegistration = false

    var body: some View {
        Form {
            statusSection
            registrationSection
            activeCouponsSection
            pastCouponsSection
        }
        .navigationTitle(String(localized: "쿠폰·AdFree"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(
            isPresented: $isShowingRegistration,
            onDismiss: {
                // Defence in depth: the registration view already calls
                // refresh on success, but if the user dismisses mid-flow
                // the headline below should still pick up any persisted
                // change.
                adFreeStore.refresh()
            },
            content: {
                CouponRegistrationView()
            }
        )
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: adFreeStore.isAdFree ? "checkmark.seal.fill" : "lock.open.fill")
                    .foregroundStyle(adFreeStore.isAdFree ? .green : .secondary)
                    .frame(width: 24)
                Text(AdFreeStatusFormatter.headline(
                    isAdFree: adFreeStore.isAdFree,
                    latestExpiration: adFreeStore.currentExpiration,
                    now: .now
                ))
                .multilineTextAlignment(.leading)
            }
        } header: {
            Text(String(localized: "현재 상태"))
        } footer: {
            Text(String(localized: "광고 제거 상태와 만료일을 보여줍니다."))
        }
    }

    private var registrationSection: some View {
        Section {
            Button {
                isShowingRegistration = true
            } label: {
                Label(
                    String(localized: "쿠폰 코드 등록"),
                    systemImage: "ticket"
                )
            }
        } header: {
            Text(String(localized: "쿠폰 등록"))
        } footer: {
            Text(String(localized: "발급받은 쿠폰 코드를 입력하거나 QR 로 스캔합니다."))
        }
    }

    @ViewBuilder
    private var activeCouponsSection: some View {
        let active = adFreeStore.activeCoupons
        if !active.isEmpty {
            Section {
                ForEach(active) { coupon in
                    CouponLedgerRow(
                        coupon: coupon,
                        statusLabel: nil,
                        statusTint: .green
                    )
                }
            } header: {
                Text(String(localized: "활성 쿠폰"))
            }
        }
    }

    @ViewBuilder
    private var pastCouponsSection: some View {
        let past = adFreeStore.pastCoupons
        if !past.isEmpty {
            Section {
                ForEach(past) { coupon in
                    CouponLedgerRow(
                        coupon: coupon,
                        statusLabel: AdFreeStatusFormatter.pastStatusLabel(for: coupon),
                        statusTint: .secondary
                    )
                }
            } header: {
                Text(String(localized: "과거 쿠폰"))
            }
        }
    }
}

/// Pure helpers for the `AdFreeStatusView` text surfaces. Deterministic
/// and side-effect-free so formatting/clamping is unit-testable.
enum AdFreeStatusFormatter {
    /// ISO-style date stamp used in headline + ledger rows.
    static let dateFormat = "yyyy-MM-dd"

    /// Whole days between `now` and `expiration`. Negative clamps to 0.
    static func remainingDays(until expiration: Date, now: Date) -> Int {
        let calendar = Calendar.current
        let startOfNow = calendar.startOfDay(for: now)
        let startOfExpiration = calendar.startOfDay(for: expiration)
        let components = calendar.dateComponents([.day], from: startOfNow, to: startOfExpiration)
        return max(0, components.day ?? 0)
    }

    /// Headline for the "현재 상태" section. Returns the inactive
    /// variant when `isAdFree == false` *or* when `latestExpiration` is
    /// `nil` — both signal the same user-visible state.
    static func headline(isAdFree: Bool, latestExpiration: Date?, now: Date) -> String {
        guard isAdFree, let latestExpiration else {
            return String(localized: "광고 제거 비활성")
        }
        let days = remainingDays(until: latestExpiration, now: now)
        let formatted = formatDate(latestExpiration)
        let template = String(localized: "광고 제거 활성 · 만료까지 %d일 (%@)")
        return String(format: template, days, formatted)
    }

    /// Mask all but the last 4 characters of a coupon code (`****-WXYZ`).
    /// Strings ≤ 4 characters are returned unchanged; empty/whitespace
    /// collapses to `****`.
    static func maskCode(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "****" }
        let visibleCount = 4
        if trimmed.count <= visibleCount { return trimmed }
        return "****-\(trimmed.suffix(visibleCount))"
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    /// Status badge text for a row in the "과거 쿠폰" section.
    static func pastStatusLabel(for coupon: Coupon) -> String {
        switch coupon.status {
            case .revoked:
                String(localized: "취소")
            // `.active` here = past expiration but not yet rolled over.
            case .expired, .active:
                String(localized: "만료")
        }
    }
}

/// Single coupon row used in both the active and past sections. Rendered
/// here (vs. inlining in the section) so both sections share spacing /
/// accessibility wiring without copy-paste drift.
private struct CouponLedgerRow: View {
    let coupon: Coupon
    let statusLabel: String?
    let statusTint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(AdFreeStatusFormatter.maskCode(coupon.code))
                    .font(.body.monospaced())
                Spacer()
                if let statusLabel {
                    Text(statusLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusTint.opacity(0.15), in: Capsule())
                        .foregroundStyle(statusTint)
                }
            }
            HStack(spacing: 12) {
                Label {
                    Text(AdFreeStatusFormatter.formatDate(coupon.activatedAt))
                } icon: {
                    Image(systemName: "play.circle")
                }
                Label {
                    Text(AdFreeStatusFormatter.formatDate(coupon.expirationDate))
                } icon: {
                    Image(systemName: "hourglass")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AdFreeStatusViewPreviewWrapper: View {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Project.self,
        PhotoPair.self,
        Coupon.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        NavigationStack {
            AdFreeStatusView()
        }
        .modelContainer(container)
        .environment(AdFreeStore(context: container.mainContext))
    }
}

#Preview {
    AdFreeStatusViewPreviewWrapper()
}
