import SwiftData
import SwiftUI

struct PhotoPairQueryHost<Content: View>: View {
    @Query(
        sort: \PhotoPairEntity.createdAt,
        order: .reverse,
    )
    private var entities: [PhotoPairEntity]

    @Environment(TutorialCoordinator.self) private var tutorialCoordinator

    let content: ([PhotoPair]) -> Content

    var body: some View {
        let filtered = tutorialCoordinator.isActive
            ? entities
            : entities.filter { !$0.isTutorial }
        content(filtered.map { $0.toDomain() })
    }
}
