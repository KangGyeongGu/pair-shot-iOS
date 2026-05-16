import SwiftData
import SwiftUI

struct PhotoPairQueryHost<Content: View>: View {
    @Query(
        filter: #Predicate<PhotoPairEntity> { !$0.isTutorial },
        sort: \PhotoPairEntity.createdAt,
        order: .reverse,
    )
    private var entities: [PhotoPairEntity]

    let content: ([PhotoPair]) -> Content

    var body: some View {
        content(entities.map { $0.toDomain() })
    }
}
