import SwiftData
import SwiftUI

struct AlbumByIdQueryHost<Content: View>: View {
    @Query private var entities: [AlbumEntity]

    let content: (Album?) -> Content

    var body: some View {
        content(entities.first?.toDomain())
    }

    init(id: UUID, @ViewBuilder content: @escaping (Album?) -> Content) {
        self.content = content
        let predicate = #Predicate<AlbumEntity> { $0.id == id }
        _entities = Query(filter: predicate)
    }
}
