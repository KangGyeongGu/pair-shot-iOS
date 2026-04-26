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
        .navigationTitle(String(localized: "저장 공간"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshDirectorySize()
        }
        .alert(
            String(localized: "고아 파일을 삭제할까요?"),
            isPresented: $showPurgeConfirmation
        ) {
            Button(String(localized: "삭제"), role: .destructive) {
                Task { await runOrphanPurge() }
            }
            Button(String(localized: "취소"), role: .cancel) {}
        } message: {
            Text(String(
                localized: "프로젝트에서 참조하지 않는 사진 파일만 삭제합니다. 이 작업은 되돌릴 수 없습니다."
            ))
        }
    }

    private var usageSection: some View {
        Section {
            HStack {
                Label(String(localized: "사진 폴더 크기"), systemImage: "internaldrive")
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
                Label(String(localized: "사진 페어 수"), systemImage: "rectangle.on.rectangle")
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
            Text(String(localized: "저장 공간"))
        } footer: {
            Text(String(
                localized: "사진 파일은 앱 전용 폴더에 저장됩니다. 앱을 삭제하면 함께 사라집니다."
            ))
        }
    }

    private var cleanupSection: some View {
        Section {
            Button(role: .destructive) {
                showPurgeConfirmation = true
            } label: {
                HStack {
                    Label(String(localized: "고아 파일 삭제"), systemImage: "trash")
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
            Text(String(localized: "캐시 정리"))
        } footer: {
            Text(String(
                localized: "프로젝트가 참조하지 않는 디스크 상의 사진 파일을 정리합니다."
            ))
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
                format: String(localized: "크기를 계산할 수 없습니다: %@"),
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
                format: String(localized: "%d개 파일 삭제 · %@ 회수"),
                result.deletedCount,
                StorageInfoMath.formatBytes(result.freedBytes)
            )
            HapticService.shared.notify(.success)
            await refreshDirectorySize()
        } catch {
            lastPurgeResult = String(
                format: String(localized: "삭제 실패: %@"),
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
