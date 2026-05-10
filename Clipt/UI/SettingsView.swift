import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

// ─────────────────────────────────────────────────────────────────────
// SettingsView  —  sidebar + content layout matching the design mockup
// ─────────────────────────────────────────────────────────────────────

enum SettingsTab: String, CaseIterable {
    case activation  = "Activation"
    case memory      = "Memory & Storage"
    case permissions = "Permissions"
    case daemon      = "Daemon & Startup"
    case shortcuts   = "Shortcuts"
    case privacy     = "Privacy"

    var icon: String {
        switch self {
        case .activation:  return "power"
        case .memory:      return "internaldrive"
        case .permissions: return "shield.checkered"
        case .daemon:      return "terminal"
        case .shortcuts:   return "keyboard"
        case .privacy:     return "eye.slash"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store:  ClipboardStore
    @EnvironmentObject var config: AppConfig
    @State private var selected: SettingsTab = .activation

    var body: some View {
        HStack(spacing: 0) {
            // ── Sidebar ───────────────────────────────────────────────
            sidebar

            Divider()

            // ── Content pane ──────────────────────────────────────────
            VStack(spacing: 0) {
                // Pane title bar
                HStack {
                    Text(selected.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                Divider()

                // Tab content
                ScrollView {
                    contentPane
                        .padding(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 640, height: 480)
    }

    // ── Sidebar ───────────────────────────────────────────────────────
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            sidebarSection("General") {
                SidebarRow(tab: .activation,  selected: $selected)
                SidebarRow(tab: .memory,      selected: $selected)
                SidebarRow(tab: .permissions, selected: $selected)
            }
            sidebarSection("System") {
                SidebarRow(tab: .daemon,    selected: $selected)
                SidebarRow(tab: .shortcuts, selected: $selected)
                SidebarRow(tab: .privacy,   selected: $selected)
            }
            Spacer()
            Text("Clipt v1.0.0")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .frame(width: 190)
        .background(.ultraThinMaterial)
    }

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
            content()
        }
    }

    // ── Content router ────────────────────────────────────────────────
    @ViewBuilder
    private var contentPane: some View {
        switch selected {
        case .activation:  ActivationTab().environmentObject(config)
        case .memory:      MemoryTab().environmentObject(config).environmentObject(store)
        case .permissions: PermissionsTab()
        case .daemon:      DaemonTab().environmentObject(config).environmentObject(store)
        case .shortcuts:   ShortcutsTab().environmentObject(config)
        case .privacy:     PrivacyTab().environmentObject(config)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Sidebar row
// ─────────────────────────────────────────────────────────────────────

struct SidebarRow: View {
    let tab: SettingsTab
    @Binding var selected: SettingsTab
    @State private var hovered = false

    var isActive: Bool { selected == tab }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tab.icon)
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
            Text(tab.rawValue)
                .font(.system(size: 13))
                .foregroundStyle(isActive ? Color.primary : .secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? Color.accentColor.opacity(0.15)
                               : hovered ? Color.primary.opacity(0.05) : .clear)
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { selected = tab }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Shared card + row components
// ─────────────────────────────────────────────────────────────────────

struct SettingsCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title   = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 6)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
    }
}

struct SettingsRow<Leading: View, Trailing: View>: View {
    let icon:      String
    let iconColor: Color
    let label:     String
    let detail:    String?
    @ViewBuilder let leading:  () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    init(icon: String, color: Color = .accentColor,
         label: String, detail: String? = nil,
         @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.icon      = icon
        self.iconColor = color
        self.label     = label
        self.detail    = detail
        self.leading   = leading
        self.trailing  = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor.opacity(0.18))
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 13))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 56).opacity(0.5)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Tab: Activation
// ─────────────────────────────────────────────────────────────────────

struct ActivationTab: View {
    @EnvironmentObject var config: AppConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            SettingsCard("Tracking status") {
                SettingsRow(icon: "power", color: .purple,
                            label: "Enable Clipt",
                            detail: "When on, Clipt monitors your clipboard and shows the menu bar icon. When off, tracking stops completely and the icon disappears.") {
                    Toggle("", isOn: $config.isEnabled).labelsHidden()
                }
                SettingsRow(icon: "circle.fill",
                            color: config.isEnabled ? .green : .red,
                            label: "Current state",
                            detail: config.isEnabled ? "Clipboard monitoring is active" : "Monitoring paused — no tracking") {
                    Circle()
                        .fill(config.isEnabled ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: config.isEnabled ? .green.opacity(0.6) : .clear, radius: 4)
                }
            }

            SettingsCard("Menu bar icon") {
                SettingsRow(icon: "menubar.rectangle", color: .teal,
                            label: "Show icon in menu bar",
                            detail: "Icon appears only while Clipt is enabled.") {
                    Toggle("", isOn: $config.showMenuBarIcon).labelsHidden()
                        .disabled(!config.isEnabled)
                }
                SettingsRow(icon: "bell.badge", color: .orange,
                            label: "Show capture badge",
                            detail: "Flash a count badge on the icon when a new item is captured.") {
                    Toggle("", isOn: $config.showCaptureBadge).labelsHidden()
                        .disabled(!config.isEnabled)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Tab: Memory & Storage
// ─────────────────────────────────────────────────────────────────────

struct MemoryTab: View {
    @EnvironmentObject var config: AppConfig
    @EnvironmentObject var store:  ClipboardStore

    @State private var entries:   Double = 0
    @State private var memoryMB:  Double = 0

    var usageRatio: Double {
        guard config.maxMemoryMB > 0 else { return 0 }
        return Double(store.totalBytes) / Double(config.maxMemoryMB * 1024 * 1024)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            SettingsCard("Storage limits") {
                // Entry count slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7).fill(Color.purple.opacity(0.18))
                            Image(systemName: "list.number").font(.system(size: 14)).foregroundStyle(.purple)
                        }
                        .frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Max entries in history").font(.system(size: 13))
                            Text("Oldest unpinned item is evicted when this limit is reached.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(entries))")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.purple)
                            .frame(minWidth: 35, alignment: .trailing)
                    }
                    Slider(value: $entries, in: 10...500, step: 10)
                        .tint(.purple)
                        .padding(.leading, 42)
                        .onChange(of: entries) { _, v in config.maxEntries = Int(v) }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .overlay(alignment: .bottom) { Divider().padding(.leading, 56).opacity(0.5) }

                // Memory slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7).fill(Color.blue.opacity(0.18))
                            Image(systemName: "memorychip").font(.system(size: 14)).foregroundStyle(.blue)
                        }
                        .frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Max memory usage").font(.system(size: 13))
                            Text("Clipt evicts the oldest entry the moment total size exceeds this.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(memoryMB)) MB")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.blue)
                            .frame(minWidth: 55, alignment: .trailing)
                    }
                    Slider(value: $memoryMB, in: 32...512, step: 32)
                        .tint(.blue)
                        .padding(.leading, 42)
                        .onChange(of: memoryMB) { _, v in config.maxMemoryMB = Int(v) }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }

