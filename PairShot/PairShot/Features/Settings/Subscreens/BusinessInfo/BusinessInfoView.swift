import SwiftUI

struct BusinessInfoView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            BannerAdSlot()

            Form {
                Section {
                    infoRow(
                        titleKey: "business_info_label_name",
                        valueKey: "business_info_value_name",
                    )
                    infoRow(
                        titleKey: "business_info_label_representative",
                        valueKey: "business_info_value_representative",
                    )
                    infoRow(
                        titleKey: "business_info_label_registration_number",
                        valueKey: "business_info_value_registration_number",
                    )
                    infoRow(
                        titleKey: "business_info_label_ecommerce_number",
                        valueKey: "business_info_value_ecommerce_number",
                    )
                } header: {
                    Text(String(localized: "business_info_section_business"))
                }

                Section {
                    infoRow(
                        titleKey: "business_info_label_address",
                        valueKey: "business_info_value_address",
                    )
                    linkRow(
                        titleKey: "business_info_label_email",
                        valueKey: "business_info_value_email",
                        url: URL(string: "mailto:rudrn0110@naver.com"),
                    )
                    linkRow(
                        titleKey: "business_info_label_phone",
                        valueKey: "business_info_value_phone",
                        url: URL(string: "tel:+821089576712"),
                    )
                } header: {
                    Text(String(localized: "business_info_section_contact"))
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(String(localized: "business_info_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(titleKey: String.LocalizationValue, valueKey: String.LocalizationValue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: titleKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(localized: valueKey))
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func linkRow(
        titleKey: String.LocalizationValue,
        valueKey: String.LocalizationValue,
        url: URL?,
    ) -> some View {
        Button {
            if let url { openURL(url) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: titleKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(localized: valueKey))
                    .font(.body)
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        BusinessInfoView()
    }
}
