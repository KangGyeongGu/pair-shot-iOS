import Foundation

struct PairPreviewRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

struct PairAfterDeleteRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}