            SettingsCard("Retention policy") {
                SettingsRow(icon: "clock.arrow.circlepath", color: .orange,
                            label: "Auto-clear unpinned items") {
                    Picker("", selection: $config.retentionPolicy) {
                        Text("Never").tag("never")
                        Text("On restart").tag("restart")
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
                SettingsRow(icon: "pin.fill", color: .green,
                            label: "Pinned items ignore limits",
                            detail: "Pinned snippets are never evicted.") {
                    Toggle("", isOn: $config.pinnedItemsIgnoreLimits).labelsHidden()
                }
            }

            SettingsCard("Current usage") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("\(store.items.count) items", systemImage: "tray.full")
                        Spacer()
                        Text(formatBytes(store.totalBytes) + " / \(config.maxMemoryMB) MB")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Button("Clear all") { store.clearAll() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundStyle(.red)
                    }
                    ProgressView(value: min(usageRatio, 1.0))
                        .tint(usageRatio > 0.9 ? .red : usageRatio > 0.7 ? .orange : .green)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
        }
        .onAppear {
            entries  = Double(config.maxEntries)
            memoryMB = Double(config.maxMemoryMB)
        }
    }

    private func formatBytes(_ b: Int) -> String {
        if b < 1024 { return "\(b) B" }
        if b < 1024*1024 { return "\(b/1024) KB" }
        return String(format: "%.1f MB", Double(b)/(1024*1024))
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Tab: Permissions
// ─────────────────────────────────────────────────────────────────────

struct PermissionsTab: View {
    @StateObject private var checker = PermissionChecker()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            SettingsCard("Required") {
                PermissionRow(
                    icon: "accessibility", color: .blue,
                    title: "Accessibility access",
                    detail: "Detects the frontmost app to exclude password managers, and enables auto-paste after selecting an item.",
                    status: checker.accessibilityGranted ? .granted : .denied,
                    buttonLabel: checker.accessibilityGranted ? "Open" : "Grant"
                ) { checker.openAccessibilitySettings() }

                PermissionRow(
                    icon: "doc.on.clipboard", color: .teal,
                    title: "Clipboard access",
                    detail: "macOS allows clipboard read without a prompt. On macOS 14+ a system banner may appear on first capture — this is expected.",
                    status: .granted
                )
            }

            SettingsCard("Optional") {
                PermissionRow(
                    icon: "bell.badge", color: .orange,
                    title: "Notifications",
                    detail: "Shows a brief toast when a new item is captured. The app works without this.",
                    status: checker.notificationsGranted ? .granted : .denied,
                    buttonLabel: "Request"
                ) { checker.requestNotifications() }

                PermissionRow(
                    icon: "arrow.up.forward.app", color: .purple,
                    title: "Launch at login",
                    detail: "Lets Clipt start automatically when you log in.",
                    status: checker.loginItemRegistered ? .granted : .unknown,
                    buttonLabel: "Open"
                ) { checker.openLoginItemsSettings() }
            }

            // Health summary
            if !checker.accessibilityGranted || !checker.notificationsGranted {
                SettingsCard {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Some permissions are missing")
                                .font(.system(size: 13, weight: .medium))
                            Text("Clipt works, but some features are limited. Grant the permissions above for full functionality.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Refresh") { checker.refresh() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
            }
        }
        .onAppear { checker.refresh() }
    }
}

struct PermissionRow: View {
    enum Status { case granted, denied, unknown }

    let icon:        String
    let color:       Color
    let title:       String
    let detail:      String
    let status:      Status
    var buttonLabel: String?
    var action:      (() -> Void)?

    init(icon: String, color: Color, title: String, detail: String,
         status: Status, buttonLabel: String? = nil, action: (() -> Void)? = nil) {
        self.icon        = icon
        self.color       = color
        self.title       = title
        self.detail      = detail
        self.status      = status
        self.buttonLabel = buttonLabel
        self.action      = action
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.18))
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(statusLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                if let label = buttonLabel, let action = action {
                    Button(label, action: action)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 56).opacity(0.5) }
    }

