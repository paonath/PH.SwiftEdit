import SwiftEditUI
import SwiftUI

@main
struct SwiftEditApp: App {
    var body: some Scene {
        WindowGroup {
            SwiftEditRootView()
        }
        #if os(macOS)
        .commands {
            SwiftEditCommands()
        }
        #endif
    }
}
