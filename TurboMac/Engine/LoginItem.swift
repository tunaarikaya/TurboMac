import Foundation

// MARK: - Login item

/// Açılışta otomatik başlatma (LaunchAgent ile — imza/entitlement gerektirmez).
enum LoginItem {
    static let label = "com.tuna.turbomac"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var enabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    /// Xcode'dan çalışırken uygulama DerivedData içindedir. Oraya işaret eden bir
    /// LaunchAgent yazmak, Xcode klasörü temizlenince bozuk bir açılış girdisi
    /// bırakırdı — bu yüzden yalnızca gerçekten kurulmuş kopyaya izin veriyoruz.
    static var canEnable: Bool { installedExecutable() != nil }

    /// Kurulu uygulamanın çalıştırılabilir dosyası: önce mevcut kopya kurulu bir
    /// yerdeyse o, değilse Applications klasörlerindeki kurulu kopya.
    static func installedExecutable() -> String? {
        let fm = FileManager.default
        if let exe = Bundle.main.executablePath, isInstalled(exe) { return exe }
        let home = fm.homeDirectoryForCurrentUser.path
        for base in ["\(home)/Applications", "/Applications"] {
            let exe = "\(base)/TurboMac.app/Contents/MacOS/TurboMac"
            if fm.isExecutableFile(atPath: exe) { return exe }
        }
        return nil
    }

    private static func isInstalled(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix("/Applications/") || path.hasPrefix("\(home)/Applications/")
    }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        let fm = FileManager.default
        if on {
            guard let exe = installedExecutable() else { return false }
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict>
              <key>Label</key><string>\(label)</string>
              <key>ProgramArguments</key><array><string>\(exe)</string></array>
              <key>RunAtLoad</key><true/>
              <key>KeepAlive</key><false/>
              <key>ProcessType</key><string>Interactive</string>
            </dict></plist>
            """
            try? fm.createDirectory(at: plistURL.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
            do { try xml.write(to: plistURL, atomically: true, encoding: .utf8) }
            catch { return false }
            sh("/bin/launchctl", ["unload", plistURL.path])
            sh("/bin/launchctl", ["load", plistURL.path])
            return enabled
        } else {
            sh("/bin/launchctl", ["unload", plistURL.path])
            try? fm.removeItem(at: plistURL)
            return true
        }
    }
}
