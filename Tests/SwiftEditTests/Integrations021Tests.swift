import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Spec 021: bundle size, header layout and zoom, clickable/searchable shortcuts panel, Duplicate Document.
@Suite("Integrations021Tests", .serialized)
@MainActor
struct Integrations021Tests {

    private static func makeModel(recovery: URL = FileManager.default.temporaryDirectory.appendingPathComponent("i021-\(UUID().uuidString)")) -> SwiftEditWorkbenchModel {
        SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recovery,
            fileSystem: LocalFileSystemAdapter(),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
    }

    private static func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dup021-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: Duplicate Document

    @Test("P-DUP1: copy names keep the extension, count up and handle dotfiles and extensionless names")
    func pDuplicateNaming() {
        #expect(DuplicateDocumentNaming.copyName(for: "note.md", attempt: 1) == "note copy.md")
        #expect(DuplicateDocumentNaming.copyName(for: "note.md", attempt: 2) == "note copy 2.md")
        #expect(DuplicateDocumentNaming.copyName(for: ".env", attempt: 1) == ".env copy")
        #expect(DuplicateDocumentNaming.copyName(for: "Makefile", attempt: 3) == "Makefile copy 3")
        let source = URL(fileURLWithPath: "/tmp/x/a.md")
        let taken: Set<String> = ["/tmp/x/a copy.md", "/tmp/x/a copy 2.md"]
        #expect(DuplicateDocumentNaming.copyURL(for: source, exists: { taken.contains($0.path) })?.lastPathComponent == "a copy 3.md")
        #expect(DuplicateDocumentNaming.copyURL(for: source, exists: { _ in true }) == nil)
    }

    @Test("P-DUP2: a file-backed document is copied (with unsaved edits) next to itself and opened right after its tab")
    func pDuplicateFileBackedDocument() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("a.md")
        try "# Title\n".write(to: source, atomically: true, encoding: .utf8)
        let model = Self.makeModel(recovery: dir.appendingPathComponent("rec"))
        model.newUntitledTab()
        model.openFile(at: source, withinScope: dir)
        model.handleEditorTextChanged("# Title\nunsaved line\n")
        let sourceID = try #require(model.tabSession.activeTabID)
        let sourceIndex = try #require(model.tabSession.tabs.firstIndex { $0.id == sourceID })

        #expect(model.duplicateActiveDocument())

