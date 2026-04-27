import Foundation

nonisolated enum FileNameBuilder {
    enum PhotoType: String {
        case before
        case after
        case combined
    }

    static let timestampFormat = "yyyyMMdd_HHmmss"
    static let shortIdLength = 6

    static func makeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = timestampFormat
        return formatter
    }

    static func before(
        prefix: String,
        timestamp: Date,
        pairId: UUID,
        formatter: DateFormatter = makeFormatter()
    ) -> String {
        build(type: .before, prefix: prefix, timestamp: timestamp, pairId: pairId, formatter: formatter)
    }

    static func after(
        prefix: String,
        timestamp: Date,
        pairId: UUID,
        formatter: DateFormatter = makeFormatter()
    ) -> String {
        build(type: .after, prefix: prefix, timestamp: timestamp, pairId: pairId, formatter: formatter)
    }

    static func combined(
        prefix: String,
        timestamp: Date,
        pairId: UUID,
        formatter: DateFormatter = makeFormatter()
    ) -> String {
        build(type: .combined, prefix: prefix, timestamp: timestamp, pairId: pairId, formatter: formatter)
    }

    static func thumbnail(forBaseName baseName: String) -> String {
        let stem = (baseName as NSString).deletingPathExtension
        let ext = (baseName as NSString).pathExtension
        let normalizedExtension = ext.isEmpty ? "jpg" : ext
        return "\(stem)_thumb.\(normalizedExtension)"
    }

    static func shortId(from pairId: UUID) -> String {
        let raw = pairId.uuidString.replacingOccurrences(of: "-", with: "")
        let lower = raw.lowercased()
        return String(lower.prefix(shortIdLength))
    }

    private static func build(
        type: PhotoType,
        prefix: String,
        timestamp: Date,
        pairId: UUID,
        formatter: DateFormatter
    ) -> String {
        let safePrefix = FileNamePrefixValidator.sanitize(prefix)
        let normalizedPrefix = safePrefix.isEmpty ? "" : "\(safePrefix)_"
        let stamp = formatter.string(from: timestamp)
        let short = shortId(from: pairId)
        return "\(normalizedPrefix)\(type.rawValue)_\(stamp)_\(short).jpg"
    }
}

nonisolated struct FileNameBuilderAdapter: FileNameBuilding {
    func before(prefix: String, timestamp: Date, pairId: UUID) -> String {
        FileNameBuilder.before(prefix: prefix, timestamp: timestamp, pairId: pairId)
    }

    func after(prefix: String, timestamp: Date, pairId: UUID) -> String {
        FileNameBuilder.after(prefix: prefix, timestamp: timestamp, pairId: pairId)
    }

    func combined(prefix: String, timestamp: Date, pairId: UUID) -> String {
        FileNameBuilder.combined(prefix: prefix, timestamp: timestamp, pairId: pairId)
    }
}
