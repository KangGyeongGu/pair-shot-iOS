import Foundation

enum SectionDateFormatter {
    static func text(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("yMd")
        return formatter.string(from: date)
    }
}
