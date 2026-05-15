import Foundation

nonisolated enum ProductIDs {
    static let proMonthly = "app.pairshot.pro.monthly"
    static let proAnnual = "app.pairshot.pro.annual"
    static let groupID = "21461234"

    static let allProSet: Set<String> = [proMonthly, proAnnual]
    static let allLoadable: [String] = [proMonthly, proAnnual]
}
