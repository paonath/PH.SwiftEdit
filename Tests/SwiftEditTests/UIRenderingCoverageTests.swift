import AppKit
import CryptoKit
import Foundation
import SwiftUI
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("UIRenderingCoverageTests", .serialized)
@MainActor
struct UIRenderingCoverageTests {

    private static func renderInOffscreenWindow<V: View>(_ view: V, size: NSSize = NSSize(width: 960, height: 640)) {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        window.contentView = nil
        window.orderOut(nil)
    }

    @Test("Render all SwiftEditUI sheets, panels, overlays, and views in Light and Black modes without crashing")
    func renderAllUIViewsInLightAndBlack() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ui-cov-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let mdFile = dir.appendingPathComponent("doc.md")
        let logFile = dir.appendingPathComponent("app.log")
        try """
        ---
        title: Coverage Doc
        tags: [swift, test]
        ---

        # Heading 1

        ### Skipped Heading

        Some **bold**, `inline code`, and [link](https://example.com).

        - [ ] Todo A
        - [x] Todo B

        > Blockquote line

        | A | B |
        | --- | --- |
        | 1 | 2 |

        ```swift
        let x = 1
        ```

        <div>raw html</div>
        """.write(to: mdFile, atomically: true, encoding: .utf8)
        try "2026-11-22 10:00:00|INFO|App|hello\n".write(to: logFile, atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("recovery"),
            fileSystem: LocalFileSystemAdapter(),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.openFile(at: mdFile, withinScope: dir)

        for mode in [AppearanceMode.light, .black] {
            model.appearanceMode = mode
            let palette = model.palette

            // 1. Brand logo, About, Help, Shortcuts
            Self.renderInOffscreenWindow(SwiftEditBrandLogoView(size: 64), size: NSSize(width: 120, height: 120))
            Self.renderInOffscreenWindow(AboutSheetView(descriptor: AboutSheetDescriptor.resolveFromMainBundle(), palette: palette, onClose: {}))
            Self.renderInOffscreenWindow(HelpDocumentationView(palette: palette, onClose: {}))
            Self.renderInOffscreenWindow(KeyboardShortcutsCheatSheetView(palette: palette, onClose: {}))

            // 2. UpdateCheckSheetView across all outcomes
            for outcome in [
                UpdateCheckOutcome.upToDate(currentVersion: "0.1.4"),
                .noReleasesFound(currentVersion: "0.1.4"),
                .updateAvailable(
                    currentVersion: "0.1.4",
                    latestVersion: "0.2.0",
                    releaseURL: URL(string: "https://github.com/paonath/PH.SwiftEdit/releases/tag/v0.2.0")!,
                    downloadURL: URL(string: "https://github.com/paonath/PH.SwiftEdit/releases/download/v0.2.0/PH.SwiftEdit-v0.2.0-macOS-arm64.zip")!
                ),
                .error(message: "Offline"),
            ] {
                model.updateCheckOutcome = outcome
                Self.renderInOffscreenWindow(UpdateCheckSheetView(model: model, palette: palette, onClose: {}), size: NSSize(width: 460, height: 280))
            }

            // 3. Diagnostics Popover, Document Navigator, Properties Panel, Native Preview
            Self.renderInOffscreenWindow(MarkdownDiagnosticsPopoverView(model: model), size: NSSize(width: 420, height: 320))
            model.toggleDocumentNavigator()
            Self.renderInOffscreenWindow(DocumentNavigatorOverlayView(model: model), size: NSSize(width: 620, height: 480))
            model.closeDocumentNavigator()
            Self.renderInOffscreenWindow(PropertiesPanelView(model: model, state: model.propertiesPanel), size: NSSize(width: 720, height: 240))
            if let snap = model.activeDocumentSession?.snapshot {
                let previewDoc = MarkdownPreviewProjector.project(snapshot: snap, showPreview: true)
                Self.renderInOffscreenWindow(
                    MarkdownNativePreviewView(document: previewDoc, palette: palette, gate: nil, activeSourceLine: 1),
                    size: NSSize(width: 640, height: 480)
                )
            }

            // 4. LineNumberGutterView (both viewport metrics and fallback)
            let gutterProj = LineNumberGutterProjection(lineCount: 20, activeLine: 3, fontSizePoints: 13)
            let viewport = GutterViewportMetrics(scrollOffsetY: 0, visibleLines: [
                GutterLineMetric(lineNumber: 1, minY: 0, height: 18),
                GutterLineMetric(lineNumber: 3, minY: 36, height: 18),
            ])
            Self.renderInOffscreenWindow(
                LineNumberGutterView(
                    projection: gutterProj,
                    palette: palette,
                    severityByLine: [1: .warning, 3: .error],
                    viewportMetrics: viewport,
                    lintDetailsByLine: [1: "Warn detail", 3: "Error detail"]
                ),
                size: NSSize(width: 80, height: 300)
            )
            Self.renderInOffscreenWindow(
                LineNumberGutterView(projection: gutterProj, palette: palette),
                size: NSSize(width: 80, height: 300)
            )

            // 5. FindReplaceGoToLineBar in all modes
            for barMode in [FindBarPresentationMode.find, .findAndReplace, .goToLine] {
                var barState = FindReplaceBarState()
                barState.mode = barMode
                barState.query = "Hello"
                barState.replacement = "World"
                barState.goToLineText = "2"
                Self.renderInOffscreenWindow(
                    FindReplaceGoToLineBar(
                        state: .constant(barState),
                        palette: palette,
                        onFind: {},
                        onFindNext: {},
                        onFindPrevious: {},
                        onReplace: {},
                        onReplaceAll: {},
                        onGoToLine: {},
                        onClose: {}
                    ),
                    size: NSSize(width: 720, height: 80)
                )
            }

            // 6. LogTailPanelView
            let tail = LogTailController(tabID: DocumentID(), url: logFile, mode: .direct)
            Self.renderInOffscreenWindow(LogTailPanelView(model: model, tail: tail), size: NSSize(width: 720, height: 44))
            tail.stop()

            // 7. TerminalPanelView (with failed session so no live shell is needed during view render)
            let session = model.openTerminalSession()
            model.embeddedTerminalDidFail(id: session.id, message: "Simulated")
            Self.renderInOffscreenWindow(TerminalPanelView(model: model), size: NSSize(width: 720, height: 260))
            model.toggleTerminalPanel()

            // 8. HeaderBrandSubmenuView
            let items = model.headerCommandItems
            Self.renderInOffscreenWindow(
                HeaderBrandSubmenuView(
                    items: items,
                    palette: palette,
                    selectedID: items.first?.id,
                    onSelect: { _ in },
                    onMoveSelection: { _ in },
                    onSelectFirst: {},
                    onSelectLast: {},
                    onDismiss: {}
                ),
                size: NSSize(width: 340, height: 520)
            )

            // 9. SwiftEditSettingsView across all 3 sections (.fonts, .terminal, .updates) + nil provider
            Self.renderInOffscreenWindow(SwiftEditSettingsView(modelProvider: { nil }), size: NSSize(width: 760, height: 500))
            let settingsVM = SettingsViewModel(
                model: model,
                catalog: SystemFontCatalog(isOpenDyslexicAvailable: { true }),
                installedTerminalsProvider: { TerminalCatalog.knownTerminals }
            )
            settingsVM.refreshInstalledTerminals()
            settingsVM.selectTerminal(TerminalCatalog.knownTerminals.first?.bundleIdentifier)
            _ = settingsVM.autoResolvedTerminalName
            _ = settingsVM.rows(for: .interface)
            _ = settingsVM.rows(for: .editor)
            settingsVM.moveHighlight(by: 1, for: .editor)
            settingsVM.confirmHighlight(for: .editor)
            for section in SettingsSection.allCases {
                settingsVM.selectedSection = section
                Self.renderInOffscreenWindow(SwiftEditSettingsView(initialSettings: settingsVM), size: NSSize(width: 780, height: 520))
            }
        }

        // 10. Full SwiftEditRootView render pass (empty welcome state)
        Self.renderInOffscreenWindow(SwiftEditRootView(), size: NSSize(width: 1080, height: 720))
        #expect(model.tabSession.tabs.count >= 1)
    }

