import SwiftData
import SwiftUI

struct AdFreeStatusView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel: AdFreeStatusViewModel?
    @State private var isShowingRegistration = false

    var body: some View {
        ZStack {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "ad_free_status_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { ensureViewModel() }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeAdFreeStatusViewModel()
        }
    }

    private func content(for viewModel: AdFreeStatusViewModel) -> some View {
        Form {
            statusSection(viewModel: viewModel)
            registrationSection
            activeCouponsSection(viewModel: viewModel)
            pastCouponsSection(viewModel: viewModel)
        }
        .sheet(
            isPresented: $isShowingRegistration,
            onDismiss: { viewModel.refresh() },
            content: { CouponRegistrationView() }
        )
    }

    private func statusSection(viewModel: AdFreeStatusViewModel) -> some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isAdFree ? "checkmark.seal.fill" : "lock.open.fill")
                    .foregroundStyle(viewModel.isAdFree ? .green : .secondary)
                    .frame(width: 24)
                Text(viewModel.headline())
                    .multilineTextAlignment(.leading)
            }
        } header: {
            Text(String(localized: "ad_free_status_section_status"))
        } footer: {
            Text(String(localized: "ad_free_status_hint"))
        }
    }

    private var registrationSection: some View {
        Section {
            Button {
                isShowingRegistration = true
            } label: {
                Label(
                    String(localized: "coupon_dialog_register_code_title"),
                    systemImage: "ticket"
                )
            }
        } header: {
            Text(String(localized: "ad_free_register_section_title"))
        } footer: {
            Text(String(localized: "ad_free_register_intro"))
        }
    }

    @ViewBuilder
    private func activeCouponsSection(viewModel: AdFreeStatusViewModel) -> some View {
        let active = viewModel.activeCoupons
        if !active.isEmpty {
            Section {
                ForEach(active) { coupon in
                    CouponLedgerRow(
                        coupon: coupon,
                        statusLabel: nil,
                        statusTint: .green,
                        viewModel: viewModel
                    )
                }
            } header: {
                Text(String(localized: "coupon_section_active"))
            }
        }
    }

    @ViewBuilder
    private func pastCouponsSection(viewModel: AdFreeStatusViewModel) -> some View {
        let past = viewModel.pastCoupons
        if !past.isEmpty {
            Section {
                ForEach(past) { coupon in
                    CouponLedgerRow(
                        coupon: coupon,
                        statusLabel: viewModel.pastStatusLabel(for: coupon),
                        statusTint: .secondary,
                        viewModel: viewModel
                    )
                }
            } header: {
                Text(String(localized: "coupon_section_past"))
            }
        }
    }
}

enum AdFreeStatusFormatter {
    static let dateFormat = "yyyy-MM-dd"

    static func remainingDays(until expiration: Date, now: Date) -> Int {
        let calendar = Calendar.current
        let startOfNow = calendar.startOfDay(for: now)
        let startOfExpiration = calendar.startOfDay(for: expiration)
        let components = calendar.dateComponents([.day], from: startOfNow, to: startOfExpiration)
        return max(0, components.day ?? 0)
    }

    static func headline(isAdFree: Bool, latestExpiration: Date?, now: Date) -> String {
        guard isAdFree, let latestExpiration else {
            return String(localized: "coupon_status_inactive")
        }
        let days = remainingDays(until: latestExpiration, now: now)
        let formatted = formatDate(latestExpiration)
        let template = String(localized: "coupon_status_active_remaining_template")
        return String(format: template, days, formatted)
    }

    static func maskCode(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "****" }
        let visibleCount = 4
        if trimmed.count <= visibleCount { return trimmed }
        return "****-\(trimmed.suffix(visibleCount))"
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    static func pastStatusLabel(for coupon: Coupon) -> String {
        switch coupon.status {
            case .revoked:
                String(localized: "coupon_status_canceled")

            case .expired, .active:
                String(localized: "coupon_status_expired")
        }
    }
}

private struct CouponLedgerRow: View {
    let coupon: Coupon
    let statusLabel: String?
    let statusTint: Color
    let viewModel: AdFreeStatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(viewModel.maskedCode(for: coupon))
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
                    Text(viewModel.formattedDate(coupon.activatedAt))
                } icon: {
                    Image(systemName: "play.circle")
                }
                Label {
                    Text(viewModel.formattedDate(coupon.expirationDate))
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
