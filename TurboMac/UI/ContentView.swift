import SwiftUI

// MARK: - Ana pencere

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var search = ""

    var filtered: [AppRow] {
        search.isEmpty ? store.apps
            : store.apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            header
            Divider()
            controls
            Divider()
            listHeader
            list
            Divider()
            footer
        }
        .frame(minWidth: 940, minHeight: 720)
        .background(WindowConfigurator())
    }

    var titleBar: some View {
        HStack {
            Text("TurboMac").font(.title3).bold()
            Text("v\(store.version)").font(.caption2).foregroundStyle(.tertiary)
            if store.caffeineOn {
                Text(store.t("☕️ uyanık tutuluyor", "☕️ keeping awake"))
                    .font(.caption2).foregroundStyle(.pink)
            }
            Spacer()
            LangPicker()
            Button { store.emergencyReset() } label: {
                Text(store.t("🚨 Acil Durum — Sıfırla", "🚨 Emergency Reset"))
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    var header: some View {
        HStack(spacing: 10) {
            StatCard(title: store.t("BELLEK", "MEMORY"), value: store.pct(store.stats.ramPct),
                     tint: store.stats.pressureColor) {
                Bar(value: store.stats.ramPct, tint: store.stats.pressureColor)
                HStack(spacing: 10) {
                    Text("\(bytesStr(store.stats.ramUsed)) / \(bytesStr(store.stats.ramTotal))")
                    Text("\(store.t("Baskı", "Pressure")): \(store.pressureText)")
                    if store.stats.swapUsed > 0 { Text("Swap \(bytesStr(store.stats.swapUsed))") }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            StatCard(title: "GPU", value: store.pct(Double(store.stats.gpuUtil)), tint: .purple) {
                Bar(value: Double(store.stats.gpuUtil), tint: .purple)
                Text("VRAM \(bytesStr(store.stats.gpuMem))").font(.caption2).foregroundStyle(.secondary)
            }
            StatCard(title: "CPU", value: store.pct(store.stats.cpuPct), tint: .blue) {
                Bar(value: store.stats.cpuPct, tint: .blue)
                Text("user \(store.pct(store.stats.cpuUser))  sys \(store.pct(store.stats.cpuSys))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                Toggle(store.t("Açılışta başlat", "Start at login"),
                       isOn: Binding(get: { store.launchAtLogin },
                                     set: { store.toggleLaunchAtLogin($0) }))
                    .toggleStyle(.switch)
                Toggle(store.t("App Nap'i sistem genelinde kapat", "Disable App Nap system-wide"),
                       isOn: Binding(get: { store.globalAppNapOff },
                                     set: { store.toggleGlobalAppNap($0) }))
                    .toggleStyle(.switch)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(store.t(
                    "MAX = uygulama hiç uyutulmaz + en yüksek CPU önceliği (şifre ister) + Mac uyanık tutulur.   Turbo = uygulama hiç uyutulmaz + yüksek öncelik.   Kıs = uygulama yavaş çekirdeklere hapsedilir (~5x yavaş).   Normal = hiç karışma.",
                    "MAX = never put to sleep + highest CPU priority (asks for password) + keeps the Mac awake.   Turbo = never put to sleep + high priority.   Slow = confined to the slow cores (~5x slower).   Normal = leave alone."))
                Text(store.t(
                    "Bu ayarlar yalnızca CPU payını değiştirir — uygulamanın kullandığı belleği azaltmaz.",
                    "These settings only change the CPU share — they do not reduce an app's memory use."))
                    .foregroundStyle(.orange.opacity(0.9))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            PendingBanner()

            BenchCard()

            HStack(spacing: 8) {
                Button(store.t("Belleği Boşalt (purge)", "Free Memory (purge)")) { store.purge() }
                Spacer()
                TextField(store.t("Ara", "Search"), text: $search)
                    .textFieldStyle(.roundedBorder).frame(width: 180)
            }
        }
        .padding(12)
    }

    var listHeader: some View {
        HStack(spacing: 10) {
            Text(store.t("UYGULAMA", "APP")).frame(maxWidth: .infinity, alignment: .leading)
            Text(store.t("BELLEK", "MEMORY")).frame(width: 70, alignment: .trailing)
                .help(store.t("Öncelik ayarı belleği değiştirmez, sadece CPU payını değiştirir.",
                              "Priority settings do not change memory, only the CPU share."))
            Text("CPU").frame(width: 46, alignment: .trailing)
            Text("NICE").frame(width: 36, alignment: .trailing)
            Text(store.t("ÖNCELİK", "PRIORITY")).frame(width: 188, alignment: .center)
            Text(store.t("DURUM", "STATUS")).frame(width: 168, alignment: .leading)
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14).padding(.vertical, 6)
    }

    var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered) { row in
                    HStack(spacing: 10) {
                        if let icon = row.icon {
                            Image(nsImage: icon).resizable().frame(width: 26, height: 26)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.name).font(.system(size: 13, weight: .medium))
                            Text("\(row.bundleID) · \(row.procCount) \(store.t("süreç", "procs"))")
                                .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(bytesStr(row.ram))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 70, alignment: .trailing)
                        Text(store.pct(row.cpu))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(row.cpu > 50 ? .orange : .secondary)
                            .frame(width: 46, alignment: .trailing)
                        Text("\(row.nice)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(row.nice < 0 ? Color.pink : row.nice > 0 ? Color.orange : Color.secondary.opacity(0.5))
                            .frame(width: 36, alignment: .trailing)

                        PriorityPicker(current: row.priority) { store.setPriority(row, $0) }
                            .frame(width: 188)

                        StatusBadge(row: row) { store.restartApp(row) }
                            .frame(width: 168)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(bg(row.priority))
                    Divider().opacity(0.4)
                }
            }
        }
    }

    func bg(_ p: Priority) -> Color {
        switch p {
        case .max: return Color.pink.opacity(0.10)
        case .turbo: return Color.green.opacity(0.09)
        case .low: return Color.orange.opacity(0.09)
        case .normal: return .clear
        }
    }

    var footer: some View {
        HStack {
            Text(store.lastAction.isEmpty
                 ? store.t("Bir uygulamaya seviye seçtikten sonra DURUM sütununa bak: sarıysa uygulamayı kapatıp açman gerekiyor.",
                           "After choosing a level, check the STATUS column: if it's amber, the app needs to be quit and reopened.")
                 : store.lastAction)
                .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            Spacer()
            Text("\(store.turboCount) turbo · \(store.lowCount) \(store.t("kısık", "slowed"))")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}
