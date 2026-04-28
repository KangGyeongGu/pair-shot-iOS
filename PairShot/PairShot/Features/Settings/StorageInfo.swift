import SwiftData
import SwiftUI

struct StorageInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var env
    @Query private var pairs: [PhotoPair]

    @State private var isClearingCache: Bool = false
    @State private var lastResult: String?

    var body: some View {
        Form {
            usageSection
            cleanupSection
        }
        .navigationTitle(String(localized: "storage_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var usageSection: some View {
        Section {
            HStack {
                Label(String(localized: "storage_label_pair_count"), systemImage: "rectangle.on.rectangle")
                Spacer()
                Text("\(pairs.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } header: {
            Text(String(localized: "storage_section_storage"))
        } footer: {
            Text(String(localized: "storage_section_storage_hint"))
        }
    }

    private var cleanupSection: some View {
        Section {
            Button(role: .destructive) {
                Task { await clearCache() }
            } label: {
                HStack {
                    Label(String(localized: "storage_button_delete_orphans"), systemImage: "trash")
                    Spacer()
                    if isClearingCache {
                        ProgressView()
                    }
                }
            }
            .disabled(isClearingCache)

            if let lastResult {
                Text(lastResult)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "storage_section_cache_clean"))
        } footer: {
            Text(String(localized: "storage_section_cache_clean_hint"))
        }
    }

    @MainActor
    private func clearCache() async {
        guard !isClearingCache else { return }
        isClearingCache = true
        defer { isClearingCache = false }
        env.thumbnailCache.removeAll()
        env.hapticService.notify(.success)
        lastResult = String(localized: "storage_section_cache_clean")
    }
}

enum StorageInfoMath {
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = true
        return formatter.string(fromByteCount: max(0, bytes))
    }
}
