import CoreImage
import ImageIO
import UIKit

extension CameraManager {
    func savePhoto(data: Data, projectId: UUID?, pairId: UUID?, isBefore: Bool) async {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let resolvedProject = projectId ?? UUID()
        let resolvedPair = pairId ?? UUID()

        let pairDirectory = documentsURL
            .appendingPathComponent("projects")
            .appendingPathComponent(resolvedProject.uuidString)
            .appendingPathComponent("pairs")
            .appendingPathComponent(resolvedPair.uuidString)

        do {
            try fileManager.createDirectory(at: pairDirectory, withIntermediateDirectories: true)
        } catch {
            return
        }

        let photoURL = pairDirectory.appendingPathComponent(isBefore ? "before.jpg" : "after.jpg")
        let jpegData: Data = if let image = UIImage(data: data),
                                let converted = image.jpegData(compressionQuality: 0.92)
        {
            converted
        } else {
            data
        }

        do {
            try jpegData.write(to: photoURL, options: .atomic)
        } catch {
            return
        }

        if let image = UIImage(data: jpegData) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }

        await generateThumbnail(
            sourceURL: photoURL,
            projectId: resolvedProject,
            pairId: resolvedPair,
            isBefore: isBefore,
            documentsURL: documentsURL
        )

        let suffix = isBefore ? "before" : "after"
        let result = SaveResult(
            filePath: "projects/\(resolvedProject.uuidString)/pairs/\(resolvedPair.uuidString)/\(suffix).jpg",
            thumbnailPath: "projects/\(resolvedProject.uuidString)/thumbs/\(resolvedPair.uuidString)_\(suffix).jpg",
            isBefore: isBefore,
            pairId: resolvedPair
        )
        await MainActor.run { [weak self] in self?.onPhotoSaved?(result) }
    }

    private func generateThumbnail(
        sourceURL: URL,
        projectId: UUID,
        pairId: UUID,
        isBefore: Bool,
        documentsURL: URL
    ) async {
        let fileManager = FileManager.default
        let thumbDirectory = documentsURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId.uuidString)
            .appendingPathComponent("thumbs")

        do {
            try fileManager.createDirectory(at: thumbDirectory, withIntermediateDirectories: true)
        } catch {
            return
        }

        let suffix = isBefore ? "before" : "after"
        let thumbURL = thumbDirectory.appendingPathComponent("\(pairId.uuidString)_\(suffix).jpg")

        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, sourceOptions as CFDictionary) else {
            return
        }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: 300,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
        ]

        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return
        }

        let thumbImage = UIImage(cgImage: cgThumb)
        guard let thumbData = thumbImage.jpegData(compressionQuality: 0.85) else { return }
        try? thumbData.write(to: thumbURL, options: .atomic)
    }
}
