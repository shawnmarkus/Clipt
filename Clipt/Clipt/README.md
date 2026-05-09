# Clipt — macOS Menu Bar Clipboard Manager

A lightweight, native macOS clipboard history manager that lives in the menu bar.  
Built with **Swift + SwiftUI + AppKit**. No Electron, no web views — pure native.

---

## Features

| Feature | Detail |
|---|---|
| Menu bar icon | Click to open history popup; always on top of all apps |
| Clipboard history | Last N items (text, URLs, images, code, files) |
| Search & filter | Live search + filter by content type |
| Pin items | Pinned items survive auto-eviction and manual clear |
| Memory limits | Two independent limits: entry count AND total MB |
| LRU eviction | Oldest unpinned item dropped when any limit is exceeded |
| Global hotkey | Open popup from any app with ⌘⇧V |
| Runs as daemon | Launches at login via SMAppService (macOS 13+) or LaunchAgent plist |
| Onboarding | First-run wizard requests permissions step-by-step |
| Settings window | Full in-app settings: memory, permissions, daemon paths, shortcuts, privacy |
| Privacy | Ignore password managers, mask credit card numbers, exclude any app |

---

## Project structure

```
Clipt/
├── CliptApp.swift               # @main SwiftUI entry point
├── AppDelegate.swift            # NSStatusItem, popup lifecycle, hotkey wiring
│
├── Core/
│   ├── ClipItem.swift           # Data model + NSPasteboard capture
│   ├── ClipboardStore.swift     # In-memory stack, eviction, JSON persistence
│   ├── ClipboardMonitor.swift   # Background 200ms polling thread
│   └── AppConfig.swift          # All settings, UserDefaults-backed
│
├── UI/
│   ├── PopupPanel.swift         # NSPanel subclass — floating, always on top
│   ├── PopupView.swift          # SwiftUI popup content (list, search, tabs)
│   ├── SettingsView.swift       # Tabbed settings window (6 tabs)
│   └── OnboardingView.swift     # First-run 3-step wizard
│
├── System/
│   ├── HotkeyManager.swift      # Carbon RegisterEventHotKey global shortcuts
│   ├── PermissionChecker.swift  # Live permission states (accessibility, notifications, login)
│   ├── LaunchAtLoginManager.swift # SMAppService (macOS 13+) + LaunchAgent plist fallback
│   ├── NotificationManager.swift  # UNUserNotificationCenter capture toasts
│   └── Logger.swift             # Dual-sink logger → os.log + ~/Library/Logs/Clipt/clipt.log
│
└── Resources/
    ├── Info.plist               # LSUIElement=true (no Dock icon)
    ├── Clipt.entitlements       # App Sandbox + required exceptions
    └── com.clipt.daemon.plist   # LaunchAgent template (macOS 12 fallback)
```

---

## Xcode setup

### 1. Create the project

1. Open Xcode → **File → New → Project → macOS → App**
2. Product Name: `Clipt`
3. Bundle Identifier: `com.yourname.clipt` *(replace with your Team prefix)*
4. Interface: **SwiftUI**
5. Language: **Swift**
6. **Uncheck** "Create Tests" for now

### 2. Copy source files

Drag all `.swift` files into the Xcode project, matching the folder structure above.  
Make sure **"Copy items if needed"** is checked and **"Add to target: Clipt"** is ticked.

### 3. Replace Info.plist

Xcode 13+ generates `Info.plist` as a build setting, not a file.  
To use our custom `Info.plist`:

1. Select the Clipt target → **Build Settings** → search `INFOPLIST_FILE`
2. Set it to `Clipt/Resources/Info.plist`
3. Set **"Generate Info.plist File"** to `NO`

### 4. Set entitlements

1. Select the Clipt target → **Signing & Capabilities**
2. Set **Entitlements File** to `Clipt/Resources/Clipt.entitlements`
3. Add the **App Sandbox** capability (tick it on)
4. For macOS 13+ launch-at-login: add **Login Items & Extensions** capability

### 5. Link Carbon framework

`HotkeyManager.swift` uses the Carbon `RegisterEventHotKey` API.

1. Select the Clipt target → **Build Phases → Link Binary With Libraries**
2. Click **+** → search `Carbon` → add `Carbon.framework`

### 6. Update bundle identifier

