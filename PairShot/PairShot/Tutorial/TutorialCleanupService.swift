import Foundation
@preconcurrency import SwiftData

@MainActor
final class TutorialCleanupService {
    private let container: ModelContainer
    private let tutorialPhotoStore: TutorialPhotoStore

    private var context: ModelContext {
        container.mainContext
    }

    init(container: ModelContainer, tutorialPhotoStore: TutorialPhotoStore) {
        self.container = container
        self.tutorialPhotoStore = tutorialPhotoStore
    }

    func deleteAllTutorialPairs() async throws {
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { $0.isTutorial },
        )
        let entities = try context.fetch(descriptor)
        try tutorialPhotoStore.deleteAll()
        guard !entities.isEmpty else { return }
        for entity in entities {
            context.delete(entity)
        }
        try context.save()
    }
}
