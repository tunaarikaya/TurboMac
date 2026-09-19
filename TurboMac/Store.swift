import SwiftUI
import AppKit

// MARK: - Store

@MainActor
final class Store: ObservableObject {
    @Published var stats = SysStats()
    @Published var apps: [AppRow] = []
    @Published var globalAppNapOff = false
    @Published var launchAtLogin = false
    @Published var lastAction = ""
    @Published var bench: BenchResult?
    @Published var benchRunning = false
    @Published var caffeineOn = false
    @Published var lang: Lang = .tr {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") }
    }
    @Published private(set) var rules: [String: Priority] = [:]

    /// "1.0 (3)" gibi — panelde ve Hakkında'da gösterilir.
    let version: String = {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return build == short ? short : "\(short) (\(build))"
    }()

    private let sampler = Sampler()
    private var timer: Timer?

    var turboCount: Int { apps.filter { $0.priority == .turbo || $0.priority == .max }.count }
    var lowCount: Int { apps.filter { $0.priority == .low }.count }
    /// Kuralı konmuş ama henüz yeniden başlatılmamış uygulamalar.
    var pendingRestart: [AppRow] { apps.filter { $0.needsRestart } }

    // MARK: Dil yardımcıları
    func t(_ tr: String, _ en: String) -> String { lang == .tr ? tr : en }
    /// Türkçe'de yüzde işareti sayıdan önce gelir: %50
    func pct(_ v: Double) -> String {
        lang == .tr ? String(format: "%%%.0f", v) : String(format: "%.0f%%", v)
    }
    func label(_ p: Priority) -> String { lang == .tr ? p.shortTR : p.shortEN }
    var pressureText: String {
        switch stats.pressure {
        case 4: return t("Kritik", "Critical")
        case 2: return t("Uyarı", "Warning")
        default: return t("Normal", "Normal")
        }
    }

    init() {
        if let l = UserDefaults.standard.string(forKey: "lang"), let v = Lang(rawValue: l) { lang = v }
        if let raw = UserDefaults.standard.dictionary(forKey: "rules") as? [String: String] {
            rules = raw.compactMapValues { Priority(rawValue: $0) }
        }
        ruleSetAt = UserDefaults.standard.dictionary(forKey: "ruleSetAt") as? [String: Date] ?? [:]
        pruneMissingApps()
        Caffeine.cleanUpLegacyProcesses()   // eski sürümlerin kaçak süreçleri
        globalAppNapOff = Policy.globalAppNapDisabled
        launchAtLogin = LoginItem.enabled
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Silinmiş/kaldırılmış uygulamaların kuralları birikmesin.
    /// (Sayaçların yanlış görünmesinin sebebi buydu.)
    private func pruneMissingApps() {
        let ws = NSWorkspace.shared
        let gone = rules.keys.filter { bid in
            bid.hasPrefix("pid.") || ws.urlForApplication(withBundleIdentifier: bid) == nil
        }
        guard !gone.isEmpty else { return }
        for bid in gone {
            rules.removeValue(forKey: bid)
            ruleSetAt.removeValue(forKey: bid)
        }
        saveRules()
    }

    private func saveRules() {
        UserDefaults.standard.set(rules.mapValues { $0.rawValue }, forKey: "rules")
        UserDefaults.standard.set(ruleSetAt, forKey: "ruleSetAt")
    }

    /// Kuralın hangi an konulduğu. Uygulamanın açılış saati bundan eskiyse
    /// ayar henüz tam geçerli değil demektir (yeniden başlatma gerekir).
    private var ruleSetAt: [String: Date] = [:]
    func priority(for bundleID: String) -> Priority { rules[bundleID] ?? .normal }

    func refresh() {
        stats = sampler.snapshot()
        let table = procTable()
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier > 0
        }
        var rows: [AppRow] = []
        for app in running {
            let pid = app.processIdentifier
            let bid = app.bundleIdentifier ?? "pid.\(pid)"
            let tree = processTree(pid, table: table)
            var ram: UInt64 = 0
            var cpu: Double = 0
            for p in tree { if let i = table[p] { ram += i.rss; cpu += i.cpu } }
            let prio = priority(for: bid)
            // Uygulama, kural konulduktan SONRA başlamış mı?
            let launched = app.launchDate ?? .distantPast
            let pending = prio != .normal && launched < (ruleSetAt[bid] ?? .distantPast)
            rows.append(AppRow(id: pid, bundleID: bid, name: app.localizedName ?? bid,
                               icon: app.icon, ram: ram, cpu: cpu,
                               nice: table[pid]?.nice ?? 0,
                               priority: prio, procCount: tree.count,
                               needsRestart: pending))
        }
        apps = rows.sorted { $0.ram > $1.ram }

        if rules.values.contains(.max) {
            Caffeine.shared.start()
        } else if Caffeine.shared.active {
            Caffeine.shared.stop()
        }
        caffeineOn = Caffeine.shared.active
    }

