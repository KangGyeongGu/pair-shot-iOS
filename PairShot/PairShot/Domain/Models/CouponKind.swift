import Foundation

nonisolated enum CouponKind: Codable, Equatable {
    case timed(days: Int)
    case unlimited

    static let timedPrefix: String = "timed:"
    static let unlimitedRawString: String = "unlimited"

    var rawString: String {
        switch self {
            case let .timed(days):
                "\(Self.timedPrefix)\(days)"

            case .unlimited:
                Self.unlimitedRawString
        }
    }

    init?(rawString: String) {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == Self.unlimitedRawString {
            self = .unlimited
            return
        }
        if trimmed.hasPrefix(Self.timedPrefix),
           let days = Int(trimmed.dropFirst(Self.timedPrefix.count)),
           days > 0
        {
            self = .timed(days: days)
            return
        }
        return nil
    }
}
