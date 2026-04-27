import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class WatermarkSettingsViewModel {
    var settings: WatermarkSettings
    var logoPickerItem: PhotosPickerItem? {
        didSet {
            guard logoPickerItem != oldValue, logoPickerItem != nil else { return }
            Task { await loadSelectedLogo() }
        }
    }

    private let appSettingsRepo: AppSettingsRepository

    init(appSettingsRepo: AppSettingsRepository) {
        self.appSettingsRepo = appSettingsRepo
        let snapshot = appSettingsRepo.load()
        settings = snapshot.watermark ?? .default
    }

    func saveSettings() async {
        var snapshot = appSettingsRepo.load()
        snapshot.watermark = settings
        try? await appSettingsRepo.save(snapshot)
    }

    private func loadSelectedLogo() async {
        guard let item = logoPickerItem else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let normalized = normalizedPNG(from: data) ?? data
            settings.logoImageData = normalized
        } catch {
            settings.logoImageData = nil
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
            height: floor(originalSize.height * scale)
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

    deinit {}
}
