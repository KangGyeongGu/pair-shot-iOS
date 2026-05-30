import Foundation
import Observation
import Photos
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class WatermarkSettingsViewModel {
    var settings: WatermarkSettings {
        didSet {
            if oldValue.logoImageRef != settings.logoImageRef
                || oldValue.pendingLegacyLogoData != settings.pendingLegacyLogoData
            {
                cachedLogoData = settings.loadLogoData(using: logoStore)
            }
        }
    }

    private(set) var cachedLogoData: Data?

    var hasLogo: Bool {
        settings.logoImageRef != nil || settings.pendingLegacyLogoData != nil
    }

    var logoPickerItem: PhotosPickerItem? {
        didSet {
            guard logoPickerItem != oldValue, logoPickerItem != nil else { return }
            Task { await loadSelectedLogo() }
        }
    }

    private let appSettingsRepo: AppSettingsRepository
    private let appSettings: AppSettings
    private let exportPresetStore: ExportPresetStore?
    private let logoStore: WatermarkLogoStore

    init(
        appSettingsRepo: AppSettingsRepository,
        appSettings: AppSettings,
        exportPresetStore: ExportPresetStore? = nil,
        logoStore: WatermarkLogoStore = WatermarkLogoStore(),
    ) {
        self.appSettingsRepo = appSettingsRepo
        self.appSettings = appSettings
        self.exportPresetStore = exportPresetStore
        self.logoStore = logoStore
        let snapshot = appSettingsRepo.load()
        let initial = snapshot.watermark ?? .default
        settings = initial
        cachedLogoData = initial.loadLogoData(using: logoStore)
    }

    func clearLogo() {
        if let oldRef = settings.logoImageRef {
            logoStore.delete(ref: oldRef)
        }
        settings.logoImageRef = nil
        settings.pendingLegacyLogoData = nil
        settings.logoFileName = nil
    }

    func saveSettings() async {
        appSettings.watermarkSettings = settings
        var snapshot = appSettingsRepo.load()
        snapshot.watermark = settings
        try? await appSettingsRepo.save(snapshot)
        exportPresetStore?.syncFromGlobal()
    }

    private func loadSelectedLogo() async {
        guard let item = logoPickerItem else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let normalized = normalizedPNG(from: data) ?? data
            let filename = await Self.fetchOriginalFilename(for: item)
            if let oldRef = settings.logoImageRef {
                logoStore.delete(ref: oldRef)
            }
            let newRef = try logoStore.save(normalized)
            settings.logoImageRef = newRef
            settings.pendingLegacyLogoData = nil
            settings.logoFileName = filename
        } catch {
            if let oldRef = settings.logoImageRef {
                logoStore.delete(ref: oldRef)
            }
            settings.logoImageRef = nil
            settings.pendingLegacyLogoData = nil
            settings.logoFileName = nil
        }
    }

    private func normalizedPNG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1024
        let originalSize = image.size
        let largest = max(originalSize.width, originalSize.height)
        guard largest > 0 else { return nil }
        let scale = largest > maxDimension ? maxDimension / largest : 1.0
        let targetSize = CGSize(
            width: floor(originalSize.width * scale),
            height: floor(originalSize.height * scale),
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.pngData()
    }

    private static func fetchOriginalFilename(for item: PhotosPickerItem) async -> String? {
        guard let identifier = item.itemIdentifier else { return nil }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return nil }
        return PHAssetResource.assetResources(for: asset).first?.originalFilename
    }
}
