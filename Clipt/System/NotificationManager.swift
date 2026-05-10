import UserNotifications
import AppKit

// ─────────────────────────────────────────────────────────────────────
// NotificationManager
//
//  Thin wrapper around UNUserNotificationCenter for showing a brief
//  toast when a clipboard item is captured.  Only fires when:
//    • notificationsGranted == true
//    • config.showCaptureBadge == true
// ─────────────────────────────────────────────────────────────────────

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Public API
    // ─────────────────────────────────────────────────────

    func notifyCaptured(_ item: ClipItem) {
        guard AppConfig.shared.showCaptureBadge else { return }

        let content = UNMutableNotificationContent()
        content.title = "Clipt"
        content.subtitle = captureSubtitle(for: item)
        content.body = previewText(for: item)
        content.sound = .none     // silent — we don't want to be annoying

        // Auto-dismiss after 2 seconds using a very short time-interval trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request  = UNNotificationRequest(
            identifier: "clipt.capture.\(item.id.uuidString)",
            content:    content,
            trigger:    trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationManager] Error: \(error)")
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: - UNUserNotificationCenterDelegate
    // ─────────────────────────────────────────────────────

    // Show notification even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner])
    }

    // Tapping the notification opens the popup
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler handler: @escaping () -> Void) {
        AppDelegate.shared.togglePopup()
        handler()
    }
    
    // ─────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────

    private func captureSubtitle(for item: ClipItem) -> String {
        switch item.type {
        case .text:  return "Text copied"
        case .url:   return "URL copied"
        case .image: return "Image copied"
        case .code:  return "Code snippet copied"
        case .file:  return "File path copied"
        }
    }

    private func previewText(for item: ClipItem) -> String {
        switch item.type {
        case .text, .url, .code:
            let raw = item.text ?? ""
            return raw.count > 60 ? String(raw.prefix(60)) + "…" : raw
        case .image:
            return "Image · \(formattedBytes(item.byteSize))"
        case .file:
            return item.filePaths?.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File"
        }
    }

    private func formattedBytes(_ b: Int) -> String {
        if b < 1024 { return "\(b) B" }
        if b < 1024*1024 { return "\(b/1024) KB" }
        return "\(b/(1024*1024)) MB"
    }
}