    private var statusLabel: String {
        switch status { case .granted: "Granted"; case .denied: "Denied"; case .unknown: "Not set" }
    }
    private var statusColor: Color {
        switch status { case .granted: .green; case .denied: .red; case .unknown: .orange }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Tab: Daemon & Startup
// ─────────────────────────────────────────────────────────────────────

struct DaemonTab: View {
    @EnvironmentObject var config: AppConfig
    @EnvironmentObject var store:  ClipboardStore
    @State private var showUninstallConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            SettingsCard("Startup behaviour") {
                SettingsRow(icon: "paperplane.fill", color: .green,
                            label: "Launch at login",
                            detail: "Registers Clipt as a Login Item using SMAppService — the modern macOS API.") {
                    Toggle("", isOn: $config.launchAtLogin).labelsHidden()
                }
                SettingsRow(icon: "eye.slash", color: .gray,
                            label: "Start silently",
                            detail: "On boot, only the menu bar icon appears — no window opens.") {
                    Toggle("", isOn: $config.startSilently).labelsHidden()
                }
                SettingsRow(icon: "arrow.clockwise", color: .orange,
                            label: "Restart on crash",
                            detail: "launchd will relaunch Clipt automatically if it exits unexpectedly.") {
                    Toggle("", isOn: $config.restartOnCrash).labelsHidden()
                }
            }

            SettingsCard("System paths") {
                PathRow(label: "Application bundle",    icon: "app.badge",      color: .teal,   path: config.appBundlePath)
                PathRow(label: "Database & config",     icon: "internaldrive",  color: .purple, path: config.supportDirPath)
                PathRow(label: "Log file",              icon: "doc.text",       color: .blue,   path: config.logFilePath)
                PathRow(label: "LaunchAgent plist",     icon: "terminal",       color: .orange, path: config.launchAgentPath)
            }

            SettingsCard("Danger zone") {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7).fill(Color.red.opacity(0.15))
                        Image(systemName: "trash").font(.system(size: 14)).foregroundStyle(.red)
                    }
                    .frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Uninstall Clipt").font(.system(size: 13))
                        Text("Removes Login Item, deletes data, and reveals the app so you can delete it.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Uninstall…") { showUninstallConfirm = true }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.red)
                        .controlSize(.small)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .confirmationDialog("Uninstall Clipt?",
                                isPresented: $showUninstallConfirm,
                                titleVisibility: .visible) {
                Button("Uninstall", role: .destructive) { performUninstall() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the Login Item and delete all clipboard history and settings. The folder containing Clipt will then open so you can safely move it to the Trash.")
            }
        }
    }

    private func performUninstall() {
        // 1. Disable launch at login
        LaunchAtLoginManager.setEnabled(false)
        
        // 2. Delete the Application Support folder (history data)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clipt")
        try? FileManager.default.removeItem(at: support)
        
        // 3. Clear all UserDefaults (settings)
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // 4. Reveal the app in Finder so the user can easily delete it
        let appURL = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
        
        // 5. Quit the app immediately so the file is unlocked
        NSApplication.shared.terminate(nil)
    }
}

