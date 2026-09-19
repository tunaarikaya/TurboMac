import AppKit

// MARK: - Uygulamayı politika ile yeniden başlatma

enum RelaunchResult {
    case ok
    /// Uygulama kapanmayı reddetti (büyük ihtimalle "kaydedilmemiş değişiklikler" soruyor).
    case refusedToQuit
    /// Kapandı ama tekrar açılamadı.
    case failedToReopen
    case noBundle
}

enum Relaunch {
    /// macOS süreç politikasını SADECE uygulama başlarken kabul ediyor (ölçümle doğrulandı).
    /// Bu yüzden kuralın gerçekten etkili olması için uygulamayı kapatıp yeniden açmak gerekiyor.
    ///
    /// ÖNEMLİ: burada asla `forceTerminate()` kullanmıyoruz. Uygulama "kaydetmek
    /// ister misin?" diye sorup beklediğinde zorla kapatmak kullanıcının işini
    /// silerdi. Kapanmazsa vazgeçip durumu bildiriyoruz.
    static func restart(app: NSRunningApplication,
                        throttled: Bool,
                        done: @escaping (RelaunchResult) -> Void) {
        guard let url = app.bundleURL else { done(.noBundle); return }
        let exe = Bundle(url: url)?.executablePath
        let bid = app.bundleIdentifier

        app.terminate()

        DispatchQueue.global().async {
            // Kapanması için 10 saniyeye kadar bekle (kaydetme diyaloğu çıkabilir).
            let deadline = Date().addingTimeInterval(10)
            while !app.isTerminated && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.25)
            }
            guard app.isTerminated else {
                DispatchQueue.main.async { done(.refusedToQuit) }
                return
            }
            Thread.sleep(forTimeInterval: 0.6)   // port/LaunchServices temizliği

            if throttled, let exe {
                launchThrottled(exe)
            } else {
                sh("/usr/bin/open", [url.path])
            }

            // Gerçekten açıldı mı? Açılmadıysa normal yoldan tekrar dene.
            let ok = waitForLaunch(bundleID: bid, timeout: 8)
                || { sh("/usr/bin/open", [url.path]); return waitForLaunch(bundleID: bid, timeout: 8) }()

            DispatchQueue.main.async { done(ok ? .ok : .failedToReopen) }
        }
    }

    /// Uygulamayı arka plan politikasıyla başlatır.
    /// `open` kullanamıyoruz: LaunchServices süreci launchd altında doğurduğu için
    /// politika miras kalmıyor. Bu yüzden ikiliyi doğrudan çalıştırıyoruz.
    private static func launchThrottled(_ exe: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/taskpolicy")
        p.arguments = ["-b", "-t", "2", "-l", "2", exe]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        // Referansı bırakırken zombi kalmasın diye bitişini dinliyoruz.
        p.terminationHandler = { _ in }
        try? p.run()
    }

    private static func waitForLaunch(bundleID: String?, timeout: TimeInterval) -> Bool {
        guard let bundleID else { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let up = NSWorkspace.shared.runningApplications
                .contains { $0.bundleIdentifier == bundleID }
            if up { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }
}
