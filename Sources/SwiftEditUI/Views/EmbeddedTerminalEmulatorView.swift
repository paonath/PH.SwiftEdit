#if os(macOS)
import AppKit
import SwiftEditCore
import SwiftTerm
import SwiftUI

/// SwiftUI bridge hosting one interactive `SwiftTerm.LocalProcessTerminalView` inside the bottom `Cmd+J` panel (`AR-005`, `UI-005`).
struct EmbeddedTerminalEmulatorView: NSViewRepresentable {
    let registry: EmbeddedTerminalRegistry
    let sessionID: UUID
    let directory: URL
    let palette: PurpleThemePalette
    let font: NSFont
    let onTitleChange: (UUID, String) -> Void
    let onDirectoryChange: (UUID, String?) -> Void
    let onTerminated: (UUID, Int32?) -> Void
    let onFailedToStart: (UUID, String) -> Void

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 220))
        attachTerminal(into: container)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        attachTerminal(into: nsView)
    }

    private func attachTerminal(into container: NSView) {
        guard let termView = registry.terminalView(
            for: sessionID,
            directory: directory,
            palette: palette,
            font: font,
            onTitleChange: onTitleChange,
            onDirectoryChange: onDirectoryChange,
            onTerminated: onTerminated,
            onFailedToStart: onFailedToStart
        ) else {
            container.subviews.forEach { $0.removeFromSuperview() }
            return
        }
        if termView.superview !== container {
            container.subviews.forEach { $0.removeFromSuperview() }
            termView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(termView)
            NSLayoutConstraint.activate([
                termView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                termView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                termView.topAnchor.constraint(equalTo: container.topAnchor),
                termView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            DispatchQueue.main.async {
                termView.window?.makeFirstResponder(termView)
            }
        }
    }
}
#endif
