import AppKit
import Combine
import UserNotifications
import ServiceManagement

// ─────────────────────────────────────────────────────────────────────
// PermissionChecker
//
//  ObservableObject that exposes the live permission states the
//  Settings → Permissions tab needs to display.
//  Call refresh() to re-query; macOS doesn't notify us of changes
//  so we re-check when the settings window gains focus.
// ─────────────────────────────────────────────────────────────────────

final class PermissionChecker: ObservableObject {

    @Published var accessibilityGranted:  Bool = false
    @Published var notificationsGranted:  Bool = false
    @Published var loginItemRegistered:   Bool = false

    init() { refresh() }

    // ─────────────────────────────────────────────────────
    // MARK: - Refresh (query all at once)
    // ─────────────────────────────────────────────────────

    func refresh() {
        checkAccessibility()
        checkNotifications()
        checkLoginItem()
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Accessibility
    // ─────────────────────────────────────────────────────

    private func checkAccessibility() {
        // AXIsProcessTrustedWithOptions — passing false means "don't prompt,
        // just tell me the current state".
        let opts: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(opts)
    }

    /// Open System Settings → Privacy & Security → Accessibility
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Request accessibility by prompting the user (shows the system dialog).
    func requestAccessibility() {
        let opts: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Notifications
    // ─────────────────────────────────────────────────────

    private func checkNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationsGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestNotifications() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                DispatchQueue.main.async { self?.notificationsGranted = granted }
            }
    }

    /// Open System Settings → Notifications → Clipt
    func openNotificationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
        NSWorkspace.shared.open(url)
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Login Item (SMAppService)
    // ─────────────────────────────────────────────────────

    private func checkLoginItem() {
        if #available(macOS 13.0, *) {
            loginItemRegistered = SMAppService.mainApp.status == .enabled
        } else {
            // Fallback: check LaunchAgents directory for our plist
            let plistURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("LaunchAgents/com.clipt.daemon.plist")
            loginItemRegistered = FileManager.default.fileExists(atPath: plistURL.path)
        }
    }

    func openLoginItemsSettings() {
        if #available(macOS 13.0, *) {
            let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
            NSWorkspace.shared.open(url)
        } else {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.users")!
            NSWorkspace.shared.open(url)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Clipboard (informational only)
    // ─────────────────────────────────────────────────────
    //
    //  macOS allows clipboard read without explicit permission.
    //  On macOS 14+ the OS shows a one-time "Clipt wants to access
    //  your clipboard" banner — we can't control that but we inform
    //  the user about it in the Permissions tab.

    var clipboardAccessNote: String {
        "macOS allows clipboard read without a permission prompt. On macOS 14+ a system banner may appear on first capture — this is normal."
    }
}
