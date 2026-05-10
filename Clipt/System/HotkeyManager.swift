import Carbon.HIToolbox
import AppKit

// ─────────────────────────────────────────────────────────────────────
// HotkeyManager
//
//  Registers system-wide keyboard shortcuts using the Carbon
//  RegisterEventHotKey API — the only approach that works even when
//  the app has no focused window (pure menu-bar daemon).
//
//  Usage:
//    let mgr = HotkeyManager()
//    mgr.register(keyCombo: config.openPopupShortcut) { ... }
//    // later:
//    mgr.unregisterAll()
// ─────────────────────────────────────────────────────────────────────

final class HotkeyManager {

    // ── Internal bookkeeping ─────────────────────────────
    private struct Registration {
        let hotKeyRef: EventHotKeyRef
        let handler:   () -> Void
    }

    private var registrations: [UInt32: Registration] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    // ── Singleton event handler UPP ──────────────────────
    private static let signature: OSType = fourCC("CLPT")

    // ────────────────────────────────────────────────────
    // MARK: - Init / deinit
    // ────────────────────────────────────────────────────

    init() { installEventHandler() }

    deinit { unregisterAll(); removeEventHandler() }

    // ────────────────────────────────────────────────────
    // MARK: - Public API
    // ────────────────────────────────────────────────────

    /// Register a global hotkey. The handler is called on the main thread.
    @discardableResult
    func register(keyCombo: KeyCombo, handler: @escaping () -> Void) -> UInt32 {
        let id  = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: id)
        var hotKeyRef: EventHotKeyRef?

        let carbonMods = carbonModifiers(from: keyCombo.modifiers)
        let status = RegisterEventHotKey(
            keyCombo.keyCode,
            carbonMods,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            print("[HotkeyManager] Failed to register \(keyCombo.display) — OSStatus \(status)")
            return 0
        }

        registrations[id] = Registration(hotKeyRef: ref, handler: handler)
        print("[HotkeyManager] Registered \(keyCombo.display) with ID \(id)")
        return id
    }

    /// Unregister a previously registered hotkey by its returned ID.
    func unregister(id: UInt32) {
        guard let reg = registrations[id] else { return }
        UnregisterEventHotKey(reg.hotKeyRef)
        registrations.removeValue(forKey: id)
    }

    /// Unregister all hotkeys.
    func unregisterAll() {
        registrations.keys.forEach { unregister(id: $0) }
    }

    // ────────────────────────────────────────────────────
    // MARK: - Carbon event handler
    // ────────────────────────────────────────────────────

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )

        // We pass `self` as userData so the C callback can reach us
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    private func removeEventHandler() {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    // Called from the C callback below
    fileprivate func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else { return status }
        guard hotKeyID.signature == HotkeyManager.signature else { return OSStatus(eventNotHandledErr) }

        if let reg = registrations[hotKeyID.id] {
            DispatchQueue.main.async { reg.handler() }
            return noErr
        }
        return OSStatus(eventNotHandledErr)
    }

    // ────────────────────────────────────────────────────
    // MARK: - Helpers
    // ────────────────────────────────────────────────────

    /// Convert NSEvent.ModifierFlags → Carbon modifier bitmask
    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey)   }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey)  }
        return carbon
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - C-compatible callback (must be a free function or closure)
// ─────────────────────────────────────────────────────────────────────

private let hotKeyCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
    guard let event    = event,
          let userData = userData else { return OSStatus(eventNotHandledErr) }

    // Recover the HotkeyManager instance from the retained opaque pointer
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    return manager.handleHotKeyEvent(event)
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - FourCC helper
// ─────────────────────────────────────────────────────────────────────

private func fourCC(_ string: String) -> OSType {
    assert(string.count == 4)
    var result: OSType = 0
    for char in string.unicodeScalars {
        result = (result << 8) + OSType(char.value)
    }
    return result
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - KeyCode reference (common keys)
// ─────────────────────────────────────────────────────────────────────
//
//  These are the Virtual Key Codes used by macOS / Carbon.
//  Pass one of these as `keyCode` when building a KeyCombo.
//
//  Letters: A=0  S=1  D=2  F=3  H=4  G=5  Z=6  X=7  C=8  V=9
//           B=11 Q=12 W=13 E=14 R=15 Y=16 T=17 1=18 2=19 3=20
//           4=21 6=22 5=23 =24  9=25 7=26 -=27  8=28 0=29
//  Space=49  Tab=48  Return=36  Escape=53  Delete=51  BackSpace=117
//  Up=126    Down=125  Left=123  Right=124
//  F1=122 F2=120 F3=99 F4=118 F5=96 F6=97 F7=98 F8=100
