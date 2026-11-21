import AppKit
import SwiftEditUI
import SwiftUI

/// AppKit lifecycle adaptor forwarding Finder document opens (`application(_:open:)`) and quit prompts (`applicationShouldTerminate(_:)`) to `SwiftEditAppLifecycleBridge` (`BUG-002`, `BUG-003`, `BUG-010`).
@MainActor
final class SwiftEditAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        SwiftEditAppLifecycleBridge.shared.receiveExternalOpenURLs(urls)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let allowNow = SwiftEditAppLifecycleBridge.shared.beginApplicationTermination { allowQuit in
            sender.reply(toApplicationShouldTerminate: allowQuit)
        }
        return allowNow ? .terminateNow : .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct SwiftEditApp: App {
    @NSApplicationDelegateAdaptor(SwiftEditAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            SwiftEditRootView()
                .onOpenURL { url in
                    SwiftEditAppLifecycleBridge.shared.receiveExternalOpenURLs([url])
                }
        }
        #if os(macOS)
        .commands {
            SwiftEditCommands()
        }
        #endif

        #if os(macOS)
        Settings {
            // Cmd+, : interface and editor font pickers bound to the active workbench (`REQ-007`).
            SwiftEditSettingsView()
        }
        #endif
    }
}
