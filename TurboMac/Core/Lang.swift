import Foundation

// MARK: - Dil

enum Lang: String, CaseIterable {
    case tr, en
    var flag: String { self == .tr ? "TR" : "EN" }
}