    @Test("Render SwiftEditRootView across active workspace states (sidebar, preview, diff, find, log tail, binary, distraction-free)")
    func renderSwiftEditRootViewActiveStates() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("root-cov-\(UUID().uuidString)")
        let sub = dir.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let mdFile = dir.appendingPathComponent("readme.md")
        let logFile = dir.appendingPathComponent("service.log")
        let binFile = dir.appendingPathComponent("blob.bin")
        let nestedFile = sub.appendingPathComponent("notes.txt")
        let mdContent = """
        ---
        title: Root View Coverage
        author: SwiftEdit
        ---

        # H1 Heading

        ## H2 Heading

        ### H3 Heading

        Paragraph with **bold**, `inline code`, [link](https://example.com), and ![img](local.png).

        1. Ordered one
        2. Ordered two

        - [ ] Task open
        - [x] Task done

        > Quoted text

        | Col1 | Col2 |
        | --- | --- |
        | A | B |

        ```swift
        let x = 1
        ```

        ---

        <div>raw html</div>
        """
        try mdContent.write(to: mdFile, atomically: true, encoding: .utf8)
        try "2026-11-22 10:00:00 ERROR failure\n2026-11-22 10:00:01 INFO recovered\n".write(to: logFile, atomically: true, encoding: .utf8)
        try Data([0x00, 0xFF, 0xFE, 0x01, 0x02, 0x00, 0x89, 0x50, 0x4E, 0x47]).write(to: binFile)
        try "nested note\n".write(to: nestedFile, atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("recovery"),
            fileSystem: LocalFileSystemAdapter()
        )
        model.openDroppedURLs([dir])
        model.openFile(at: mdFile, withinScope: dir)
        model.openFile(at: logFile, withinScope: dir)
        if let mdTab = model.tabSession.tabs.first(where: { $0.fileURL?.standardizedFileURL == mdFile.standardizedFileURL }) {
            model.activateTab(id: mdTab.id)
        }