        let copyURL = dir.appendingPathComponent("a copy.md")
        #expect(try String(contentsOf: copyURL, encoding: .utf8) == "# Title\nunsaved line\n")
        #expect(try String(contentsOf: source, encoding: .utf8) == "# Title\n")
        let newIndex = try #require(model.tabSession.tabs.firstIndex { $0.id == model.tabSession.activeTabID })
        #expect(newIndex == sourceIndex + 1)
        #expect(model.tabSession.tabs[newIndex].title == "a copy.md")
    }

    @Test("P-DUP3: an in-memory document is duplicated only in memory")
    func pDuplicateInMemoryDocument() throws {
        let model = Self.makeModel()
        model.handleEditorTextChanged("scratch notes")
        let before = model.tabSession.tabs.count
        #expect(model.duplicateActiveDocument())
        #expect(model.tabSession.tabs.count == before + 1)
        #expect(model.activeDocumentSession?.fileURL == nil)
        #expect(model.activeDocumentSession?.text == "scratch notes")
    }

    @Test("N-DUP1: an existing copy is never overwritten and binary documents are refused")
    func nDuplicateNeverOverwrites() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("b.txt")
        try "new".write(to: source, atomically: true, encoding: .utf8)
        let existing = dir.appendingPathComponent("b copy.txt")
        try "keep me".write(to: existing, atomically: true, encoding: .utf8)
        let model = Self.makeModel(recovery: dir.appendingPathComponent("rec"))
        model.openFile(at: source, withinScope: dir)
        #expect(model.duplicateActiveDocument())
        #expect(try String(contentsOf: existing, encoding: .utf8) == "keep me")
        #expect(try String(contentsOf: dir.appendingPathComponent("b copy 2.txt"), encoding: .utf8) == "new")

        let binary = dir.appendingPathComponent("blob.bin")
        try Data([0, 1, 2, 0, 255, 0]).write(to: binary)
        model.openFile(at: binary, withinScope: dir)
        #expect(model.duplicateActiveDocument() == false)
    }

    @Test("P-DUP4: the contextual palette Duplicate Document action runs the duplicate")
    func pDuplicateFromContextualPalette() {
        let model = Self.makeModel()
        model.handleEditorTextChanged("palette")
        let before = model.tabSession.tabs.count
        #expect(model.presentElementContextualMenu())
        let action = ElementContextualActionCatalog.documentGroup.actions[0]
        #expect(model.performElementContextualAction(action))
        #expect(model.tabSession.tabs.count == before + 1)
    }

    // MARK: Shortcuts panel

    @Test("P-CS1: search matches title, description and shortcut in symbol or word form")
    func pCheatSheetSearch() {
        let all = KeyboardShortcutsCheatSheetCatalog.allSections.flatMap(\.items)
        func titles(_ q: String) -> [String] { KeyboardShortcutsCheatSheetCatalog.sections(matching: q).flatMap(\.items).map(\.title) }
        #expect(titles("⇧⌘D").contains("Toggle File Compare Diff"))
        #expect(titles("cmd shift d").contains("Toggle File Compare Diff"))
        #expect(titles("word wrap").contains("Toggle Word Wrap"))
        #expect(titles("pasteboard").contains("Copy"))
        #expect(KeyboardShortcutsCheatSheetCatalog.sections(matching: "zzzz").isEmpty)
        #expect(KeyboardShortcutsCheatSheetCatalog.sections(matching: "").flatMap(\.items).count == all.count)
        // Every mapped title exists and documentation-only rows stay unmapped.
        let catalogTitles = Set(all.map(\.title))
        #expect(KeyboardShortcutsCheatSheetCatalog.commandsByTitle.keys.allSatisfy { catalogTitles.contains($0) })
        #expect(all.first { $0.title == "Accept Word Completion" }?.command == nil)
        #expect(all.first { $0.title == "Reorder Tabs" }?.command == nil)
    }

    @Test("P-CS2: clicking rows runs workbench commands; Option+Cmd+/ toggles the side panel")
    func pCheatSheetCommandsRun() {
        let model = Self.makeModel()
        model.handleEditorTextChanged("text")
        let zoom = model.zoomController.zoomPercent
        model.performCheatSheetCommand(.zoomIn)
        #expect(model.zoomController.zoomPercent > zoom)
        let tabs = model.tabSession.tabs.count
        model.performCheatSheetCommand(.newDocument)
        #expect(model.tabSession.tabs.count == tabs + 1)
        model.performCheatSheetCommand(.toggleCompare)
        #expect(model.showDiffPane)
        #expect(model.isShortcutsPanelVisible == false)
        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "÷", charactersIgnoringModifiers: "/", modifiers: [.command, .option]), model: model))
        #expect(model.isShortcutsPanelVisible)
        model.performCheatSheetCommand(.toggleShortcutsPanel)
        #expect(model.isShortcutsPanelVisible == false)
    }

    // MARK: Header

    @Test("P-HDR1: header and SwiftEdit menu sizes follow the editor zoom; targets keep the 24 pt floor")
    func pHeaderScalesWithZoom() {
        let base = ZoomedChromeMetrics(zoomPercent: 100)
        let double = ZoomedChromeMetrics(zoomPercent: 200)
        let half = ZoomedChromeMetrics(zoomPercent: 50)
        #expect(double.headerIconSize == 2 * base.headerIconSize)
        #expect(double.menuFontSize == 2 * base.menuFontSize)
        #expect(double.headerLogoSize == 2 * base.headerLogoSize)
        #expect(double.headerHeight == 2 * base.headerHeight)
        #expect(half.headerIconSize < base.headerIconSize)
        #expect(half.headerIconButtonHeight >= ChromeHitTarget.minimumPoints)
        #expect(half.headerHeight >= ChromeHitTarget.minimumPoints)
    }

    @Test("P-HDR2: command icons sit next to the SwiftEdit menu and the document title is on the right")
    func pHeaderOrder() throws {
        let source = AuditReportFitness.read("Sources/SwiftEditUI/Views/SwiftEditRootView.swift")
        let start = try #require(source.range(of: "private var toolbarBar: some View"))
        let header = String(source[start.lowerBound...].prefix(5000))
        let menu = try #require(header.range(of: "SwiftEditBrandLogoView(")).lowerBound
        let icons = try #require(header.range(of: "headerIconButton(.sidebar")).lowerBound
        let spacer = try #require(header.range(of: "Spacer(minLength: 8)")).lowerBound
        let title = try #require(header.range(of: "headerBreadcrumb\n")).lowerBound
        #expect(menu < icons && icons < spacer && spacer < title)
    }
}
