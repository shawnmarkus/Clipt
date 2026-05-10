import SwiftUI

// ─────────────────────────────────────────────────────────────────────
// OnboardingView
//
//  Shown as a regular NSWindow on first launch.
//  Walks the user through 3 steps:
//    1. Welcome + what the app does
//    2. Request Accessibility permission
//    3. Optional: enable launch at login
//
//  After finishing, sets UserDefaults "hasOnboarded" = true.
// ─────────────────────────────────────────────────────────────────────

struct OnboardingView: View {

    @State private var step = 0
    @StateObject private var checker = PermissionChecker()

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background glass
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                            .animation(.easeInOut, value: step)
                    }
                }
                .padding(.top, 28)

                Spacer()

                // Step content
                Group {
                    if step == 0 { WelcomeStep() }
                    if step == 1 { AccessibilityStep(checker: checker) }
                    if step == 2 { StartupStep() }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.25), value: step)

                Spacer()

                // Navigation buttons
                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(step < 2 ? "Continue" : "Done — Start Clipt") {
                        if step < 2 { step += 1 } else { finish() }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
        }
        .frame(width: 520, height: 420)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasOnboarded")
        AppConfig.shared.isEnabled = true
        onComplete()
        // Show the popup immediately so user sees the app is running        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AppDelegate.shared.togglePopup()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Step 1: Welcome
// ─────────────────────────────────────────────────────────────────────

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse)

            Text("Welcome to Clipt")
                .font(.system(size: 28, weight: .semibold))

            Text("Clipt lives in your menu bar and keeps a searchable history of everything you copy — text, URLs, images, and files.\n\nClick the clipboard icon to browse and re-paste any item instantly.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Step 2: Accessibility permission
// ─────────────────────────────────────────────────────────────────────

struct AccessibilityStep: View {
    @ObservedObject var checker: PermissionChecker

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "accessibility")
                .font(.system(size: 56))
                .foregroundStyle(checker.accessibilityGranted ? .green : .orange)

            Text("Accessibility access")
                .font(.system(size: 24, weight: .semibold))

            Text("Clipt needs Accessibility access to detect which app is in front and to auto-paste when you select an item from the history.\n\nWithout it the app still works — but you'll need to paste manually with ⌘V after selecting.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)

            if checker.accessibilityGranted {
                Label("Permission granted", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else {
                Button("Grant Accessibility Access…") {
                    checker.requestAccessibility()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        checker.refresh()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Step 3: Launch at login
// ─────────────────────────────────────────────────────────────────────

struct StartupStep: View {
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)

            Text("Always ready")
                .font(.system(size: 24, weight: .semibold))

            Text("Would you like Clipt to start automatically when you log in?\n\nIt runs as a lightweight background daemon — no Dock icon, no open windows. The menu bar icon will appear once it starts.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)

            Toggle("Launch Clipt at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, newValue in
                    AppConfig.shared.launchAtLogin = newValue
                }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Onboarding window controller
// ─────────────────────────────────────────────────────────────────────

final class OnboardingWindowController: NSWindowController {

    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "hasOnboarded") else { return }
        let controller = OnboardingWindowController()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    convenience init() {
        let window = NSWindow(
            contentRect:  NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask:    [.titled, .closable, .fullSizeContentView],
            backing:      .buffered,
            defer:        false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility  = .hidden
        window.isMovableByWindowBackground = true
        window.center()

        self.init(window: window)

        let view = OnboardingView { [weak window] in
                    window?.close()
        }
        window.contentView = NSHostingView(rootView: view)
    }
}