        // State A: Expanded sidebar + Markdown split preview + Properties panel + Find & Replace + Terminal + Brand submenu
        model.toggleMarkdownPreview()
        model.presentFindBar(mode: .findAndReplace)
        let termSession = model.openTerminalSession()
        model.embeddedTerminalDidFail(id: termSession.id, message: "Offline test")
        model.headerSubmenu.pointerEntered(.trigger)
        model.appearanceMode = .light
        Self.renderInOffscreenWindow(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800))

        // State B: Black mode + Document Navigator + Diff pane + Word Wrap toggled
        model.headerSubmenu.escapePressed()
        model.toggleDocumentNavigator()
        model.toggleDiffPane()
        model.toggleWordWrap()
        model.appearanceMode = .black
        Self.renderInOffscreenWindow(SwiftEditRootView(initialModel: model), size: NSSize(width: 1280, height: 800))

        // State C: Distraction-free mode + collapsed sidebar
        model.closeDocumentNavigator()
        model.toggleDiffPane()
        model.toggleDistractionFree()
        Self.renderInOffscreenWindow(SwiftEditRootView(initialModel: model), size: NSSize(width: 1080, height: 720))
        model.toggleDistractionFree()
        model.toggleTerminalPanel()

        // State D: Log file tab with LogTail panel
        if let logTab = model.tabSession.tabs.first(where: { $0.fileURL?.standardizedFileURL == logFile.standardizedFileURL }) {
            model.activateTab(id: logTab.id)
            Self.renderInOffscreenWindow(SwiftEditRootView(initialModel: model), size: NSSize(width: 1080, height: 720))
        }

        // State E: Binary file read-only inspection view
        model.openFile(at: binFile, withinScope: dir)
        Self.renderInOffscreenWindow(SwiftEditRootView(initialModel: model), size: NSSize(width: 1080, height: 720))

        // PreviewThumbnailCache + MarkdownNativePreviewView with all block types & local gate
        let cache = PreviewThumbnailCache(countLimit: 4, totalCostLimit: 1024 * 1024)
        let img = NSImage(size: NSSize(width: 16, height: 16))
        cache.store(img, forKey: "k1", costBytes: 1024)
        #expect(cache.image(forKey: "k1") != nil)
        cache.clear()
        #expect(cache.image(forKey: "k1") == nil)

        if let mdTab = model.tabSession.tabs.first(where: { $0.fileURL?.standardizedFileURL == mdFile.standardizedFileURL }) {
            model.activateTab(id: mdTab.id)
            if let snap = model.activeDocumentSession?.snapshot {
                let doc = MarkdownPreviewProjector.project(snapshot: snap, showPreview: true)
                let gate = PreviewResourceAndLinkGate(fileSystem: LocalFileSystemAdapter(), scopeRoot: dir, documentDirectory: dir)
                Self.renderInOffscreenWindow(
                    MarkdownNativePreviewView(document: doc, palette: model.palette, gate: gate, activeSourceLine: 10),
                    size: NSSize(width: 640, height: 720)
                )
            }
        }
        #expect(model.tabSession.tabs.count >= 2)
    }

    private struct StubUpdateFetcher: HTTPDataFetching {
        let handler: @Sendable (URLRequest) async throws -> (Data, Int)
        func fetch(request: URLRequest) async throws -> (Data, Int) {
            try await handler(request)
        }
    }

    @Test("AppUpdateInstaller covers validation, download error, checksum mismatch, and extraction failure branches")
    func appUpdateInstallerErrorBranches() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("upd-cov-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fakeApp = dir.appendingPathComponent("SwiftEdit.app", isDirectory: true)
        try FileManager.default.createDirectory(at: fakeApp, withIntermediateDirectories: true)
        let validZipURL = URL(string: "https://github.com/paoloinnocenti/PH.SwiftEdit/releases/download/v1.0.0/SwiftEdit.zip")!

        // 1. Unverified host & non-zip
        let noopInstaller = AppUpdateInstaller(fetcher: StubUpdateFetcher { _ in (Data(), 200) })
        await #expect(throws: AppUpdateInstallError.unverifiedDownloadURL) {
            try await noopInstaller.stageAndScheduleInstall(
                downloadURL: URL(string: "https://evil.example.com/SwiftEdit.zip")!,
                targetBundleURL: fakeApp,
                relaunch: false
            )
        }
        await #expect(throws: AppUpdateInstallError.unverifiedDownloadURL) {
            try await noopInstaller.stageAndScheduleInstall(
                downloadURL: URL(string: "https://github.com/paoloinnocenti/PH.SwiftEdit/releases/download/v1.0.0/SwiftEdit.dmg")!,
                targetBundleURL: fakeApp,
                relaunch: false
            )
        }

        // 2. Non-.app target bundle
        await #expect(throws: AppUpdateInstallError.nonAppBundleHost) {
            try await noopInstaller.stageAndScheduleInstall(
                downloadURL: validZipURL,
                targetBundleURL: dir.appendingPathComponent("NotAnApp"),
                relaunch: false
            )
        }

        // 3. Download HTTP 500
        let failingInstaller = AppUpdateInstaller(fetcher: StubUpdateFetcher { _ in (Data(), 500) })
        await #expect(throws: AppUpdateInstallError.downloadFailed(statusCode: 500)) {
            try await failingInstaller.stageAndScheduleInstall(
                downloadURL: validZipURL,
                targetBundleURL: fakeApp,
                relaunch: false
            )
        }

        // 4. Checksum mismatch
        let mismatchInstaller = AppUpdateInstaller(fetcher: StubUpdateFetcher { req in
            if req.url?.pathExtension == "sha256" {
                return (Data("0000000000000000000000000000000000000000000000000000000000000000  SwiftEdit.zip\n".utf8), 200)
            }
            return (Data("not-a-real-zip".utf8), 200)
        })
        await #expect(throws: AppUpdateInstallError.checksumMismatch) {
            try await mismatchInstaller.stageAndScheduleInstall(
                downloadURL: validZipURL,
                targetBundleURL: fakeApp,
                relaunch: false
            )
        }

        // 5. Extraction failed (valid SHA256 of corrupt zip)
        let badZipBytes = Data("corrupt-zip-bytes".utf8)
        let badZipHash = SHA256.hash(data: badZipBytes).map { String(format: "%02x", $0) }.joined()
        let extractFailInstaller = AppUpdateInstaller(fetcher: StubUpdateFetcher { req in
            if req.url?.pathExtension == "sha256" {
                return (Data("\(badZipHash)  SwiftEdit.zip\n".utf8), 200)
            }
            return (badZipBytes, 200)
        })
        do {
            try await extractFailInstaller.stageAndScheduleInstall(
                downloadURL: validZipURL,
                targetBundleURL: fakeApp,
                relaunch: false
            )
            Issue.record("Expected extractionFailed")
        } catch let err as AppUpdateInstallError {
            if case .extractionFailed = err {
                // expected
            } else {
                Issue.record("Unexpected error: \(err)")
            }
        }
    }
}
