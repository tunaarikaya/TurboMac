import SwiftUI
import AppKit

// MARK: - Entry

/// Login item + elle açma aynı anda olunca iki kopya çalışmasın.
enum SingleInstance {
    static func enforce() {
        // Xcode'dan Run'a basınca menü çubuğundaki kopya yüzünden kapanmasın.
        #if DEBUG
        return
        #else
        guard let bid = Bundle.main.bundleIdentifier else { return }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !others.isEmpty { others.first?.activate(); exit(0) }
        #endif
    }
}

/// Release'de app menü çubuğunda yaşar (Dock ikonu yok).
/// Debug'da Run'a basınca gözle görülür bir şey olsun diye pencereyi açıyoruz.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        showFirstRunNoteIfNeeded()
        #if DEBUG
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.activate(ignoringOtherApps: true)
            if let w = NSApp.windows.first(where: { $0.canBecomeMain }) {
                w.makeKeyAndOrderFront(nil)
            }
        }
        #endif
    }
    /// İlk açılışta uygulama yalnızca menü çubuğunda yaşıyor; kullanıcı hiçbir şey
    /// olmadı sanmasın diye nerede olduğunu bir kez söylüyoruz.
    private func showFirstRunNoteIfNeeded() {
        let key = "didShowFirstRunNote"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let tr = Locale.preferredLanguages.first?.hasPrefix("tr") ?? false
        let a = NSAlert()
        a.messageText = tr ? "TurboMac menü çubuğunda çalışıyor"
                           : "TurboMac is running in your menu bar"
        a.informativeText = tr
            ? "Dock'ta ikonu yok. Menü çubuğunun sağındaki yüzdeye (örn. %59 — bellek kullanımın) tıklayınca panel açılır.\n\nOradan uygulamalara hız seviyesi verebilir, her şeyi tek tuşla eski haline döndürebilirsin."
            : "It has no Dock icon. Click the percentage on the right of your menu bar (e.g. 59% — your memory usage) to open the panel.\n\nFrom there you can set a speed level per app, and undo everything with one button."
        a.addButton(withTitle: tr ? "Anladım" : "Got it")
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }

    /// Dock ikonuna tıklayınca paneli geri getir.
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let w = NSApp.windows.first(where: { $0.canBecomeMain }) {
            NSApp.setActivationPolicy(.regular)
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
}

@main
struct TurboMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = Store()

    init() { SingleInstance.enforce() }

    var body: some Scene {
        mainWindow

        MenuBarExtra {
            MenuPanel().environmentObject(store)
        } label: {
            Text(store.pct(store.stats.ramPct))
        }
        .menuBarExtraStyle(.window)
    }

    private var mainWindow: some Scene {
        let w = Window("TurboMac", id: "main") {
            ContentView()
                .environmentObject(store)
                .onDisappear {
                    // Pencere kapanınca Dock ikonunu gizle, menü çubuğunda kal.
                    #if !DEBUG
                    NSApp.setActivationPolicy(.accessory)
                    #endif
                }
        }
        .windowResizability(.contentSize)

        #if DEBUG
        return w.defaultLaunchBehavior(.presented)
        #else
        return w.defaultLaunchBehavior(.suppressed)
        #endif
    }
}
