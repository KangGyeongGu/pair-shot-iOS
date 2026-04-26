import SwiftData
import SwiftUI

/// P8.4 — disk-usage readout + orphan-file cleanup.
///
/// Two sections:
/// - **저장 공간** — total bytes occupied by `Application Support/photos/`
///   plus the SwiftData `PhotoPair` count for context. Computed in
///   `.task` so the UI doesn't block on directory enumeration.
/// - **캐시 정리** — "고아 파일 삭제" runs
///   ``PhotoStorageService/deleteOrphanFiles(referencedRelativePaths:)``
///   against the union of every PhotoPair's before/after/combined paths.
///   Confirmed via alert because the operation is destructive (no
///   undo); on success a toast announces `(N개 · M MB 회수)`.
///
/// View kept ≤ 200 lines; orphan-set computation is delegated to the
/// pure helper ``StorageInfoMath`` so the calculation is unit-testable.
struct StorageInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var pairs: [PhotoPair]

    @State private var directorySizeBytes: Int64?
    @State private var isCalculating: Bool = false
    @State private var isPurging: Bool = false
    @State private var showPurgeConfirmation: Bool = false
    @State private var lastPurgeResult: String?
    @State private var loadError: String?

    private let storage: PhotoStorageService

    init(storage: PhotoStorageService = PhotoStorageService()) {
        self.storage = storage
    }

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

    // MARK: - Usage

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

    // MARK: - Cleanup

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

    // MARK: - Actions

    @MainActor
    private func refreshDirectorySize() async {
        isCalculating = true
        loadError = nil
        defer { isCalculating = false }
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
        let referenced = StorageInfoMath.referencedRelativePaths(in: pairs)
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try storage.deleteOrphanFiles(referencedRelativePaths: referenced)
            }.value
            lastPurgeResult = String(
                format: String(localized: "%d개 파일 삭제 · %@ 회수"),
                result.deletedCount,
                StorageInfoMath.formatBytes(result.freedBytes)
            )
            await refreshDirectorySize()
        } catch {
            lastPurgeResult = String(
                format: String(localized: "삭제 실패: %@"),
                error.localizedDescription
            )
        }
    }
}

/// Pure helpers for the P8.4 storage UI. Extracted so the orphan-set
/// computation and the bytes-to-string formatting are testable without
/// SwiftUI / SwiftData / disk.
enum StorageInfoMath {
    /// Unions the `beforePath`, `afterPath`, and `combinedPath` of every
    /// pair into a single relative-path set used by orphan detection.
    /// Empty paths are filtered out so a half-captured pair doesn't
    /// accidentally protect every file with an empty filename.
    static func referencedRelativePaths(in pairs: [PhotoPair]) -> Set<String> {
        var set: Set<String> = []
        for pair in pairs {
            insert(&set, pair.beforePath)
            insert(&set, pair.afterPath)
            insert(&set, pair.combinedPath)
        }
        return set
    }

    /// Apple's standard byte formatter wired with the `.file` style
    /// (auto B / KB / MB / GB) — matches the iOS Settings → "사용 가능"
    /// readout users are familiar with. `0` collapses to "0 KB" rather
    /// than "Zero bytes" via `zeroPadsFractionDigits = false`.
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

private struct StorageInfoViewPreviewWrapper: View {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Project.self,
        PhotoPair.self,
        Coupon.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        NavigationStack {
            StorageInfoView()
        }
        .modelContainer(container)
    }
}

#Preview {
    StorageInfoViewPreviewWrapper()
}
