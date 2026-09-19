<div align="center">

<img src="TurboMac/Resources/icon.png" width="128" alt="TurboMac icon">

# TurboMac

**Stop macOS from throttling the app you're actually waiting on.**

A tiny menu-bar utility that shows live memory, GPU and CPU usage — and lets you
pin individual apps to a speed class, so the long-running job on your other
desktop keeps running at full speed.

[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-black)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

<img src="docs/screenshot.png" width="880" alt="TurboMac main panel">

</div>

---

## The problem

You start a long build, a model download, an AI agent — anything that takes
minutes. You switch to another Space to do something else while it runs.

When you come back, it has barely moved.

This isn't your imagination and it isn't thermal throttling. macOS has a power
saving feature called **App Nap**. When an app's windows are no longer visible —
because you moved to another Space, minimized it, or covered it with another
window — macOS decides nobody is watching and starts cutting it down:

- reduces the CPU time it gets
- coalesces its timers, so work that ran 60×/second now runs about once a second
- drops its disk and network I/O to a background priority tier

Great for a chat app sitting idle. Terrible for the job you're waiting on.

Activity Monitor will show you the slowdown. It gives you no way to stop it.

## What TurboMac does

TurboMac puts a percentage in your menu bar and a per-app speed switch behind it.

| Level | What it does |
|:--|:--|
| **MAX** | App Nap disabled · highest CPU priority (`nice −20`, asks for your password) · keeps the Mac awake while active |
| **Turbo** | App Nap disabled · high CPU priority (`nice −10`) |
| **Normal** | Nothing at all. Apps with no rule are never touched. |
| **Slow** | Confines the app to the efficiency cores — about **5× slower**. For things that just need to tick along in the background. |

Rules are stored per bundle identifier, so they survive quitting the app,
restarting TurboMac, and rebooting.

Everything is also reachable from the menu bar dropdown: live gauges, your
active rules, the five biggest memory consumers, and the emergency reset.

## Honest about what works

Most "Mac optimizer" apps ship buttons that do nothing measurable. This one
ships a benchmark so you don't have to trust the README.

Press **Measure (10 s)** and TurboMac runs a CPU-bound loop three ways on
*your* machine, then reports the numbers. On an M4 (macOS 26):

| Run | Iterations in 3 s |
|:--|--:|
| Normal | 34,054 |
| Started under background policy | 5,466 |
| **Difference** | **6.2× slower** |

That is what "Slow" is actually buying you, measured rather than claimed.

The same benchmark also uncovered something that changes how the app works:

> **macOS only assigns a process's speed class while that process is starting up.**
> Applying a policy to an already-running process returns success and then does
> absolutely nothing — a new thread spawned inside that process stays throttled
> too (6,188 vs 16,251 iterations).

So TurboMac does **not** pretend a rule took effect the moment you click it.
Each row shows its real state:

- 🟢 **Active** — the setting is fully applied
- 🟠 **Quit & reopen** — clickable; the app has to restart before the setting is real

It knows which is which by comparing when you set the rule against the app's
actual launch time. A banner at the top offers to restart everything that's
still pending, and the confirmation dialog explains in plain language why a
restart is needed instead of just demanding one.

TurboMac never force-quits an app. If an app refuses to close — usually because
it's asking about unsaved work — the restart is abandoned and you're told what
happened. Your work is never at risk.

## Emergency Reset

One red button, top right. It asks for confirmation, then puts your Mac back
exactly as it was:

- removes every rule
- reverts every App Nap setting, per-app and system-wide
- resets every process priority it changed back to 0
- releases the wake lock
- refreshes the preferences daemon so it all takes effect immediately

No leftovers, no config file to hunt down.

## Install

