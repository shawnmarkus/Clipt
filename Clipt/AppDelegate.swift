import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {

    static private(set) var shared: AppDelegate!
    
    // ── Shared singletons ────────────────────────────────────────────
    
    let config  = AppConfig.shared
    let store   = ClipboardStore.shared
    
    
    override init() {
            super.init()
            AppDelegate.shared = self
    }

    // ── Internal references ──────────────────────────────────────────
    private var statusItem:       NSStatusItem?
    private var popupPanel:       PopupPanel?
    private var settingsWindow:   NSWindow?          // managed manually
    private var monitor:          ClipboardMonitor?
    private var hotkeyManager:    HotkeyManager?
    private var cancellables      = Set<AnyCancellable>()
    private var isActive          = false   // guard against duplicate activate() calls

    // ────────────────────────────────────────────────────────────────
    // MARK: - Launch
    // ────────────────────────────────────────────────────────────────

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon

        CliptLog.logStartupInfo()
        buildPopupPanel()

        // ── FIX 1: .dropFirst() prevents the publisher from firing
        //    immediately — we make the single explicit activate() call below.
        config.$isEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                enabled ? self?.activate() : self?.deactivate()
            }
            .store(in: &cancellables)

        config.$showMenuBarIcon
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                guard let self else { return }
                if show && config.isEnabled { ensureStatusItem() }
                else { removeStatusItem() }
            }
            .store(in: &cancellables)

        // Single boot call — no double-fire possible
        if config.isEnabled { activate() }

        OnboardingWindowController.showIfNeeded()
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Activate / Deactivate
    // ────────────────────────────────────────────────────────────────

    private func activate() {
        guard !isActive else { return }   // prevent hotkey storm
        isActive = true
        if config.showMenuBarIcon { ensureStatusItem() }
        startMonitor()
        registerHotkey()
    }

    private func deactivate() {
        guard isActive else { return }
        isActive = false
        stopMonitor()
        unregisterHotkey()
        removeStatusItem()
        closePopup()
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Status Item
    // ────────────────────────────────────────────────────────────────

    private func ensureStatusItem() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem?.button {
            btn.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                accessibilityDescription: "Clipt")
            btn.image?.isTemplate = true
            btn.action = #selector(handleIconClick)
            btn.target = self
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func handleIconClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            togglePopup()
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        // Set target=self only on items AppDelegate handles
        let open    = NSMenuItem(title: "Open Clipt",    action: #selector(togglePopup),  keyEquivalent: "")
        let clear   = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        let settings = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        open.target     = self
        clear.target    = self
        settings.target = self

        // Quit: target must be nil so the event travels the responder
        // chain to NSApp.terminate(_:). Setting target=self greys it out
        // because AppDelegate doesn't implement terminate(_:).
        let quit = NSMenuItem(title: "Quit Clipt", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        quit.target = nil

        menu.addItem(open)
        menu.addItem(clear)
        menu.addItem(.separator())
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(quit)

        statusItem?.menu = menu
        sender.performClick(nil)
        DispatchQueue.main.async { self.statusItem?.menu = nil }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Popup
    // ────────────────────────────────────────────────────────────────

    private func buildPopupPanel() {
        let content = PopupView(onClose: { [weak self] in self?.closePopup() })
            .environmentObject(store)
            .environmentObject(config)
        popupPanel = PopupPanel(rootView: content)
        popupPanel?.onClickOutside = { [weak self] in self?.closePopup() }
    }

    @objc func togglePopup() {
        guard let panel = popupPanel else { return }
        panel.isVisible ? closePopup() : openPopup()
    }

    private func openPopup() {
        guard let panel = popupPanel else { return }

        if let btn = statusItem?.button, let win = btn.window {
            let btnRect = win.convertToScreen(btn.frame)
            let x       = btnRect.midX - panel.frame.width / 2
            let y       = btnRect.minY - panel.frame.height - 6
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }

        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopup() {
        popupPanel?.orderOut(nil)
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Settings window  (FIX 2 — no private API, fully managed)
    // ────────────────────────────────────────────────────────────────

    @objc func openSettings() {
        closePopup()

        // Re-use existing window if already open
        if let win = settingsWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = SettingsView()
            .environmentObject(store)
            .environmentObject(config)

        let win = NSWindow(
            contentRect:  NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask:    [.titled, .closable, .miniaturizable],
            backing:      .buffered,
            defer:        false
        )
        win.title                  = "Clipt Settings"
        win.contentView            = NSHostingView(rootView: content)
        win.isReleasedWhenClosed   = false   // keep alive for re-show
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = win
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Monitor
    // ────────────────────────────────────────────────────────────────

    private func startMonitor() {
        guard monitor == nil else { return }
        monitor = ClipboardMonitor(store: store)
        monitor?.start()
    }

    private func stopMonitor() {
        monitor?.stop()
        monitor = nil
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Hotkey  (FIX 1 — always unregister before re-registering)
    // ────────────────────────────────────────────────────────────────

    private func registerHotkey() {
        unregisterHotkey()   // ensure clean state before registering
        hotkeyManager = HotkeyManager()
        hotkeyManager?.register(keyCombo: config.openPopupShortcut) { [weak self] in
            DispatchQueue.main.async { self?.togglePopup() }
        }
    }

    private func unregisterHotkey() {
        hotkeyManager?.unregisterAll()
        hotkeyManager = nil
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Actions
    // ────────────────────────────────────────────────────────────────

    @objc func clearHistory() {
        store.clearAll()
    }
}
