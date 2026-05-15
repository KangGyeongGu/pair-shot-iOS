import Foundation

nonisolated enum PaywallURLs {
    static var privacy: URL {
        url(path: "/privacy")
    }

    static var terms: URL {
        url(path: "/terms")
    }

    private static var isEnglish: Bool {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return Locale(identifier: preferred).language.languageCode?.identifier != "ko"
    }

    private static func url(path: String) -> URL {
        let base = "https://pairshot.kangkyeonggu.com"
        let suffix = isEnglish ? "/en" : ""
        guard let url = URL(string: base + path + suffix) else {
            fatalError("Invalid PaywallURLs base configuration")
        }
        return url
    }
}
