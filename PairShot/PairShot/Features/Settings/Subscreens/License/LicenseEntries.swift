import Foundation

struct LicenseEntry: Identifiable {
    let id = UUID()
    let name: String
    let author: String
    let licenseType: String
    let url: URL

    var subtitle: String {
        "\(author) · \(licenseType)"
    }
}

enum LicenseEntries {
    static let all: [LicenseEntry] = [
        LicenseEntry(
            name: "Google Mobile Ads SDK",
            author: "Google",
            licenseType: "Apache 2.0",
            url: apacheTwoURL,
        ),
        LicenseEntry(
            name: "Google User Messaging Platform",
            author: "Google",
            licenseType: "Apache 2.0",
            url: apacheTwoURL,
        ),
        LicenseEntry(
            name: "ZIPFoundation",
            author: "Thomas Zoechling",
            licenseType: "MIT",
            url: zipFoundationURL,
        ),
    ]

    private static let apacheTwoURL: URL = {
        guard let url = URL(string: "https://www.apache.org/licenses/LICENSE-2.0") else {
            fatalError("Invalid static URL")
        }
        return url
    }()

    private static let zipFoundationURL: URL = {
        guard let url = URL(string: "https://github.com/weichsel/ZIPFoundation/blob/development/LICENSE") else {
            fatalError("Invalid static URL")
        }
        return url
    }()
}
