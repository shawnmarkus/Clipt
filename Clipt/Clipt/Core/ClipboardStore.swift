import Foundation
import Combine

// ─────────────────────────────────────────────────────────────────────
// ClipboardStore
//
//  • Owns the ordered history stack (index 0 = newest)
//  • Enforces two independent limits: entry count AND total memory
//  • Evicts the oldest *unpinned* entry when either limit is exceeded
//  • Persists to JSON in ~/Library/Application Support/Clipt/history.json
//  • Publishes changes so SwiftUI views update automatically
// ─────────────────────────────────────────────────────────────────────

final class ClipboardStore: ObservableObject {

    static let shared = ClipboardStore()

    // ── Published state ───────────────────────────────────
    @Published private(set) var items:        [ClipItem] = []
    @Published private(set) var totalBytes:   Int        = 0   // live memory usage

    // ── Limits (kept in sync with AppConfig) ─────────────
    var maxEntries:  Int { AppConfig.shared.maxEntries  }
    var maxMemoryMB: Int { AppConfig.shared.maxMemoryMB }
    private var maxBytes: Int { maxMemoryMB * 1024 * 1024 }

    // FIX 3: suppress flag — set true before writing to pasteboard from within Clipt
    // The monitor skips the next detected change, preventing duplicate entries.
    var suppressNextCapture: Bool = false

    // ── Persistence ───────────────────────────────────────
    private let saveURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir     = support.appendingPathComponent("Clipt", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    private let saveQueue = DispatchQueue(label: "com.clipt.store.save", qos: .background)

    // ── Init ──────────────────────────────────────────────
    private init() { load() }

    // ─────────────────────────────────────────────────────
    // MARK: - Public API
    // ─────────────────────────────────────────────────────

    /// Add a newly captured item. Called from ClipboardMonitor on main thread.
    func add(_ item: ClipItem) {
        // Skip exact duplicates (same text/data as the current top item)
        if let top = items.first {
            if top.text != nil, top.text == item.text { return }
            if let d1 = top.imageData, let d2 = item.imageData, d1 == d2 { return }
        }

        items.insert(item, at: 0)
        totalBytes += item.byteSize

        enforceEntryLimit()
        enforceMemoryLimit()

        scheduleSave()
    }

    /// Toggle pin state for an item.
    func togglePin(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isPinned.toggle()
        scheduleSave()
    }

    /// Delete a single item.
    func remove(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        totalBytes -= items[idx].byteSize
        items.remove(at: idx)
        scheduleSave()
    }

    /// Clear all unpinned items.
    func clearAll() {
        let pinned = items.filter(\.isPinned)
        items = pinned
        recalculateBytes()
        scheduleSave()
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Eviction
    // ─────────────────────────────────────────────────────

    private func enforceEntryLimit() {
        while items.count > maxEntries {
            evictOldest()
        }
    }

    private func enforceMemoryLimit() {
        while totalBytes > maxBytes {
            evictOldest()
        }
    }

    /// Remove the oldest non-pinned item. If all are pinned, remove oldest pinned.
    private func evictOldest() {
        // Search from the end (oldest items are at the back of the array)
        if let idx = items.indices.reversed().first(where: { !items[$0].isPinned }) {
            totalBytes -= items[idx].byteSize
            items.remove(at: idx)
        } else if let last = items.indices.last {
            // All pinned — still must evict to honour limits
            totalBytes -= items[last].byteSize
            items.remove(at: last)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Persistence
    // ─────────────────────────────────────────────────────

    private func scheduleSave() {
        let snapshot = items
        saveQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.writeToDisk(snapshot)
        }
    }

    private func writeToDisk(_ snapshot: [ClipItem]) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: saveURL, options: .atomicWrite)
        } catch {
            print("[ClipboardStore] Save failed: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        do {
            let loaded = try JSONDecoder().decode([ClipItem].self, from: data)
            items = loaded
            recalculateBytes()
            // Enforce limits against the loaded data (settings may have changed)
            enforceEntryLimit()
            enforceMemoryLimit()
        } catch {
            print("[ClipboardStore] Load failed: \(error)")
        }
    }

    private func recalculateBytes() {
        totalBytes = items.reduce(0) { $0 + $1.byteSize }
    }
}
