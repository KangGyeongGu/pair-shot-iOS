import Foundation
@preconcurrency import SwiftData

@MainActor
final class TutorialCleanupService {
    private let container: ModelContainer
    private let photoLibrary: PhotoLibraryService

    private var context: ModelContext {
        container.mainContext
    }

    init(container: ModelContainer, photoLibrary: PhotoLibraryService) {
        self.container = container
        self.photoLibrary = photoLibrary
    }

    func deleteAllTutorialPairs() async throws {
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { $0.isTutorial },
        )
        let entities = try context.fetch(descriptor)
        guard !entities.isEmpty else { return }
        var assetIdsToDelete: [String] = []
        for entity in entities {
            if let beforeId = entity.beforePhotoLocalIdentifier, !beforeId.isEmpty {
                assetIdsToDelete.append(beforeId)
            }
            if let afterId = entity.afterPhotoLocalIdentifier, !afterId.isEmpty {
                assetIdsToDelete.append(afterId)
            }
            for record in entity.exportHistory where !record.photoLocalIdentifier.isEmpty {
                assetIdsToDelete.append(record.photoLocalIdentifier)
            }
        }
        if !assetIdsToDelete.isEmpty {
            try await photoLibrary.deleteAssets(localIdentifiers: assetIdsToDelete)
        }
        for entity in entities {
            context.delete(entity)
        }
        try context.save()
    }
}
