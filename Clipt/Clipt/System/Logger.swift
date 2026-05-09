import Foundation
import os.log

// ─────────────────────────────────────────────────────────────────────
// Logger
//
//  Dual-sink logger:
//  1. os.Logger  →  appears in Console.app (structured, low overhead)
//  2. File log   →  ~/Library/Logs/Clipt/clipt.log  (tail-able by user)
//
//  Usage:
//    CliptLog.info("Monitor started")
//    CliptLog.error("Hotkey registration failed: \(err)")
// ─────────────────────────────────────────────────────────────────────

enum CliptLog {

    // ── os.Logger ────────────────────────────────────────
    private static let osLog = os.Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.clipt",
        category:  "clipt"
    )

    // ── File log ──────────────────────────────────────────
    private static let fileURL: URL = {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Clipt", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("clipt.log")
    }()

    private static let fileHandle: FileHandle? = {
        // Create file if absent
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        return try? FileHandle(forWritingTo: fileURL)
    }()

    private static let queue = DispatchQueue(label: "com.clipt.logger", qos: .background)
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    // Max log file size before rotation (5 MB)
    private static let maxFileSizeBytes = 5 * 1024 * 1024

    // ─────────────────────────────────────────────────────
    // MARK: - Public API
    // ─────────────────────────────────────────────────────

    static func info(_ message: String, file: String = #file, line: Int = #line) {
        osLog.info("\(message, privacy: .public)")
        write(level: "INFO ", message: message, file: file, line: line)
    }

    static func debug(_ message: String, file: String = #file, line: Int = #line) {
#if DEBUG
        osLog.debug("\(message, privacy: .public)")
        write(level: "DEBUG", message: message, file: file, line: line)
#endif
    }

    static func warning(_ message: String, file: String = #file, line: Int = #line) {
        osLog.warning("\(message, privacy: .public)")
        write(level: "WARN ", message: message, file: file, line: line)
    }

    static func error(_ message: String, file: String = #file, line: Int = #line) {
        osLog.error("\(message, privacy: .public)")
        write(level: "ERROR", message: message, file: file, line: line)
    }

    // ─────────────────────────────────────────────────────
    // MARK: - File write
    // ─────────────────────────────────────────────────────

    private static func write(level: String, message: String, file: String, line: Int) {
        queue.async {
            let filename = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
            let timestamp = dateFormatter.string(from: Date())
            let line = "[\(timestamp)] [\(level)] [\(filename):\(line)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            rotateIfNeeded()
            fileHandle?.seekToEndOfFile()
            fileHandle?.write(data)
        }
    }

    /// Rotate log file if it exceeds maxFileSizeBytes (rename to clipt.log.old)
    private static func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size  = attrs[.size] as? Int,
              size > maxFileSizeBytes else { return }

        let oldURL = fileURL.deletingPathExtension().appendingPathExtension("log.old")
        try? FileManager.default.removeItem(at: oldURL)
        try? FileManager.default.moveItem(at: fileURL, to: oldURL)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Convenience: dump all paths on startup
    // ─────────────────────────────────────────────────────

    static func logStartupInfo() {
        let config = AppConfig.shared
        info("─── Clipt starting up ───────────────────────────────")
        info("App bundle  : \(config.appBundlePath)")
        info("Support dir : \(config.supportDirPath)")
        info("Log file    : \(config.logFilePath)")
        info("LaunchAgent : \(config.launchAgentPath)")
        info("isEnabled   : \(config.isEnabled)")
        info("maxEntries  : \(config.maxEntries)")
        info("maxMemoryMB : \(config.maxMemoryMB) MB")
        info("launchAtLogin: \(config.launchAtLogin)")
        info("────────────────────────────────────────────────────")
    }
}
