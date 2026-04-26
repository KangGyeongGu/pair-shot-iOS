import Foundation

enum PairStatus: Equatable, CaseIterable {
    case scheduled
    case captured
    case combined
}

extension PhotoPair {
    var status: PairStatus {
        if combinedFileName != nil { return .combined }
        if afterFileName != nil { return .captured }
        return .scheduled
    }
}
