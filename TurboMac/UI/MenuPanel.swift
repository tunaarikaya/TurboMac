import SwiftUI

// MARK: - Menü çubuğu paneli

struct MenuPanel: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TurboMac").font(.headline)
                Text("v\(store.version)").font(.system(size: 9)).foregroundStyle(.tertiary)
                Spacer()
                LangPicker()
            }

            gauge(store.t("Bellek", "Memory"), store.pct(store.stats.ramPct),
                  store.stats.ramPct, store.stats.pressureColor,
                  "\(bytesStr(store.stats.ramUsed)) / \(bytesStr(store.stats.ramTotal)) · \(store.pressureText)")
            gauge("GPU", store.pct(Double(store.stats.gpuUtil)), Double(store.stats.gpuUtil), .purple,
                  "VRAM \(bytesStr(store.stats.gpuMem))")
            gauge("CPU", store.pct(store.stats.cpuPct), store.stats.cpuPct, .blue,
                  "user \(store.pct(store.stats.cpuUser)) · sys \(store.pct(store.stats.cpuSys))")

            Divider()

            let ruled = store.apps.filter { $0.priority != .normal }
            if ruled.isEmpty {
                Text(store.t("Aktif kural yok", "No active rules"))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(store.t("AKTİF KURALLAR", "ACTIVE RULES"))
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                ForEach(ruled) { row in
                    HStack(spacing: 6) {
                        Circle().fill(row.priority.color).frame(width: 6, height: 6)
                        Text(row.name).font(.caption).lineLimit(1)
                        Spacer()
                        Text(store.label(row.priority))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(row.priority.color)
                        if row.needsRestart {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8)).foregroundStyle(.orange)
                        }
                        Text(bytesStr(row.ram)).font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
            Text(store.t("EN ÇOK BELLEK", "TOP MEMORY"))
                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            ForEach(store.apps.prefix(5)) { row in
                HStack(spacing: 6) {
                    Text(row.name).font(.caption).lineLimit(1)
                    Spacer()
                    Text(bytesStr(row.ram)).font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if !store.pendingRestart.isEmpty {
                Text(store.t("⚠️ \(store.pendingRestart.count) uygulama kapatılıp açılmalı — ayar henüz tam geçerli değil.",
                             "⚠️ \(store.pendingRestart.count) app(s) must be quit and reopened — setting not fully active."))
                    .font(.system(size: 10)).foregroundStyle(.orange)
            }

            Divider()
            Button(store.t("Paneli Aç", "Open Panel")) {
                NSApp.setActivationPolicy(.regular)
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button(store.t("Belleği Boşalt", "Free Memory")) { store.purge() }
            Button(store.t("🚨 Acil Durum — Hepsini Sıfırla", "🚨 Emergency Reset")) {
                store.emergencyReset()
            }
            Divider()
            Button(store.t("Çıkış", "Quit")) { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 300)
    }

    func gauge(_ title: String, _ value: String, _ p: Double, _ tint: Color, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.system(.caption, design: .rounded)).bold().foregroundStyle(tint)
            }
            Bar(value: p, tint: tint, height: 6)
            Text(sub).font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }
}