In `Info.plist` and `Clipt.entitlements`, replace every occurrence of  
`com.yourname.clipt` with your actual reverse-DNS bundle ID.

---

## Building & running

```bash
# Open in Xcode
open Clipt/Clipt.xcodeproj

# Or build from the command line (after setup)
xcodebuild -scheme Clipt -configuration Debug build
```

**First run:** The onboarding wizard will appear and guide you through permissions.

---

## System paths (runtime)

| Path | Purpose |
|---|---|
| `/Applications/Clipt.app` | Application bundle |
| `~/Library/Application Support/Clipt/history.json` | Clipboard history (JSON) |
| `~/Library/Application Support/Clipt/` | Config directory |
| `~/Library/Logs/Clipt/clipt.log` | App log (rotated at 5 MB) |
| `~/Library/LaunchAgents/com.clipt.daemon.plist` | LaunchAgent (macOS 12 fallback) |

---

## Daemon — how launch-at-login works

### macOS 13+ (recommended)

```swift
// Enable
try SMAppService.mainApp.register()

// Disable
try SMAppService.mainApp.unregister()
```

No plist file is written. macOS manages it entirely.

### macOS 12 and earlier (LaunchAgent plist)

`LaunchAtLoginManager.swift` writes `com.clipt.daemon.plist` to  
`~/Library/LaunchAgents/` and calls `launchctl load -w` to activate it.

The plist sets `KeepAlive.SuccessfulExit = false` which tells `launchd`  
to restart the process automatically on crash — this is the daemon restart  
behaviour controlled by the "Restart on crash" toggle in Settings.

### Detecting daemon vs direct launch

```swift
// The LaunchAgent sets CLIPT_DAEMON=1 in the environment.
// Use this to skip onboarding when launched by launchd.
let isDaemon = ProcessInfo.processInfo.environment["CLIPT_DAEMON"] == "1"
```

---

## Memory limit & eviction algorithm

The store maintains two independent limits simultaneously.  
Every time a new item is added:

```
while items.count > maxEntries  →  evict oldest unpinned
while totalBytes  > maxBytes    →  evict oldest unpinned
```

**Eviction order:** The array is kept newest-first (index 0 = most recent).  
Eviction scans from the **end** (oldest) and removes the first unpinned item it finds.  
If all items are pinned, the oldest pinned item is removed to honour the hard limit.

---

## Default keyboard shortcuts

| Action | Default |
|---|---|
| Open / close popup | `⌘ ⇧ V` |
| Paste last item directly | `⌘ ⇧ C` |
| Open Settings | `⌘ ,` |
| Clear all history | `⌘ ⇧ ⌫` |

Shortcuts are registered via Carbon `RegisterEventHotKey` and fire  
even when Clipt has no focused window (true global shortcuts).

---

## Permissions required

| Permission | Why | Required? |
|---|---|---|
| Accessibility | Detect frontmost app; auto-paste | Optional but recommended |
| Notifications | Capture toasts | Optional |
| Login Items | Launch at login | Optional |
| Clipboard read | Core clipboard monitoring | Always allowed on macOS |

---

## Distribution

### Direct download (.dmg — notarized)

1. Build for Release with a Developer ID certificate
2. `xcrun notarytool submit Clipt.app.zip --apple-id ... --password ... --team-id ...`
3. `xcrun stapler staple Clipt.app`
4. Wrap in a DMG with `create-dmg` or Disk Utility

### Mac App Store

1. Set sandbox entitlements (already included in `Clipt.entitlements`)
2. Archive with a Distribution certificate
3. Upload via Xcode Organizer or `altool`

---

## Uninstalling

The Settings → Daemon tab has an "Uninstall Clipt" button that:

1. Calls `SMAppService.mainApp.unregister()` (or removes the LaunchAgent plist)
2. Deletes `~/Library/Application Support/Clipt/`
3. Moves `Clipt.app` to the Trash
4. Terminates the process

Manual uninstall:

```bash
launchctl unload -w ~/Library/LaunchAgents/com.clipt.daemon.plist 2>/dev/null
rm -rf ~/Library/LaunchAgents/com.clipt.daemon.plist
rm -rf ~/Library/Application\ Support/Clipt
rm -rf ~/Library/Logs/Clipt
rm -rf /Applications/Clipt.app
```
