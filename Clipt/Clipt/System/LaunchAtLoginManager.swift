import Foundation
import ServiceManagement

// ─────────────────────────────────────────────────────────────────────
// LaunchAtLoginManager
//
//  Wraps the two approaches macOS offers for "launch at login":
//
//  macOS 13+  →  SMAppService.mainApp  (recommended, no plist needed)
//  macOS 12-  →  LaunchAgent plist written to ~/Library/LaunchAgents/
//
//  The plist method requires no special entitlement but the app must be
//  inside /Applications and the plist must not be quarantined.
// ─────────────────────────────────────────────────────────────────────

enum LaunchAtLoginManager {

    // ────────────────────────────────────────────────────
    // MARK: - Public API
    // ────────────────────────────────────────────────────

    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            modern(enabled)
        } else {
            legacy(enabled)
        }
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return legacyPlistExists
        }
    }

    // ────────────────────────────────────────────────────
    // MARK: - macOS 13+ (SMAppService)
    // ────────────────────────────────────────────────────

    @available(macOS 13.0, *)
    private static func modern(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
                print("[LaunchAtLogin] Registered via SMAppService ✓")
            } else {
                try SMAppService.mainApp.unregister()
                print("[LaunchAtLogin] Unregistered via SMAppService ✓")
            }
        } catch {
            print("[LaunchAtLogin] SMAppService error: \(error)")
        }
    }

    // ────────────────────────────────────────────────────
    // MARK: - macOS 12 and earlier (LaunchAgent plist)
    // ────────────────────────────────────────────────────

    private static var legacyPlistURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LaunchAgents/com.clipt.daemon.plist")
    }

    private static var legacyPlistExists: Bool {
        FileManager.default.fileExists(atPath: legacyPlistURL.path)
    }

    private static func legacy(_ enable: Bool) {
        if enable {
            writeLaunchAgentPlist()
            loadPlist()
        } else {
            unloadPlist()
            removeLaunchAgentPlist()
        }
    }

    /// Write ~/Library/LaunchAgents/com.clipt.daemon.plist
    private static func writeLaunchAgentPlist() {
        guard let execPath = Bundle.main.executablePath else {
            print("[LaunchAtLogin] Cannot find executable path"); return
        }

        // Create LaunchAgents directory if needed
        let dir = legacyPlistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label":                   "com.clipt.daemon",
            "ProgramArguments":        [execPath],
            "RunAtLoad":               true,
            "KeepAlive":               ["SuccessfulExit": false],   // restart on crash
            "ProcessType":             "Background",
            "StandardOutPath":         logPath("stdout.log"),
            "StandardErrorPath":       logPath("stderr.log"),
            "EnvironmentVariables":    ["CLIPT_DAEMON": "1"],
        ]

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: legacyPlistURL, options: .atomicWrite)
            print("[LaunchAtLogin] Wrote plist to \(legacyPlistURL.path)")
        } catch {
            print("[LaunchAtLogin] Plist write error: \(error)")
        }
    }

    private static func removeLaunchAgentPlist() {
        try? FileManager.default.removeItem(at: legacyPlistURL)
        print("[LaunchAtLogin] Removed plist")
    }

    /// launchctl load the plist (activates it for the current session too)
    private static func loadPlist() {
        shell("launchctl", "load", "-w", legacyPlistURL.path)
    }

    private static func unloadPlist() {
        shell("launchctl", "unload", "-w", legacyPlistURL.path)
    }

    // ────────────────────────────────────────────────────
    // MARK: - Helpers
    // ────────────────────────────────────────────────────

    private static func logPath(_ filename: String) -> String {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Clipt")
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent(filename).path
    }

    @discardableResult
    private static func shell(_ args: String...) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = Array(args.dropFirst())   // first arg is the tool path
        if args.first == "launchctl" {
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = Array(args.dropFirst())
        } else {
            process.executableURL = URL(fileURLWithPath: args[0])
            process.arguments = Array(args.dropFirst())
        }
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
