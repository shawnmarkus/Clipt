import Foundation
import AppKit

// ─────────────────────────────────────────────────────────
// MARK: - Content type
// ─────────────────────────────────────────────────────────

enum ClipType: String, Codable, CaseIterable {
    case text, url, image, file, code

    var icon: String {
        switch self {
        case .text:  return "doc.text"
        case .url:   return "link"
        case .image: return "photo"
        case .file:  return "doc"
        case .code:  return "chevron.left.forwardslash.chevron.right"
        }
    }

    var label: String { rawValue.capitalized }
}

// ─────────────────────────────────────────────────────────
// MARK: - ClipItem
// ─────────────────────────────────────────────────────────

struct ClipItem: Identifiable, Codable, Equatable {

    let id:          UUID
    let type:        ClipType
    let text:        String?          // plain text / URL / code
    let imageData:   Data?            // PNG bytes for image items
    let filePaths:   [String]?        // file URLs as strings
    let capturedAt:  Date
    var isPinned:    Bool
    var byteSize:    Int              // used for memory-limit tracking

    // ── Convenience init ─────────────────────────────────
    init(
        id:         UUID     = UUID(),
        type:       ClipType,
        text:       String?  = nil,
        imageData:  Data?    = nil,
        filePaths:  [String]? = nil,
        capturedAt: Date     = Date(),
        isPinned:   Bool     = false
    ) {
        self.id         = id
        self.type       = type
        self.text       = text
        self.imageData  = imageData
        self.filePaths  = filePaths
        self.capturedAt = capturedAt
        self.isPinned   = isPinned
        self.byteSize   = ClipItem.computeByteSize(text: text, imageData: imageData, filePaths: filePaths)
    }

    // ── Display helpers ───────────────────────────────────

    var displayText: String {
        switch type {
        case .text, .code: return text ?? ""
        case .url:         return text ?? ""
        case .image:       return "Image · \(formattedBytes(byteSize))"
        case .file:        return filePaths?.first ?? "File"
        }
    }

    var timeAgo: String {
        let seconds = Int(-capturedAt.timeIntervalSinceNow)
        if seconds < 60   { return "just now" }
        if seconds < 3600 { return "\(seconds / 60) min ago" }
        if seconds < 86400 { return "\(seconds / 3600) hr ago" }
        return "\(seconds / 86400)d ago"
    }

    // ── Snapshot from NSPasteboard ────────────────────────

    static func from(pasteboard: NSPasteboard) -> ClipItem? {
        // Image
        if let img = NSImage(pasteboard: pasteboard),
           let tiff = img.tiffRepresentation,
           let rep  = NSBitmapImageRep(data: tiff),
           let png  = rep.representation(using: .png, properties: [:]) {
            return ClipItem(type: .image, imageData: png)
        }

        // File paths
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            return ClipItem(type: .file, filePaths: urls.map(\.path))
        }

        // Text / URL / code
        if let raw = pasteboard.string(forType: .string), !raw.isEmpty {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let type: ClipType
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                type = .url
            } else if looksLikeCode(trimmed) {
                type = .code
            } else {
                type = .text
            }
            return ClipItem(type: type, text: trimmed)
        }

        return nil
    }

    // ── Private helpers ───────────────────────────────────

    private static func computeByteSize(text: String?, imageData: Data?, filePaths: [String]?) -> Int {
        var size = 0
        if let t = text       { size += t.utf8.count }
        if let d = imageData  { size += d.count }
        filePaths?.forEach { size += $0.utf8.count }
        return max(size, 64)   // minimum 64 bytes per item
    }

    private static func looksLikeCode(_ s: String) -> Bool {
        let codeSignals = ["{", "}", "func ", "class ", "var ", "let ", "import ",
                           "def ", "return ", "=>", "->", "//", "/*", "#!/"]
        return codeSignals.contains(where: s.contains)
    }

    private func formattedBytes(_ bytes: Int) -> String {
        if bytes < 1024       { return "\(bytes) B" }
        if bytes < 1024*1024  { return "\(bytes / 1024) KB" }
        return "\(bytes / (1024*1024)) MB"
    }
}
