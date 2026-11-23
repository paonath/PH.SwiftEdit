import AppKit
import Foundation
import SwiftUI
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Opt-in visual debug harness: renders the full workbench offscreen in Light and Black modes and writes PNGs.
///
/// Enabled only when `SWIFTEDIT_VISUAL_AUDIT_DIR` points to an output directory, so CI and the default suite skip it.
@Suite("VisualAuditSnapshotTests", .serialized)
@MainActor
struct VisualAuditSnapshotTests {
    nonisolated static let outputDirectory: URL? = ProcessInfo.processInfo.environment["SWIFTEDIT_VISUAL_AUDIT_DIR"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }

    private static let sample = """
    ---
    title: Visual Audit Sample
    tags: [swiftedit, audit]
    status: draft
    ---

    # SwiftEdit visual audit

    SwiftEdit is a minimal editor. SwiftEdit opens fast and SwiftEdit stays light.

    ## Lists

    - item one with `inline code`
    - item two with **bold** and *italic*
      - nested item

    ```swift
    let value = compute(alpha, beta) // brackets (alpha) [beta] {gamma}
    ```

    | Col A | Col B |
    | ----- | ----- |
    | one   | two   |

    > A blockquote with a [link](https://example.com).
    """

    private static func snapshot<V: View>(_ view: V, size: NSSize, appearance: NSAppearance.Name, to url: URL) throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        window.contentView = hosting
        // Let SwiftUI, TextKit 2 viewport layout and highlight passes settle across a few run-loop turns.
        for _ in 0..<6 {
            hosting.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        }
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: url)
        window.contentView = nil
        window.orderOut(nil)
    }

    @Test("Visual audit: render workbench (editor, properties, preview, occurrences) in Light and Black", .enabled(if: outputDirectory != nil))
    func renderWorkbenchSnapshots() throws {
        let out = try #require(Self.outputDirectory)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("visual-audit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("sample.md")
        try Self.sample.write(to: file, atomically: true, encoding: .utf8)

        for mode in [AppearanceMode.light, .black] {
            let model = SwiftEditWorkbenchModel(
                preferencesStore: InMemoryKeyValueStore(),
                recentFilesStore: InMemoryKeyValueStore(),
                recoveryDirectoryURL: dir.appendingPathComponent("recovery-\(mode)"),
                fileSystem: LocalFileSystemAdapter(),
                systemDarkDetector: { mode == .black },
                savePanelProvider: { _ in nil }
            )
            model.appearanceMode = mode
            model.openFile(at: file, withinScope: dir)
            let appearance: NSAppearance.Name = mode == .black ? .darkAqua : .aqua
            let name = mode == .black ? "dark" : "light"

            // 1. Plain workbench.
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-01-workbench.png"))

            // 2. Selected word: other occurrences must show a soft highlight.
            let nsText = (model.activeDocumentSession?.text ?? "") as NSString
            let wordRange = nsText.range(of: "SwiftEdit is")
            model.selectRange(SwiftEditCore.TextRange(location: wordRange.location, length: 9))
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-02-occurrences.png"))

            // 3. Preview + expanded properties.
            model.propertiesPanel.isCollapsed = false
            model.toggleMarkdownPreview()
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-03-preview-properties.png"))
            model.toggleMarkdownPreview()

            // 4. Header submenu open.
            model.headerSubmenu.clickToggle()
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-04-header-menu.png"))
            model.headerSubmenu.clickToggle()

            // 5b. Contextual action palette (Cmd+Return) anchored under the selected word.
            model.selectRange(SwiftEditCore.TextRange(location: wordRange.location, length: 9))
            model.presentElementContextualMenu(anchor: CGPoint(x: 120, y: 330))
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-06-contextual-menu.png"))
            model.closeElementContextualMenu()

            // 5. Sidebar open.
            model.toggleLeftSidebar()
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-05-sidebar.png"))
            model.toggleLeftSidebar()

            // 7. Find & Replace bar + File Compare pane.
            model.presentFindBar(mode: .findAndReplace)
            model.toggleDiffPane()
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-07-find-compare.png"))
            model.toggleDiffPane()
            model.presentFindBar(mode: .hidden)

            // 17. Compare between two open tabs (destination picked in the Compare header).
            model.toggleDiffPane()
            if let other = model.compareDestinationCandidates.first { model.setCompareDestination(other.id) }
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-17-compare-two-tabs.png"))
            model.toggleDiffPane()

            // 8. Document navigator overlay.
            model.toggleDocumentNavigator()
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-08-navigator.png"))
            model.closeDocumentNavigator()

            // 14. Shortcuts side panel docked right.
            model.toggleShortcutsPanel()
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-14-shortcuts-panel.png"))
            model.toggleShortcutsPanel()

            // 15. Contextual palette without a selection (document actions only).
            model.selectRange(SwiftEditCore.TextRange(location: 0, length: 0))
            model.presentElementContextualMenu(anchor: CGPoint(x: 120, y: 200))
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-15-contextual-no-selection.png"))
            model.closeElementContextualMenu()

            // 16. Header and SwiftEdit menu at 150% zoom.
            model.zoomController.zoomIn(); model.zoomController.zoomIn(); model.zoomController.zoomIn(); model.zoomController.zoomIn(); model.zoomController.zoomIn()
            model.headerSubmenu.clickToggle()
            try Self.snapshot(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800), appearance: appearance, to: out.appendingPathComponent("\(name)-16-zoom150-menu.png"))
            model.headerSubmenu.clickToggle()
            model.zoomController.resetZoom()

            // 9. Sheets and popovers rendered standalone.
            let palette = model.palette
            try Self.snapshot(KeyboardShortcutsCheatSheetView(palette: palette, onClose: {}), size: NSSize(width: 900, height: 700), appearance: appearance, to: out.appendingPathComponent("\(name)-09-cheatsheet.png"))
            try Self.snapshot(AboutSheetView(descriptor: AboutSheetDescriptor.resolveFromMainBundle(), palette: palette, onClose: {}), size: NSSize(width: 520, height: 520), appearance: appearance, to: out.appendingPathComponent("\(name)-10-about.png"))
            try Self.snapshot(MarkdownDiagnosticsPopoverView(model: model), size: NSSize(width: 440, height: 260), appearance: appearance, to: out.appendingPathComponent("\(name)-11-diagnostics.png"))
            try Self.snapshot(HelpDocumentationView(palette: palette, onClose: {}), size: NSSize(width: 900, height: 700), appearance: appearance, to: out.appendingPathComponent("\(name)-12-help.png"))

            // 13. Icon sheet: every AppIcon at 16 pt and 24 pt with its name.
            let sheet = VStack(alignment: .leading, spacing: 10) {
                Text("SwiftEdit Line icons (\(AppIcon.allCases.count))").appFont(.headline, weight: .semibold)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(118), spacing: 8), count: 8), alignment: .leading, spacing: 12) {
                    ForEach(AppIcon.allCases, id: \.self) { icon in
                        VStack(spacing: 6) {
                            HStack(spacing: 10) {
                                AppIconView(icon, size: 16)
                                AppIconView(icon, size: 24)
                            }
                            .foregroundStyle(palette.chromeForeground.swiftUIColor)
                            Text(icon.rawValue).appFont(.caption2).foregroundStyle(palette.secondaryForeground.swiftUIColor)
                        }
                        .frame(width: 118, height: 58)
                        .background(palette.badgeSurface.swiftUIColor.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(palette.sheetSurface.swiftUIColor)
            try Self.snapshot(sheet, size: NSSize(width: 1040, height: 560), appearance: appearance, to: out.appendingPathComponent("\(name)-13-icons.png"))
        }
    }
}
