import Foundation

// MARK: - Sistem politikaları (App Nap, nice, purge)

enum Policy {
    static func setAppNap(bundleID: String, disabled: Bool) {
        guard !bundleID.hasPrefix("pid.") else { return }
        if disabled {
            sh("/usr/bin/defaults", ["write", bundleID, "NSAppSleepDisabled", "-bool", "true"])
        } else {
            sh("/usr/bin/defaults", ["delete", bundleID, "NSAppSleepDisabled"])
        }
    }
    static var globalAppNapDisabled: Bool {
        get {
            sh("/usr/bin/defaults", ["read", "-g", "NSAppSleepDisabled"])
                .trimmingCharacters(in: .whitespacesAndNewlines) == "1"
        }
        set {
            if newValue { sh("/usr/bin/defaults", ["write", "-g", "NSAppSleepDisabled", "-bool", "true"]) }
            else { sh("/usr/bin/defaults", ["delete", "-g", "NSAppSleepDisabled"]) }
        }
    }
    /// Tüm süreç ağacına TEK şifre istemiyle nice uygular.
    @discardableResult
    static func renice(_ value: Int, pids: [Int32]) -> Bool {
        guard !pids.isEmpty else { return true }
        let list = pids.map { "-p \($0)" }.joined(separator: " ")
        let cmd = "/usr/bin/renice -n \(value) \(list) 2>/dev/null; true"
        if value < 0 { return adminSh(cmd) }
        sh("/bin/sh", ["-c", cmd])
        return true
    }
    static func purgeRAM() { adminSh("/usr/sbin/purge") }
}
