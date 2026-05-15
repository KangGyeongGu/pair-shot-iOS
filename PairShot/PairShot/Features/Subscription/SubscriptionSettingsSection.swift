import StoreKit
import SwiftUI

struct SubscriptionSettingsSection: View {
    @Environment(Entitlement.self) private var entitlement
    @Environment(AppEnvironment.self) private var env
    @Binding var showPaywall: Bool

    var body: some View {
        Section {
            membershipRow
            if !entitlement.isPaidPro {
                upgradeButton
            }
            manageButton
            restoreButton
            promotionCodeRow
        } header: {
            Text(String(localized: "settings_subscription_title"))
        } footer: {
            if entitlement.hasCouponAdFree, !entitlement.isPaidPro {
                Text(adFreeStatusFooterText)
            }
        }
    }

    private var membershipRow: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(
                icon: SettingsRowIcon(
                    systemImage: entitlement.isPaidPro ? "checkmark.seal.fill" : "person.crop.circle",
                    color: entitlement.isPaidPro ? .yellow : .gray
                )
            )
            Text(String(localized: "settings_subscription_membership"))
                .foregroundStyle(.primary)
            Spacer()
            Text(membershipStatusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(entitlement.isPaidPro ? Color.accentColor : .secondary)
        }
        .contentShape(Rectangle())
    }

    private var membershipStatusText: String {
        entitlement.isPaidPro
            ? String(localized: "settings_subscription_status_pro")
            : String(localized: "settings_subscription_status_free")
    }

    private var promotionCodeRow: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(
                icon: SettingsRowIcon(systemImage: "tag.fill", color: .pink)
            )
            Text(String(localized: "settings_promotion_code_redeem"))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            CouponRedemptionLink.open(
                config: env.couponApiConfig,
                deviceHashProvider: env.deviceHashProvider
            )
        }
    }

    private var adFreeStatusFooterText: String {
        let activeBase = String(localized: "settings_promotion_code_status_active")
        let adFreeStore = entitlement.adFreeStore
        guard let remaining = adFreeStore.remainingDays else {
            return String(localized: "settings_promotion_code_status_permanent")
        }
        let remainingText = String(
            format: String(localized: "settings_promotion_code_status_remaining_days"),
            remaining
        )
        if adFreeStore.couponCount >= 2 {
            let couponsText = String(
                format: String(localized: "settings_promotion_code_status_coupons_template"),
                adFreeStore.couponCount
            )
            return "\(activeBase) (\(couponsText)) — \(remainingText)"
        }
        return "\(activeBase) — \(remainingText)"
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
        await entitlement.subscriptionStore.refresh()
    }
}
