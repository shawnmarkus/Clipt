import AppKit

// ─────────────────────────────────────────────────────────────────────
// ClipboardMonitor
//
//  Polls NSPasteboard every 200 ms on a background thread.
//  Detects changes via changeCount (integer NSPasteboard provides).
//  On change, captures a ClipItem and hands it to ClipboardStore
//  on the main thread.
// ─────────────────────────────────────────────────────────────────────

final class ClipboardMonitor {

    private weak var store:     ClipboardStore?
    private var timer:          DispatchSourceTimer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let queue = DispatchQueue(label: "com.clipt.monitor", qos: .utility)

    /// Apps whose clipboard activity we never capture (e.g. password managers)
    private let excludedBundleIDs: Set<String> = [
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.bitwarden.desktop",
        "com.dashlane.dashlane",
        "com.lastpass.lastpass",
        "in.sinew.Enpass-Desktop",
    ]

    init(store: ClipboardStore) {
        self.store = store
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Lifecycle
    // ─────────────────────────────────────────────────────

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.2, repeating: 0.2)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
        print("[ClipboardMonitor] Started — polling every 200 ms")
    }

    func stop() {
        timer?.cancel()
        timer = nil
        print("[ClipboardMonitor] Stopped")
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Poll
    // ─────────────────────────────────────────────────────

    private func tick() {
        let pb = NSPasteboard.general
        let current = pb.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // FIX 3: if Clipt itself just wrote to the pasteboard, skip this change
        if store?.suppressNextCapture == true {
            store?.suppressNextCapture = false
            return
        }

        // Skip if the source app is excluded (password managers, etc.)
        if let frontApp = frontmostBundleID(), excludedBundleIDs.contains(frontApp) {
            return
        }

        guard let item = ClipItem.from(pasteboard: pb) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.store?.add(item)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────

    private func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
