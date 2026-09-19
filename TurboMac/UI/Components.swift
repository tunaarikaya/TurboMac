import SwiftUI

// MARK: - UI parçaları

struct Bar: View {
    var value: Double
    var tint: Color
    var height: CGFloat = 8
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule().fill(tint.gradient)
                    .frame(width: Swift.max(3, geo.size.width * Swift.min(Swift.max(value, 0), 100) / 100))
            }
        }
        .frame(height: height)
    }
}

struct StatCard<Content: View>: View {
    let title: String
    let value: String
    let tint: Color
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.system(.title3, design: .rounded)).bold().foregroundStyle(tint)
            }
            content
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LangPicker: View {
    @EnvironmentObject var store: Store
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Lang.allCases, id: \.self) { l in
                Button { store.lang = l } label: {
                    Text(l.flag)
                        .font(.system(size: 10, weight: store.lang == l ? .bold : .regular))
                        .frame(width: 28, height: 18)
                        .background(store.lang == l ? Color.accentColor.opacity(0.25)
                                                    : Color.primary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(store.lang == l ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PriorityPicker: View {
    @EnvironmentObject var store: Store
    let current: Priority
    let onPick: (Priority) -> Void
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Priority.allCases, id: \.self) { p in
                Button { onPick(p) } label: {
                    Text(store.label(p))
                        .font(.system(size: 10, weight: current == p ? .bold : .regular))
                        .frame(width: 44, height: 20)
                        .background(current == p ? p.color.opacity(0.22) : Color.primary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(current == p ? p.color : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Durum rozeti
// Bir satırda seçilen seviyenin GERÇEKTEN aktif olup olmadığını düz Türkçe söyler.
// macOS süreç politikasını yalnızca uygulama açılırken kabul ettiği için,
// kural konduktan sonra uygulama kapatılıp açılana kadar ayar tam geçerli değildir.

struct StatusBadge: View {
    @EnvironmentObject var store: Store
    let row: AppRow
    let onRestart: () -> Void

    var body: some View {
        if !row.hasRule {
            EmptyView()
        } else if row.needsRestart {
            Button(action: onRestart) {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9))
                    Text(store.t("Kapat ve aç", "Quit & reopen"))
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.orange.opacity(0.22), in: Capsule())
                .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .help(store.t("Ayar henüz tam geçerli değil. Tıkla — uygulama kapanıp ayar aktif halde tekrar açılsın.",
                          "The setting isn't fully active yet. Click to quit and reopen the app with it applied."))
        } else {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 9))
                Text(store.t("Aktif", "Active")).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.green)
            .help(store.t("Ayar tam olarak uygulanmış durumda.", "The setting is fully applied."))
        }
    }
}

// MARK: - Bekleyen yeniden başlatma şeridi

struct PendingBanner: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let pending = store.pendingRestart
        if !pending.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t("\(pending.count) uygulamada ayar henüz tam geçerli değil",
                                 "\(pending.count) app(s) not fully switched over yet"))
                        .font(.system(size: 11, weight: .semibold))
                    Text(store.t("macOS hız ayarını yalnızca uygulama açılırken kabul ediyor. \(pending.map(\.name).joined(separator: ", ")) kapatılıp açılmalı.",
                                 "macOS only applies the speed setting while an app starts up. \(pending.map(\.name).joined(separator: ", ")) must be quit and reopened."))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button(store.t("Hepsini kapat ve aç", "Quit & reopen all")) {
                    for row in pending { store.restartApp(row) }
                }
            }
            .padding(10)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Pencere ayarları
// Boyut/konumun oturumlar arası hatırlanmasını sağlar.

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.setFrameAutosaveName("TurboMacMainWindow")
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
