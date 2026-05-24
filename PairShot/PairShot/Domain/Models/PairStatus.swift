enum PairStatus: Equatable, CaseIterable {
    case scheduled
    case afterOnly
    case captured
}

extension PhotoPair {
    var status: PairStatus {
        let hasBefore = beforePhotoLocalIdentifier?.isEmpty == false
        let hasAfter = afterPhotoLocalIdentifier?.isEmpty == false
        if hasBefore, hasAfter { return .captured }
        if hasAfter { return .afterOnly }
        return .scheduled
    }
}
