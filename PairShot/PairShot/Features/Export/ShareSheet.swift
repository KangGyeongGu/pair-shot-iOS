import Foundation
import Photos
import SwiftData
import SwiftUI
import UIKit

/// P7.3 — SwiftUI bridge for `UIActivityViewController`. Handed an array of
/// activity items (a ZIP `URL`, an array of `UIImage`s, etc.) and a single
/// completion callback; the view controller's chrome handles everything else.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: (() -> Void)?

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        // Audit-A — `completionWithItemsHandler`'s second parameter is
        // `completed: Bool` (false when the user dismisses without
        // picking a destination). Firing `onComplete` regardless caused
        // `ExportPicker` to dismiss on cancel, denying the user a
        // chance to pick a different export destination. Honour the
        // flag so cancels keep the picker on screen.
        controller.completionWithItemsHandler = { _, completed, _, _ in
            guard completed else { return }
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {
        // Activity items are immutable for the lifetime of one share sheet —
        // recreating the controller would dismiss it mid-flight.
    }
}

/// Picker shown via `.sheet(item:)` from the gallery's multi-select bar.
/// Three actions: ZIP for archive, save to Photos app, or share images directly.
/// `ExportMode` (Before/After/Combined/All) is shared across all three.
struct ExportPicker: View {
    let pairs: [PhotoPair]
    let storage: PhotoStorageService
    var photoLibrary: any PhotoLibraryExporting = PhotoLibraryExport()
    var zipExporter: ZipExporter = .init()

    @Environment(\.dismiss) private var dismiss
    @State private var mode: ExportMode = .all
    @State private var phase: ExportPickerPhase = .idle
    @State private var error: ExportPickerError?
    @State private var shareItems: ExportShareItems?
    @State private var toast: String?
    /// Audit-C — track the temporary ZIP URL so we can unlink it once the
    /// share sheet finishes (or the user dismisses the picker). Without
    /// this the `tmp/` directory accumulated one ZIP per export.
    @State private var pendingZipURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                modeSection
                actionsSection
            }
            .navigationTitle(String(localized: "내보내기"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "닫기")) { dismiss() }
                }
            }
            .overlay { busyOverlay }
            .alert(item: $error) { err in
                Alert(
                    title: Text(String(localized: "내보내기 실패")),
                    message: Text(err.message),
                    dismissButton: .default(Text("확인"))
                )
            }
            .sheet(item: $shareItems) { items in
                ShareSheet(activityItems: items.values) {
                    shareItems = nil
                    cleanupPendingZip()
                    dismiss()
                }
            }
            .overlay(alignment: .bottom) { toastView }
            .onDisappear { cleanupPendingZip() }
        }
    }

    /// Best-effort unlink of the temporary ZIP file produced by
    /// ``shareAsZip``. Audit-C: previously the file was written to
    /// `FileManager.default.temporaryDirectory` and never removed.
    private func cleanupPendingZip() {
        guard let url = pendingZipURL else { return }
        pendingZipURL = nil
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - subviews

    private var modeSection: some View {
        Section(String(localized: "포함할 사진")) {
            Picker(String(localized: "범위"), selection: $mode) {
                ForEach(ExportMode.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text("\(pairs.count)\(String(localized: "개 페어"))")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var actionsSection: some View {
        Section(String(localized: "작업")) {
            Button(action: shareAsZip) {
                Label(String(localized: "ZIP 으로 공유"), systemImage: "doc.zipper")
            }
            Button(action: saveToPhotoLibrary) {
                Label(String(localized: "사진 앱에 저장"), systemImage: "photo.on.rectangle.angled")
            }
            Button(action: shareAsImages) {
                Label(String(localized: "이미지로 공유"), systemImage: "square.and.arrow.up")
            }
        }
        .disabled(phase != .idle)
    }

    @ViewBuilder
    private var busyOverlay: some View {
        if phase != .idle {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView(phase.label)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 24)
                .task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    self.toast = nil
                }
        }
    }

    // MARK: - actions

    private func shareAsZip() {
        phase = .zipping
        let pairsCopy = pairs
        let modeCopy = mode
        let storageCopy = storage
        Task { @MainActor in
            defer { phase = .idle }
            do {
                let url = try await zipExporter.makeZip(
                    for: pairsCopy,
                    mode: modeCopy,
                    storage: storageCopy,
                    in: FileManager.default.temporaryDirectory
                )
                pendingZipURL = url
                shareItems = ExportShareItems(values: [url])
            } catch let err as ZipExporter.ExportError {
                error = ExportPickerError.from(zipError: err)
            } catch {
                self.error = ExportPickerError(message: String(localized: "ZIP 생성에 실패했습니다"))
            }
        }
    }

    private func saveToPhotoLibrary() {
        phase = .savingToLibrary
        let entries = pairs.flatMap { ExportSelection.relativePaths(for: $0, mode: mode) }
        let storageCopy = storage
        let exporter = photoLibrary
        Task { @MainActor in
            defer { phase = .idle }
            // Audit-C — drive `authorize()` once before the loop. The
            // previous implementation re-prompted PHKit on every saved
            // image, which produced a noisy queue of permission probes
            // when the user batch-saved a multi-pair selection.
            let status = await exporter.authorize()
            guard status == .authorized || status == .limited else {
                error = ExportPickerError(
                    message: String(localized: "사진 라이브러리 권한이 필요합니다")
                )
                return
            }
            var saved = 0
            for entry in entries {
                guard
                    let url = storageCopy.resolve(relativePath: entry.sourcePath),
                    let data = try? Data(contentsOf: url)
                else { continue }
                do {
                    try await exporter.saveImageData(data, type: .photo)
                    saved += 1
                } catch PhotoLibraryExportError.notAuthorized {
                    error = ExportPickerError(
                        message: String(localized: "사진 라이브러리 권한이 필요합니다")
                    )
                    return
                } catch {
                    self.error = ExportPickerError(
                        message: String(localized: "저장 중 오류가 발생했습니다")
                    )
                    return
                }
            }
            toast = "\(saved)\(String(localized: "장 저장됨"))"
            try? await Task.sleep(nanoseconds: 700_000_000)
            dismiss()
        }
    }

    private func shareAsImages() {
        phase = .preparingImages
        let entries = pairs.flatMap { ExportSelection.relativePaths(for: $0, mode: mode) }
        let storageCopy = storage
        Task { @MainActor in
            defer { phase = .idle }
            var images: [UIImage] = []
            for entry in entries {
                guard
                    let url = storageCopy.resolve(relativePath: entry.sourcePath),
                    let image = UIImage(contentsOfFile: url.path)
                else { continue }
                images.append(image)
            }
            guard !images.isEmpty else {
                error = ExportPickerError(message: String(localized: "공유할 이미지가 없습니다"))
                return
            }
            shareItems = ExportShareItems(values: images)
        }
    }
}
