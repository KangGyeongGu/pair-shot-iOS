import Foundation

@MainActor
protocol CompositorService: AnyObject {
    func makeComposite(
        for pair: PhotoPair,
        options: CompositeOptions,
        now: Date
    ) async throws -> Data
}

@MainActor
final class DefaultCompositorService: CompositorService {
    private let photoLibrary: PhotoLibraryService

    init(photoLibrary: PhotoLibraryService) {
        self.photoLibrary = photoLibrary
    }

    func makeComposite(
        for pair: PhotoPair,
        options: CompositeOptions,
        now: Date
    ) async throws -> Data {
        try await CompositeRenderer.makeComposite(
            for: pair,
            options: options,
            photoLibrary: photoLibrary,
            now: now
        )
    }

    deinit {}
}
