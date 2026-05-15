import SwiftData
import SwiftUI

struct AlbumQueryHost<Content: View>: View {
    @Query(sort: \AlbumEntity.updatedAt, order: .reverse)
    private var entities: [AlbumEntity]

    let content: ([Album]) -> Content

    var body: some View {
        content(entities.map { $0.toDomain() })
    }
}
