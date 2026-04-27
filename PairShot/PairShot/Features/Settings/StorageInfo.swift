import SwiftData
import SwiftUI

struct StorageInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var env
    @Query private var pairs: [PhotoPair]

    @State private var directorySizeBytes: Int64?
    @State private var isCalculating: Bool = false
    @State private var isPurging: Bool = false
    @State private var showPurgeConfirmation: Bool = false
    @State private var lastPurgeResult: String?
    @State private var loadError: String?

    var body: some View {
        Form {
            usageSection
            cleanupSection
        }
        .navigationTitle(String(localized: "storage_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshDirectorySize()
        }
        .alert(
            String(localized: "storage_dialog_orphan_delete_title"),
            isPresented: $showPurgeConfirmation
        ) {
            Button(String(localized: "common_button_delete"), role: .destructive) {
                Task { await runOrphanPurge() }
            }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "storage_dialog_orphan_delete_message"))
        }
    }

    private var usageSection: some View {
        Section {
            HStack {
                Label(String(localized: "storage_label_photo_folder_size"), systemImage: "internaldrive")
                Spacer()
                if let directorySizeBytes {
                    Text(StorageInfoMath.formatBytes(directorySizeBytes))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else if isCalculating {
                    ProgressView()
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            HStack {
                Label(String(localized: "storage_label_pair_count"), systemImage: "rectangle.on.rectangle")
                Spacer()
                Text("\(pairs.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.red)
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
                showPurgeConfirmation = true
            } label: {
                HStack {
                    Label(String(localized: "storage_button_delete_orphans"), systemImage: "trash")
                    Spacer()
                    if isPurging {
                        ProgressView()
                    }
                }
            }
            .disabled(isPurging)

            if let lastPurgeResult {
                Text(lastPurgeResult)
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
    private func refreshDirectorySize() async {
        isCalculating = true
        loadError = nil
        defer { isCalculating = false }
        let storage = env.photoStorageService
        do {
            let bytes = try await Task.detached(priority: .userInitiated) {
                try storage.directorySize()
            }.value
            directorySizeBytes = bytes
        } catch {
            loadError = String(
                format: String(localized: "storage_size_calculation_failed_template"),
                error.localizedDescription
            )
        }
    }

    @MainActor
    private func runOrphanPurge() async {
        guard !isPurging else { return }
        isPurging = true
        defer { isPurging = false }
        let referenced = StorageInfoMath.referencedFileNames(in: pairs)
        let storage = env.photoStorageService
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try storage.deleteOrphanFiles(referencedFileNames: referenced)
            }.value
            lastPurgeResult = String(
                format: String(localized: "storage_orphan_delete_summary_template"),
                result.deletedCount,
                StorageInfoMath.formatBytes(result.freedBytes)
            )
            HapticService.shared.notify(.success)
            await refreshDirectorySize()
        } catch {
            lastPurgeResult = String(
                format: String(localized: "storage_delete_failed_template"),
                error.localizedDescription
            )
        }
    }
}

enum StorageInfoMath {
    static func referencedFileNames(in pairs: [PhotoPair]) -> Set<String> {
        var set: Set<String> = []
        for pair in pairs {
            insert(&set, pair.beforeFileName)
            insert(&set, pair.afterFileName)
            insert(&set, pair.combinedFileName)
        }
        return set
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = true
        return formatter.string(fromByteCount: max(0, bytes))
    }

    private static func insert(_ set: inout Set<String>, _ raw: String?) {
        guard let raw, !raw.isEmpty else { return }
        set.insert(raw)
    }
}
