import Foundation

nonisolated enum FileNameBuilder {
    enum PhotoType: String {
        case before = "BEFORE"
        case after = "AFTER"
        case combined = "PAIR"
    }

    static let dateFormat = "yyyyMMdd"
    static let timeFormat = "HHmmss"
    static let sequenceWidth = 3

    static func before(
        prefix: String,
        timestamp: Date,
        sequenceNumber: Int,
        fileExtension: String = "jpg",
    ) -> String {
        build(
            type: .before,
            prefix: prefix,
            timestamp: timestamp,
            sequenceNumber: sequenceNumber,
            fileExtension: fileExtension,
        )
    }

    static func after(
        prefix: String,
        timestamp: Date,
        sequenceNumber: Int,
        fileExtension: String = "jpg",
    ) -> String {
        build(
            type: .after,
            prefix: prefix,
            timestamp: timestamp,
            sequenceNumber: sequenceNumber,
            fileExtension: fileExtension,
        )
    }

    static func combined(
        prefix: String,
        timestamp: Date,
        sequenceNumber: Int,
        fileExtension: String = "jpg",
    ) -> String {
        build(
            type: .combined,
            prefix: prefix,
            timestamp: timestamp,
            sequenceNumber: sequenceNumber,
            fileExtension: fileExtension,
        )
    }

    private static func build(
        type: PhotoType,
        prefix: String,
        timestamp: Date,
        sequenceNumber: Int,
        fileExtension: String,
    ) -> String {
        let safePrefix = FileNamePrefixValidator.sanitize(prefix)
        let prefixPart = safePrefix.isEmpty ? "" : "\(safePrefix)_"
        let dateStr = DateFormatter.psFileDate.string(from: timestamp)
        let timeStr = DateFormatter.psFileTime.string(from: timestamp)
        let seqStr = String(format: "%0\(sequenceWidth)d", sequenceNumber)
        return "\(prefixPart)\(type.rawValue)_\(seqStr)_\(dateStr)_\(timeStr).\(fileExtension)"
    }
}

extension DateFormatter {
    nonisolated static let psFileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = FileNameBuilder.dateFormat
        return formatter
    }()

    nonisolated static let psFileTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = FileNameBuilder.timeFormat
        return formatter
    }()
}
