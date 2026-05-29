import Foundation

enum SettingsExternalLinks {
    static var privacyPolicy: URL {
        PaywallURLs.privacy
    }

    static var termsOfUse: URL {
        PaywallURLs.terms
    }

    static var appStoreReview: URL {
        guard let url = URL(string: "https://apps.apple.com/app/id6770494128?action=write-review") else {
            fatalError("Invalid appStoreReview URL configuration")
        }
        return url
    }
}
