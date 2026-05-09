import Foundation
import Combine

// ─────────────────────────────────────────────────────────────────────
// AppConfig
//
//  Single source of truth for every user-configurable preference.
//  Uses @Published so SwiftUI settings views stay in sync automatically.
//  All values persist to UserDefaults (standard suite).
// ─────────────────────────────────────────────────────────────────────

final class AppConfig: ObservableObject {

    static let shared = AppConfig()

    private let defaults = UserDefaults.standard

    // ── Master switch ─────────────────────────────────────
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    // ── Menu bar ──────────────────────────────────────────
    @Published var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    @Published var showCaptureBadge: Bool {
        didSet { defaults.set(showCaptureBadge, forKey: Keys.showCaptureBadge) }
    }

    // ── Memory & storage ──────────────────────────────────

    /// Maximum number of history entries (triggers oldest-first eviction)
    @Published var maxEntries: Int {
        didSet { defaults.set(maxEntries, forKey: Keys.maxEntries) }
    }

    /// Maximum total memory in megabytes (triggers oldest-first eviction)
    @Published var maxMemoryMB: Int {
        didSet { defaults.set(maxMemoryMB, forKey: Keys.maxMemoryMB) }
    }

    @Published var pinnedItemsIgnoreLimits: Bool {
        didSet { defaults.set(pinnedItemsIgnoreLimits, forKey: Keys.pinnedItemsIgnoreLimits) }
    }

    // Encoded as string: "never" | "restart" | "daily" | "weekly"
    @Published var retentionPolicy: String {
        didSet { defaults.set(retentionPolicy, forKey: Keys.retentionPolicy) }
    }

    // ── Daemon / startup ─────────────────────────────────
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    @Published var startSilently: Bool {
        didSet { defaults.set(startSilently, forKey: Keys.startSilently) }
    }

    @Published var restartOnCrash: Bool {
        didSet { defaults.set(restartOnCrash, forKey: Keys.restartOnCrash) }
    }

    // ── Shortcuts — stored as "⌘⇧V" style strings ────────
    @Published var openPopupShortcut: KeyCombo {
        didSet { defaults.set(openPopupShortcut.encoded, forKey: Keys.openPopupShortcut) }
    }

    @Published var pasteLastShortcut: KeyCombo {
        didSet { defaults.set(pasteLastShortcut.encoded, forKey: Keys.pasteLastShortcut) }
    }

    // ── Privacy ───────────────────────────────────────────
    @Published var ignorePasswordManagers: Bool {
        didSet { defaults.set(ignorePasswordManagers, forKey: Keys.ignorePasswordManagers) }
    }

    @Published var maskCreditCards: Bool {
        didSet { defaults.set(maskCreditCards, forKey: Keys.maskCreditCards) }
    }

    @Published var excludedAppBundleIDs: [String] {
        didSet { defaults.set(excludedAppBundleIDs, forKey: Keys.excludedApps) }
    }

    // ── System paths (read-only, informational) ───────────
    var appBundlePath:    String { Bundle.main.bundlePath }
    var supportDirPath:   String {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return url.appendingPathComponent("Clipt").path
    }
    var logFilePath:      String {
        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return url.appendingPathComponent("Logs/Clipt/clipt.log").path
    }
    var launchAgentPath:  String {
        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return url.appendingPathComponent("LaunchAgents/com.clipt.daemon.plist").path
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Init
    // ─────────────────────────────────────────────────────

    private init() {
        let d = UserDefaults.standard
        isEnabled               = d.object(forKey: Keys.isEnabled)               as? Bool   ?? true
        showMenuBarIcon         = d.object(forKey: Keys.showMenuBarIcon)         as? Bool   ?? true
        showCaptureBadge        = d.object(forKey: Keys.showCaptureBadge)        as? Bool   ?? false
        maxEntries              = d.object(forKey: Keys.maxEntries)              as? Int    ?? 100
        maxMemoryMB             = d.object(forKey: Keys.maxMemoryMB)             as? Int    ?? 128
        pinnedItemsIgnoreLimits = d.object(forKey: Keys.pinnedItemsIgnoreLimits) as? Bool   ?? true
        retentionPolicy         = d.string(forKey: Keys.retentionPolicy)                    ?? "restart"
        launchAtLogin           = d.object(forKey: Keys.launchAtLogin)           as? Bool   ?? false
        startSilently           = d.object(forKey: Keys.startSilently)           as? Bool   ?? true
        restartOnCrash          = d.object(forKey: Keys.restartOnCrash)          as? Bool   ?? true
        ignorePasswordManagers  = d.object(forKey: Keys.ignorePasswordManagers)  as? Bool   ?? true
        maskCreditCards         = d.object(forKey: Keys.maskCreditCards)         as? Bool   ?? true
        excludedAppBundleIDs    = d.stringArray(forKey: Keys.excludedApps)                  ?? []

        if let enc = d.string(forKey: Keys.openPopupShortcut) {
            openPopupShortcut = KeyCombo(encoded: enc) ?? .defaultOpen
        } else {
            openPopupShortcut = .defaultOpen
        }

        if let enc = d.string(forKey: Keys.pasteLastShortcut) {
            pasteLastShortcut = KeyCombo(encoded: enc) ?? .defaultPasteLast
        } else {
            pasteLastShortcut = .defaultPasteLast
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Keys
    // ─────────────────────────────────────────────────────

    private enum Keys {
        static let isEnabled               = "isEnabled"
        static let showMenuBarIcon         = "showMenuBarIcon"
        static let showCaptureBadge        = "showCaptureBadge"
        static let maxEntries              = "maxEntries"
        static let maxMemoryMB             = "maxMemoryMB"
        static let pinnedItemsIgnoreLimits = "pinnedItemsIgnoreLimits"
        static let retentionPolicy         = "retentionPolicy"
        static let launchAtLogin           = "launchAtLogin"
        static let startSilently           = "startSilently"
        static let restartOnCrash          = "restartOnCrash"
        static let openPopupShortcut       = "openPopupShortcut"
        static let pasteLastShortcut       = "pasteLastShortcut"
        static let ignorePasswordManagers  = "ignorePasswordManagers"
        static let maskCreditCards         = "maskCreditCards"
        static let excludedApps            = "excludedApps"
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - KeyCombo (lightweight shortcut model)
// ─────────────────────────────────────────────────────────────────────

struct KeyCombo: Equatable {
    let modifiers: NSEvent.ModifierFlags   // .command, .shift, etc.
    let keyCode:   UInt32                  // Carbon key code
    let display:   String                  // e.g. "⌘⇧V"
    var encoded:   String { display }      // stored as the display string for simplicity

    static let defaultOpen     = KeyCombo(modifiers: [.command, .shift], keyCode: 9,  display: "⌘⇧V")
    static let defaultPasteLast = KeyCombo(modifiers: [.command, .shift], keyCode: 8, display: "⌘⇧C")

    init(modifiers: NSEvent.ModifierFlags, keyCode: UInt32, display: String) {
        self.modifiers = modifiers
        self.keyCode   = keyCode
        self.display   = display
    }

    init?(encoded: String) {
        // Minimal decoder — extend for a full shortcut recorder
        switch encoded {
        case "⌘⇧V": self = .defaultOpen
        case "⌘⇧C": self = .defaultPasteLast
        default:    return nil
        }
    }
}

import AppKit
