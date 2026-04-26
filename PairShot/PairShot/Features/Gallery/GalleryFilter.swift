import Foundation
import SwiftUI

/// P4.2 — toggle between "all pairs" and "composited only" inside
/// `PairGalleryView`. Pure value type so unit tests don't need a SwiftUI host.
///
/// **Why two modes only**: Android v1.1.3 ships ALL / 합성본; we match that.
/// Adding "complete only" / "pending only" buckets is an explicit non-goal
/// (would multiply Phase 4 surface area without user benefit — composite
/// itself implies complete).
enum GalleryFilter: String, CaseIterable, Identifiable {
    /// Every PhotoPair attached to the project, regardless of status.
    case all
    /// Only pairs that have a non-empty `combinedPath` — i.e. the user has
    /// produced a side-by-side composite.
    case combinedOnly

    var id: String {
        rawValue
    }

    /// Korean label for the segmented picker.
    var label: String {
        switch self {
            case .all: String(localized: "전체")
            case .combinedOnly: String(localized: "합성본")
        }
    }

    /// SF Symbol used in the segmented picker.
    var systemImage: String {
        switch self {
            case .all: "square.grid.2x2"
            case .combinedOnly: "rectangle.on.rectangle"
        }
    }

    /// Apply this filter to a list of `PhotoPair`s. Pure function so the
    /// gallery view can stay declarative and tests can target the predicate
    /// directly.
    ///
    /// **Note on `combinedPath`**: a non-nil but empty string is treated as
    /// "no composite" — defensive against legacy migrations where the field
    /// was set to `""` instead of `nil`.
    func apply(to pairs: [PhotoPair]) -> [PhotoPair] {
        switch self {
            case .all:
                pairs

            case .combinedOnly:
                pairs.filter { pair in
                    guard let combined = pair.combinedPath else { return false }
                    return !combined.isEmpty
                }
        }
    }
}
