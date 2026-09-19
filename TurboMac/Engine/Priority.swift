import SwiftUI

// MARK: - Priority

enum Priority: String, CaseIterable, Codable {
    case low, normal, turbo, max

    var shortTR: String {
        switch self { case .low: return "Kıs"; case .normal: return "Normal"
                      case .turbo: return "Turbo"; case .max: return "MAX" }
    }
    var shortEN: String {
        switch self { case .low: return "Slow"; case .normal: return "Normal"
                      case .turbo: return "Turbo"; case .max: return "MAX" }
    }
    var color: Color {
        switch self { case .low: return .orange; case .normal: return .secondary
                      case .turbo: return .green; case .max: return .pink }
    }
    var niceValue: Int {
        switch self { case .low: return 15; case .normal: return 0
                      case .turbo: return -10; case .max: return -20 }
    }
    /// Negatif nice sadece root ile verilebilir.
    var needsAdmin: Bool { niceValue < 0 }
}
