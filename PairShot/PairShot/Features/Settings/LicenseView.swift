import SwiftUI

struct LicenseView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                BannerAdSlot()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(LicenseEntries.all) { entry in
                Button {
                    openURL(entry.url)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(entry.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .navigationTitle(String(localized: "license_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LicenseView()
    }
}
