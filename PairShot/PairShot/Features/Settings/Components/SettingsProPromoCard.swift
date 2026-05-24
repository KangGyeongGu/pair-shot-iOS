import SwiftUI
import UIKit

struct SettingsProPromoCard: View {
    let onLearnMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(String(localized: "settings_pro_promo_title"))
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 10) {
                promoFeatureRow(text: String(localized: "settings_pro_promo_feature_pairs"))
                promoFeatureRow(text: String(localized: "settings_pro_promo_feature_no_ads"))
                promoFeatureRow(text: String(localized: "settings_pro_promo_feature_full_access"))
            }

            Button(action: onLearnMore) {
                Text(String(localized: "settings_pro_promo_cta"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground)),
        )
    }

    private func promoFeatureRow(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tint)
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
