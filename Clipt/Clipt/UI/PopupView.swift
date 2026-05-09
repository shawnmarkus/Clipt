import SwiftUI
import AppKit

// ─────────────────────────────────────────────────────────────────────
// PopupView
//
//  The clipboard history popup that appears when the menu bar icon
//  is clicked.  Styled to match macOS Control Center aesthetics.
// ─────────────────────────────────────────────────────────────────────

struct PopupView: View {

    @EnvironmentObject var store:  ClipboardStore
    @EnvironmentObject var config: AppConfig

    var onClose: () -> Void

    @State private var searchText:   String   = ""
    @State private var selectedTab:  ClipType? = nil   // nil = All

    // ── Filtered list ────────────────────────────────────
    private var filtered: [ClipItem] {
        store.items
            .filter { item in
                if let tab = selectedTab, item.type != tab { return false }
                if searchText.isEmpty { return true }
                return item.displayText.localizedCaseInsensitiveContains(searchText)
            }
    }

    // ────────────────────────────────────────────────────
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            typeTabs
            clipList
            footer
        }
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)           // frosted-glass, adapts to dark/light
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
    }

    // ── Search bar ────────────────────────────────────────
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            TextField("Search clipboard…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Text("⌘K")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.15)
        }
    }

    // ── Type filter tabs ──────────────────────────────────
    private var typeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                TabPill(label: "All",    isActive: selectedTab == nil)     { selectedTab = nil }
                ForEach(ClipType.allCases, id: \.self) { type in
                    TabPill(label: type.label, isActive: selectedTab == type) { selectedTab = type }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .overlay(alignment: .bottom) { Divider().opacity(0.1) }
    }

    // ── Clipboard item list ───────────────────────────────
    private var clipList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filtered.isEmpty {
                    Text(searchText.isEmpty ? "Nothing copied yet." : "No results for '\(searchText)'")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(filtered) { item in
                        ClipRow(item: item, onSelect: { select(item) })
                            .environmentObject(store)
                        Divider().opacity(0.07).padding(.leading, 52)
                    }
                }
            }
        }
        .frame(maxHeight: 380)
    }

    // ── Footer ────────────────────────────────────────────
    private var footer: some View {
        HStack {
            Text("\(store.items.count) items")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            
            Button("⚙ Settings") {
                onClose()
                AppDelegate.shared.openSettings()
            }
            .buttonStyle(FooterButtonStyle())

            Button("Clear all") {
                store.clearAll()
            }
            .buttonStyle(FooterButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.03))
        .overlay(alignment: .top) { Divider().opacity(0.1) }
    }

    // ── Actions ───────────────────────────────────────────

    private func select(_ item: ClipItem) {
        // FIX 3: tell the monitor to ignore the next clipboard change
        // because it was triggered by Clipt itself, not an external copy.
        ClipboardStore.shared.suppressNextCapture = true

        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.type {
        case .text, .url, .code:
            if let t = item.text { pb.setString(t, forType: .string) }
        case .image:
            if let d = item.imageData { pb.setData(d, forType: .png) }
        case .file:
            if let paths = item.filePaths {
                let urls = paths.compactMap { URL(fileURLWithPath: $0) as NSURL }
                pb.writeObjects(urls)
            }
        }
        onClose()
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - ClipRow
// ─────────────────────────────────────────────────────────────────────

struct ClipRow: View {
    @EnvironmentObject var store: ClipboardStore
    let item:     ClipItem
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconBg)
                Image(systemName: item.type.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(iconFg)
            }
            .frame(width: 28, height: 28)
            .padding(.top, 1)

            // Text + meta
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.displayText)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    if item.isPinned {
                        Text("pinned")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.orange.opacity(0.9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text("\(item.type.label) · \(item.timeAgo)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons (show on hover)
            if isHovered {
                HStack(spacing: 4) {
                    IconAction(sfSymbol: "doc.on.doc",   tip: "Copy")   { onSelect() }
                    IconAction(sfSymbol: item.isPinned ? "pin.slash" : "pin", tip: item.isPinned ? "Unpin" : "Pin") {
                        store.togglePin(id: item.id)
                    }
                    IconAction(sfSymbol: "trash",         tip: "Delete") { store.remove(id: item.id) }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isHovered ? Color.white.opacity(0.06) : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }

    private var iconBg: Color {
        switch item.type {
        case .text:  return Color.purple.opacity(0.22)
        case .url:   return Color.blue.opacity(0.22)
        case .image: return Color.green.opacity(0.2)
        case .code:  return Color.orange.opacity(0.22)
        case .file:  return Color.gray.opacity(0.22)
        }
    }

    private var iconFg: Color {
        switch item.type {
        case .text:  return .purple
        case .url:   return Color(nsColor: .systemBlue)
        case .image: return .green
        case .code:  return .orange
        case .file:  return .gray
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Small reusable components
// ─────────────────────────────────────────────────────────────────────

struct TabPill: View {
    let label:    String
    let isActive: Bool
    let action:   () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Color.white.opacity(0.14) : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct IconAction: View {
    let sfSymbol: String
    let tip:      String
    let action:   () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: sfSymbol)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tip)
    }
}

struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(configuration.isPressed ? Color.white.opacity(0.12) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
