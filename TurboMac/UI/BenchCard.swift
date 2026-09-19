import SwiftUI

// MARK: - Ölçüm kartı

struct BenchCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(store.t("GERÇEKTEN İŞE YARIYOR MU?", "DOES IT ACTUALLY WORK?"))
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                Spacer()
                Button(store.benchRunning ? store.t("Ölçülüyor…", "Running…")
                                          : store.t("Ölç (10 sn)", "Measure (10 s)")) {
                    store.runBench()
                }
                .disabled(store.benchRunning)
            }
            if let b = store.bench {
                HStack(spacing: 16) {
                    metric(store.t("Normal", "Normal"), "\(b.normal)", .green)
                    metric(store.t("Kısık", "Throttled"), "\(b.throttled)", .orange)
                    metric(store.t("Fark", "Diff"), String(format: "%.1fx", b.ratio), .blue)
                }
                Text(b.ratio > 1.5
                     ? store.t("✅ Öncelik mekanizması bu Mac'te çalışıyor — kısılan süreç \(String(format: "%.1f", b.ratio)) kat yavaş.",
                               "✅ The priority mechanism works on this Mac — throttled process is \(String(format: "%.1f", b.ratio))x slower.")
                     : store.t("⚠️ Anlamlı fark ölçülemedi.", "⚠️ No meaningful difference measured."))
                    .font(.caption2)
                Text(b.runtimeWorks
                     ? store.t("✅ Çalışan sürece anında uygulanabiliyor.",
                               "✅ Can be applied to a running process instantly.")
                     : store.t("⚠️ macOS çalışan sürecin politikasını değiştirtmiyor — kural koyduktan sonra app'i ⟳ ile yeniden başlatman gerekiyor.",
                               "⚠️ macOS won't change a running process's policy — after setting a rule, restart the app with ⟳."))
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(store.t("Bu Mac'te önceliklendirmenin gerçekten etki edip etmediğini ölçer.",
                             "Measures whether prioritization actually has an effect on this Mac."))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    func metric(_ title: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 9)).foregroundStyle(.tertiary)
            Text(v).font(.system(.caption, design: .monospaced)).bold().foregroundStyle(c)
        }
    }
}
