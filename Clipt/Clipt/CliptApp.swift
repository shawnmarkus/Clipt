//import SwiftUI
//
//@main
//struct CliptApp: App {
//
//    // Bridge SwiftUI lifecycle → AppDelegate (NSStatusItem, NSPanel, hotkeys)
//    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
//
//    var body: some Scene {
//        // Empty scene — all windows (popup, settings, onboarding) are
//        // created and managed manually in AppDelegate to avoid SwiftUI
//        // Settings scene quirks with menu-bar-only (LSUIElement) apps.
//        WindowGroup(id: "noop") {
//            EmptyView()
//        }
//        .defaultSize(width: 0, height: 0)
//        .windowResizability(.contentSize)
//        .commandsRemoved()
//    }
//}

import SwiftUI

@main
struct CliptApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene never auto-opens — it's the correct container
        // for LSUIElement (menu-bar-only) apps. WindowGroup conflicts
        // with LSUIElement and causes IDELaunchErrorDomain Code 20.
        Settings {
            EmptyView()
        }
    }
}
