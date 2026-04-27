import Foundation
import SwiftData

@MainActor
protocol CompositorService: AnyObject {
    func makeComposite(
        for pair: PhotoPair,
        options: CompositeOptions,
        fileNamePrefix: String,
        now: Date
    ) async throws -> String
}

@MainActor
final class DefaultCompositorService: CompositorService {
    private let storage: PhotoStorageService
    private let modelContainer: ModelContainer

    init(storage: PhotoStorageService, modelContainer: ModelContainer) {
        self.storage = storage
        self.modelContainer = modelContainer
    }

    func makeComposite(
        for pair: PhotoPair,
        options: CompositeOptions,
        fileNamePrefix: String,
        now: Date
    ) async throws -> String {
        try await CompositeRenderer.makeComposite(
            for: pair,
            options: options,
            storage: storage,
            fileNamePrefix: fileNamePrefix,
            in: modelContainer.mainContext,
            now: now
        )
    }

    deinit {}
}