    // MARK: Öncelik uygulama
    func setPriority(_ row: AppRow, _ p: Priority) {
        let tree = processTree(row.id, table: procTable())

        if p == .normal {
            rules.removeValue(forKey: row.bundleID)
            ruleSetAt.removeValue(forKey: row.bundleID)
            Policy.setAppNap(bundleID: row.bundleID, disabled: false)
            Policy.renice(0, pids: tree)
            lastAction = t("\(row.name) normale döndü.", "\(row.name) back to normal.")
        } else {
            rules[row.bundleID] = p
            ruleSetAt[row.bundleID] = Date()
            // App Nap: Turbo/MAX kapatır, Kıs açık bırakır.
            Policy.setAppNap(bundleID: row.bundleID, disabled: p != .low)
            Policy.renice(p.niceValue, pids: tree)
            if p == .max { Caffeine.shared.start() }
            lastAction = t("\(row.name) → \(label(p)). Ayarın tam geçerli olması için \(row.name)'i yeniden başlat.",
                           "\(row.name) → \(label(p)). Restart \(row.name) for the setting to fully apply.")
        }
        saveRules()
        refresh()
    }

    /// Kuralı gerçekten uygulamak için app'i kapatıp politika altında açar.
    func restartApp(_ row: AppRow) {
        guard let app = NSRunningApplication(processIdentifier: row.id) else { return }
        let throttled = priority(for: row.bundleID) == .low
        let alert = NSAlert()
        let lvl = label(priority(for: row.bundleID))
        alert.messageText = t("\(row.name) şimdi kapatılıp açılsın mı?",
                              "Quit and reopen \(row.name) now?")
        alert.informativeText = t(
            """
            "\(lvl)" ayarını macOS ancak uygulama YENİDEN AÇILIRKEN kabul ediyor. \
            Bu yüzden \(row.name) önce kapatılacak, hemen ardından ayar aktif halde tekrar açılacak. \
            Yaklaşık 3 saniye sürer.

            Kaydedilmemiş bir işin varsa önce kaydet.
            """,
            """
            macOS only applies the "\(lvl)" setting while an app is STARTING UP. \
            So \(row.name) will be quit and immediately reopened with the setting active. \
            Takes about 3 seconds.

            Save any unsaved work first.
            """)
        alert.addButton(withTitle: t("Kapat ve Aç", "Quit & Reopen"))
        alert.addButton(withTitle: t("Vazgeç", "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = row.name
        let bid = row.bundleID
        lastAction = t("\(name) yeniden başlatılıyor…", "Restarting \(name)…")
        Relaunch.restart(app: app, throttled: throttled) { [weak self] result in
            guard let self else { return }
            switch result {
            case .ok:
                let p = self.priority(for: bid)
                if p.needsAdmin,
                   let fresh = NSWorkspace.shared.runningApplications
                    .first(where: { $0.bundleIdentifier == bid }) {
                    let tree = processTree(fresh.processIdentifier, table: procTable())
                    Policy.renice(p.niceValue, pids: tree)
                }
                self.lastAction = self.t("✅ \(name) yeniden açıldı — ayar artık tam aktif.",
                                         "✅ \(name) reopened — the setting is now fully active.")
            case .refusedToQuit:
                self.lastAction = self.t("⚠️ \(name) kapanmadı — muhtemelen kaydedilmemiş bir şey soruyor. İşini kaydedip tekrar dene.",
                                         "⚠️ \(name) wouldn't quit — it's probably asking about unsaved work. Save it and try again.")
            case .failedToReopen:
                self.lastAction = self.t("⚠️ \(name) kapandı ama açılamadı. Elle açman yeterli, ayar geçerli olacak.",
                                         "⚠️ \(name) quit but couldn't reopen. Just open it yourself — the setting will apply.")
            case .noBundle:
                self.lastAction = self.t("⚠️ \(name) yeniden başlatılamadı.", "⚠️ Couldn't restart \(name).")
            }
            self.refresh()
        }
    }

    // MARK: Acil durum
    func emergencyReset() {
        let alert = NSAlert()
        alert.messageText = t("Her şeyi eski haline döndür?", "Reset everything?")
        alert.informativeText = t(
            "Tüm kurallar silinir, App Nap ayarları (global + app bazlı) kaldırılır, süreç öncelikleri sıfırlanır, uyanık tutma bırakılır. Mac tamamen varsayılana döner.",
            "All rules are removed, App Nap settings (global + per-app) are reverted, process priorities reset, wake-lock released. Your Mac returns to defaults.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: t("Sıfırla", "Reset"))
        alert.addButton(withTitle: t("Vazgeç", "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let table = procTable()
        var allPids: [Int32] = []
        for row in apps where row.priority != .normal {
            allPids += processTree(row.id, table: table)
        }
        // Kapalı olan app'lerin kayıtlı ayarlarını da temizle
        for bid in rules.keys { Policy.setAppNap(bundleID: bid, disabled: false) }

        Policy.globalAppNapDisabled = false
        globalAppNapOff = false
        Caffeine.shared.stop()
        rules.removeAll()
        ruleSetAt.removeAll()
        saveRules()
        if !allPids.isEmpty { Policy.renice(0, pids: allPids) }
        sh("/usr/bin/killall", ["cfprefsd"])   // ayarların anında geçerli olması için

        lastAction = t("Her şey varsayılana döndürüldü.", "Everything restored to defaults.")
        refresh()
    }

    func toggleGlobalAppNap(_ on: Bool) {
        Policy.globalAppNapDisabled = on
        globalAppNapOff = on
        lastAction = on ? t("Global App Nap kapatıldı — açık app'leri yeniden başlat.",
                            "Global App Nap disabled — restart open apps.")
                        : t("Global App Nap tekrar açıldı.", "Global App Nap re-enabled.")
    }

    func toggleLaunchAtLogin(_ on: Bool) {
        if on && !LoginItem.canEnable {
            lastAction = t("⚠️ Açılışta başlatma yalnızca kurulu kopyada çalışır. TurboMac'i Applications klasörüne taşı.",
                           "⚠️ Start-at-login only works for an installed copy. Move TurboMac to your Applications folder.")
            launchAtLogin = LoginItem.enabled
            return
        }
        LoginItem.set(on)
        launchAtLogin = LoginItem.enabled
        lastAction = launchAtLogin ? t("Açılışta otomatik başlayacak.", "Will start at login.")
                                   : t("Otomatik başlatma kapatıldı.", "Start at login disabled.")
    }

    func purge() {
        lastAction = t("Bellek temizleniyor…", "Purging memory…")
        DispatchQueue.global().async {
            Policy.purgeRAM()
            Task { @MainActor in
                self.lastAction = self.t("Inactive bellek boşaltıldı.", "Inactive memory freed.")
                self.refresh()
            }
        }
    }

    func runBench() {
        guard !benchRunning else { return }
        benchRunning = true
        lastAction = t("Ölçüm sürüyor (~10 sn)…", "Benchmarking (~10 s)…")
        DispatchQueue.global().async {
            let r = Bench.run()
            Task { @MainActor in
                self.bench = r
                self.benchRunning = false
                self.lastAction = self.t("Ölçüm bitti.", "Benchmark done.")
            }
        }
    }
}
