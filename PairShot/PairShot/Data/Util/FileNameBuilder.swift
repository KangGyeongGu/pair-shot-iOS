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
        sequenceNumber: Int
    ) -> String {
        build(type: .before, prefix: prefix, timestamp: timestamp, sequenceNumber: sequenceNumber)
    }

    static func after(
        prefix: String,
        timestamp: Date,
        sequenceNumber: Int
    ) -> String {
        build(type: .after, prefix: prefix, timestamp: timestamp, sequenceNumber: sequenceNumber)
    }

    static func combined(
        prefix: String,
        timestamp: Date,
        sequenceNumber: Int
    ) -> String {
        build(type: .combined, prefix: prefix, timestamp: timestamp, sequenceNumber: sequenceNumber)
    }

    static func thumbnail(forBaseName baseName: String) -> String {
        let stem = (baseName as NSString).deletingPathExtension
        let ext = (baseName as NSString).pathExtension
        let normalizedExtension = ext.isEmpty ? "jpg" : ext
        return "\(stem)_thumb.\(normalizedExtension)"
    }

    static func extractSequenceNumber(from fileName: String) -> Int? {
        let pattern = "_(?:BEFORE|AFTER|PAIR)_([0-9]{\(sequenceWidth)})_"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(fileName.startIndex ..< fileName.endIndex, in: fileName)
        guard let match = regex.firstMatch(in: fileName, range: range), match.numberOfRanges >= 2 else {
            return nil
        }
        guard let captureRange = Range(match.range(at: 1), in: fileName) else { return nil }
        return Int(fileName[captureRange])
    }

    private static func build(
        type: PhotoType,
        prefix: String,
        timestamp: Date,
        sequenceNumber: Int
    ) -> String {
        let safePrefix = FileNamePrefixValidator.sanitize(prefix)
        let prefixPart = safePrefix.isEmpty ? "" : "\(safePrefix)_"
        let dateStr = DateFormatter.psFileDate.string(from: timestamp)
        let timeStr = DateFormatter.psFileTime.string(from: timestamp)
        let seqStr = String(format: "%0\(sequenceWidth)d", sequenceNumber)
        return "\(prefixPart)\(type.rawValue)_\(seqStr)_\(dateStr)_\(timeStr).jpg"
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

nonisolated struct FileNameBuilderAdapter: FileNameBuilding {
    func before(prefix: String, timestamp: Date, sequenceNumber: Int) -> String {
        FileNameBuilder.before(prefix: prefix, timestamp: timestamp, sequenceNumber: sequenceNumber)
    }

    func after(prefix: String, timestamp: Date, sequenceNumber: Int) -> String {
        FileNameBuilder.after(prefix: prefix, timestamp: timestamp, sequenceNumber: sequenceNumber)
    }

    func combined(prefix: String, timestamp: Date, sequenceNumber: Int) -> String {
        FileNameBuilder.combined(prefix: prefix, timestamp: timestamp, sequenceNumber: sequenceNumber)
    }
}
