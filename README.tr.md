# TurboMac

macOS bellek/GPU izleyici + uygulama bazlı öncelik yöneticisi. Menü çubuğunda yaşar.

## Açmak
- **Xcode:** `TurboMac.xcodeproj` → çift tık → ⌘R
- **Terminal (hızlı):** `./build-cli.sh` → `~/Applications/TurboMac.app` oluşur

## Yapı
```
TurboMac/
  Core/
    Shell.swift          sh() / adminSh() / bytesStr()  — süreç çalıştırma
    Lang.swift           TR/EN dil enum'ı
  System/
    SystemStats.swift    RAM / CPU / GPU okuma (mach + sysctl + ioreg)
    ProcessTable.swift   ps parse + süreç ağacı çıkarma
  Engine/
    Priority.swift       Kıs / Normal / Turbo / MAX seviyeleri
    Policy.swift         App Nap, nice, purge uygulama
    Caffeine.swift       MAX modda Mac'i uyanık tutma
    Benchmark.swift      "gerçekten işe yarıyor mu" ölçümü
    LoginItem.swift      açılışta başlatma (LaunchAgent)
    Relaunch.swift       app'i politika altında yeniden başlatma
  Models/
    AppRow.swift         listedeki satırın modeli
  UI/
    Components.swift     Bar, StatCard, LangPicker, PriorityPicker
    BenchCard.swift      ölçüm kartı
    MenuPanel.swift      menü çubuğu açılır paneli
    ContentView.swift    ana pencere
  Store.swift            tüm durum + aksiyonlar (ObservableObject)
  TurboMacApp.swift      giriş noktası + tek-kopya kilidi

TurboMac.xcodeproj       Xcode projesi
build-cli.sh             Xcode'suz derleme
```

## Nerede ne var
- Yeni bir ölçüm/istatistik → `System/SystemStats.swift`
- Yeni bir hızlandırma yöntemi → `Engine/Policy.swift` + `Engine/Priority.swift`
- Arayüz değişikliği → `UI/`
- Yeni buton/aksiyon → `Store.swift` (mantık) + ilgili `UI/` dosyası
- Yeni metin → ilgili yerde `store.t("türkçe", "english")`

## Açılışta otomatik başlatma
`~/Library/LaunchAgents/com.tuna.turbomac.plist` → `~/Applications/TurboMac.app` işaret eder.
Panelden "Açılışta başlat" anahtarıyla açılıp kapatılır.

## Öncelik seviyeleri
| Seviye | Yaptığı |
|---|---|
| MAX   | App Nap kapalı + `nice -20` (şifre ister) + `caffeinate` ile Mac uyanık |
| Turbo | App Nap kapalı + `nice -10` |
| Normal| Hiçbir şey |
| Kıs   | App'i `taskpolicy -b` altında yeniden başlatır → verimlilik çekirdekleri (~6x yavaş) |

## Önemli teknik not
macOS süreç politikasını (`taskpolicy`) **sadece süreç başlarken** kabul ediyor.
Çalışan bir sürece `taskpolicy -p` uygulamak `rc=0` döner ama hiçbir etkisi yoktur —
ölçümle doğrulandı. Bu yüzden kural koyduktan sonra satırdaki ⟳ ile app'in
yeniden başlatılması gerekiyor. Panelde bunu kendi Mac'inde ölçen
"Gerçekten işe yarıyor mu?" kartı var.

## Acil durum
Sağ üstteki kırmızı buton her şeyi varsayılana döndürür: kurallar, App Nap ayarları
(global + app bazlı), nice değerleri, caffeinate.