struct PathRow: View {
    let label: String
    let icon:  String
    let color: Color
    let path:  String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.18))
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 12))
                Text(path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help("Copy path")
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 56).opacity(0.5) }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Tab: Shortcuts
// ─────────────────────────────────────────────────────────────────────

struct ShortcutsTab: View {
    @EnvironmentObject var config: AppConfig

    private let shortcuts: [(String, String, String)] = [
        ("Open / close popup",  "power",                  "⌘ ⇧ V"),
        ("Paste last item",     "arrow.up.doc.on.clipboard", "⌘ ⇧ C"),
        ("Open Settings",       "gearshape",              "⌘ ,"),
        ("Clear all history",   "trash",                  "⌘ ⇧ ⌫"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("Keyboard shortcuts") {
                ForEach(shortcuts, id: \.0) { label, icon, combo in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7).fill(Color.accentColor.opacity(0.15))
                            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(Color.accentColor)
                        }
                        .frame(width: 30, height: 30)
                        Text(label).font(.system(size: 13))
                        Spacer()
                        HStack(spacing: 6) {
                            Text(combo)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.primary.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Button("Change") { /* shortcut recorder — v1.1 */ }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .disabled(true)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Divider().padding(.leading, 56).opacity(0.5) }
                }
            }

            SettingsCard {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.secondary)
                    Text("Shortcut recorder (click to rebind) coming in v1.1.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Tab: Privacy
// ─────────────────────────────────────────────────────────────────────

struct PrivacyTab: View {
    @EnvironmentObject var config: AppConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            SettingsCard("Protection") {
                SettingsRow(icon: "lock.shield", color: .red,
                            label: "Ignore password manager apps",
                            detail: "Never capture copies from 1Password, Bitwarden, Keychain, Dashlane, and similar apps.") {
                    Toggle("", isOn: $config.ignorePasswordManagers).labelsHidden()
                }
                SettingsRow(icon: "creditcard.and.123", color: .orange,
                            label: "Mask credit card numbers",
                            detail: "Detected card numbers are stored as •••• •••• •••• 1234.") {
                    Toggle("", isOn: $config.maskCreditCards).labelsHidden()
                }
            }

            SettingsCard("Excluded apps (\(config.excludedAppBundleIDs.count))") {
                if config.excludedAppBundleIDs.isEmpty {
                    HStack {
                        Text("No apps excluded yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                } else {
                    ForEach(config.excludedAppBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Image(systemName: "app.badge.checkmark")
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            Text(bundleID)
                                .font(.system(size: 11, design: .monospaced))
                            Spacer()
                            Button {
                                config.excludedAppBundleIDs.removeAll { $0 == bundleID }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .overlay(alignment: .bottom) { Divider().padding(.leading, 56).opacity(0.5) }
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        pickApp()
                    } label: {
                        Label("Add excluded app…", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
            }
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.directoryURL     = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles   = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = "Exclude"
        if panel.runModal() == .OK, let url = panel.url {
            if let id = Bundle(url: url)?.bundleIdentifier,
               !config.excludedAppBundleIDs.contains(id) {
                config.excludedAppBundleIDs.append(id)
            }
        }
    }
}
