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
    // swiftlint:disable trailing_comma
    static let all: [LicenseEntry] = [
        LicenseEntry(
            name: "Google Mobile Ads SDK",
            author: "Google",
            licenseType: "Apache 2.0",
            url: apacheTwoURL
        ),
        LicenseEntry(
            name: "ZIPFoundation",
            author: "Thomas Zoechling",
            licenseType: "MIT",
            url: zipFoundationURL
        ),
    ]
    // swiftlint:enable trailing_comma

    // swiftlint:disable force_unwrapping
    private static let apacheTwoURL = URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!
    private static let zipFoundationURL = URL(
        string: "https://github.com/weichsel/ZIPFoundation/blob/development/LICENSE"
    )!
    // swiftlint:enable force_unwrapping
}