**Download** — grab the latest `.app` from
[Releases](https://github.com/tunaarikaya/TurboMac/releases), drag it to
`/Applications`, and open it.

The app is signed ad-hoc, not notarized. On first launch macOS will refuse it;
right-click the app → **Open**, then confirm. Once only.

**Build from source** — no dependencies, nothing to install:

```bash
git clone https://github.com/tunaarikaya/TurboMac.git
cd TurboMac
./build-cli.sh          # → ~/Applications/TurboMac.app
```

Or open `TurboMac.xcodeproj` and press ⌘R.

Requires macOS 15 or later. Universal, but developed and measured on Apple silicon.

## Start at login

Toggle **Start at login** in the panel. TurboMac writes a LaunchAgent to
`~/Library/LaunchAgents/com.tuna.turbomac.plist` pointing at the installed copy.

It deliberately refuses to enable this when you're running a debug build from
Xcode's DerivedData — that path gets cleaned up and would leave you with a
broken login item.

## Permissions

TurboMac asks for your administrator password in exactly two cases, each time
you trigger them:

- **MAX** — only `root` may assign a negative `nice` value
- **Free Memory (purge)** — `/usr/sbin/purge` requires root

Everything else runs as you. No helper tool is installed, no daemon runs as
root, no password is ever stored. Every privileged action goes through the
standard macOS authorization dialog.

## What it can't do

Being straight about the limits:

- **It can't reduce an app's memory use.** Speed levels change the CPU share,
  nothing else. macOS gives no API to reclaim another app's memory. Your options
  are to quit the app or use system-wide `purge`.
- **It can't prioritize the GPU.** macOS exposes no per-process GPU scheduling.
  GPU usage is displayed, not controlled.
- **It can't retune a running process.** See above — this is a macOS constraint,
  which is why restarts exist.
- **High Power Mode isn't available on most Macs.** It's limited to specific
  high-end MacBook Pro models, so TurboMac doesn't offer a switch that would do
  nothing on your machine.

## How it's built

Plain SwiftUI. No third-party dependencies, no package manager, no build system
beyond Xcode. About 1,100 lines across 17 files.

```
TurboMac/
├── Core/
│   ├── Shell.swift          Process execution, privileged commands
│   └── Lang.swift           Language enum
├── System/
│   ├── SystemStats.swift    RAM / CPU / GPU sampling (mach, sysctl, ioreg)
│   └── ProcessTable.swift   ps parsing, process-tree walking
├── Engine/
│   ├── Priority.swift       The four speed levels
│   ├── Policy.swift         App Nap, nice, purge
│   ├── Caffeine.swift       Wake lock for MAX
│   ├── Benchmark.swift      The "does it actually work" measurement
│   ├── LoginItem.swift      LaunchAgent management
│   └── Relaunch.swift       Restarting an app under a policy
├── Models/AppRow.swift
├── UI/                      Components, BenchCard, MenuPanel, ContentView
├── Store.swift              State and actions
└── TurboMacApp.swift        Entry point, single-instance guard
```

Two design details worth knowing if you're reading the source:

**Process trees, not processes.** Chrome, Electron apps and terminals do their
real work in helper processes. Applying a rule only to the main process would
accomplish nothing, so TurboMac walks the full `ppid` tree and applies the level
to every descendant. That's also why the memory and CPU figures are higher —
and more honest — than a per-process view.

**No unread pipes.** `sh()` sends stderr to `/dev/null` rather than an unread
`Pipe`. An unread pipe deadlocks the child process once 64 KB accumulates, which
would hang the UI. Where stderr actually matters — detecting that you cancelled
a password prompt — `shFull()` drains both pipes concurrently.

## Contributing

Issues and pull requests welcome. If you're proposing a new optimization, please
include a measurement showing it does something — that's the whole premise of
this app.

The UI ships in English and Turkish, switchable from the header. Strings are
inline `store.t("türkçe", "english")` calls; adding a language means extending
the `Lang` enum.

## License

MIT — see [LICENSE](LICENSE).

---

<div align="center">
<sub>Türkçe dokümantasyon için: <a href="README.tr.md">README.tr.md</a></sub>
</div>
