import StoreKit
import SwiftUI

struct SubscriptionSettingsSection: View {
    @Environment(Membership.self) private var membership
    @Environment(AppEnvironment.self) private var env
    @Binding var showPaywall: Bool

    var body: some View {
        Section {
            membershipRow
            if !membership.proIsActive {
                upgradeButton
            }
            manageButton
            restoreButton
        } header: {
            Text(String(localized: "settings_subscription_title"))
        } footer: {
            promotionCodeFooterLink
        }
    }

    private var membershipRow: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(
                icon: SettingsRowIcon(
                    systemImage: membership.proIsActive ? "checkmark.seal.fill" : "person.crop.circle",
                    color: membership.proIsActive ? .yellow : .gray
                )
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "settings_subscription_membership"))
                    .foregroundStyle(.primary)
                if let subline = membershipSublineText {
                    Text(subline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(membershipStatusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(membership.proIsActive ? Color.accentColor : .secondary)
        }
        .contentShape(Rectangle())
    }

    private var membershipStatusText: String {
        membership.proIsActive
            ? String(localized: "settings_subscription_status_pro")
            : String(localized: "settings_subscription_status_free")
    }

    private var membershipSublineText: String? {
        if membership.proIsActive {
            return Self.expirationSublineText(date: membership.proExpiresAt)
        }
        if membership.adFreeIsActive {
            let active = String(localized: "settings_subscription_status_ad_free_active")
            if let date = membership.adFreeExpiresAt {
                return "\(active) — \(Self.formattedExpirationText(date: date))"
            }
            return "\(active) — \(String(localized: "settings_subscription_membership_permanent"))"
        }
        return nil
    }

    private var promotionCodeFooterLink: some View {
        HStack(spacing: 0) {
            Spacer()
            Button {
                PromotionRedemptionLink.open(
                    config: env.couponApiConfig,
                    deviceHashProvider: env.deviceHashProvider
                )
            } label: {
                HStack(spacing: 4) {
                    Text(String(localized: "settings_promotion_code_redeem"))
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.footnote)
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var upgradeButton: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                SettingsIconBadge(
                    icon: SettingsRowIcon(systemImage: "crown.fill", color: .yellow)
                )
                Text(String(localized: "settings_subscription_upgrade"))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var manageButton: some View {
        Button {
            Task { await openManageSubscriptions() }
        } label: {
            HStack(spacing: 12) {
                SettingsIconBadge(
                    icon: SettingsRowIcon(systemImage: "gearshape.fill", color: .blue)
                )
                Text(String(localized: "settings_subscription_manage"))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var restoreButton: some View {
        Button {
            Task { await restorePurchases() }
        } label: {
            HStack(spacing: 12) {
                SettingsIconBadge(
                    icon: SettingsRowIcon(systemImage: "arrow.clockwise", color: .blue)
                )
                Text(String(localized: "settings_subscription_restore"))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openManageSubscriptions() async {
        guard let scene = SubscriptionSceneResolver.resolve() else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }

    private func restorePurchases() async {
        try? await AppStore.sync()
        await membership.subscriptionStore.refresh()
    }

    private static func expirationSublineText(date: Date?) -> String {
        guard let date else {
            return String(localized: "settings_subscription_membership_permanent")
        }
        return formattedExpirationText(date: date)
    }

    private static func formattedExpirationText(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return String(
            format: String(localized: "settings_subscription_membership_expires_template"),
            formatter.string(from: date)
        )
    }
}
