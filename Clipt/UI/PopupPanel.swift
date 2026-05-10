import AppKit
import SwiftUI

// ─────────────────────────────────────────────────────────────────────
// PopupPanel
//
//  An NSPanel configured to:
//  • Float above all other windows (level = .floating)
//  • Never steal keyboard focus from the active app
//  • Dismiss itself when the user clicks outside
//  • Have no standard title bar chrome
// ─────────────────────────────────────────────────────────────────────

final class PopupPanel: NSPanel {

    /// Called when a click outside the panel is detected
    var onClickOutside: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor:  Any?

    // ── Init ──────────────────────────────────────────────

    convenience init<Content: View>(rootView: Content) {
        // Borderless, non-activating panel
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 480),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )

        // Always on top of every app
        level = .floating

        // Transparent chrome
        isOpaque          = false
        backgroundColor   = .clear
        hasShadow         = false
        isMovable         = false   // anchored below the menu bar icon

        // Don't appear in ⌘-Tab or Mission Control
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]

        // Key events go to whoever was focused before — panel just observes
        becomesKeyOnlyIfNeeded = true

        // Inject SwiftUI content
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        contentView = hosting
    }

    // ── Show / Hide with outside-click detection ──────────

    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        startMonitoring()
    }

    override func orderFrontRegardless() {
        super.orderFrontRegardless()
        startMonitoring()
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        stopMonitoring()
    }

    // ── Event monitoring ──────────────────────────────────

    private func startMonitoring() {
        stopMonitoring()   // guard against duplicates

        // Global monitor catches clicks in other apps
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.onClickOutside?()
        }

        // Local monitor catches clicks inside our own process but outside the panel
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self = self else { return event }
            if event.window !== self { self.onClickOutside?() }
            return event
        }
    }

    private func stopMonitoring() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor  { NSEvent.removeMonitor(l); localMonitor  = nil }
    }

    // ── Make panel respond to Escape key ──────────────────

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {   // 53 = Escape
            onClickOutside?()
        } else {
            super.keyDown(with: event)
        }
    }

    // Panel must be set as key window to receive keyboard events for search
    override var canBecomeKey: Bool { true }
}
