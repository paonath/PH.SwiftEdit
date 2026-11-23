import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("TranslucentHeaderBrandSubmenuTests")
struct TranslucentHeaderBrandSubmenuTests {

    @Test("P1: HeaderSubmenuStateMachine opens at 0 ms click/keyboard, stays sticky >= 1000 ms across hover exit, supports arrow/Home/End navigation, and keeps 36 pt height")
    func p1ClickOnlyStickyNavigationAndZeroLayoutShift() {
        // GIVEN a closed click-only state machine and command catalog
        var click = HeaderSubmenuStateMachine()
        let items = HeaderCommandCatalog.items(canSave: true, canFormat: true, showMarkdownPreview: false)

        // WHEN clicking to open, moving pointer across trigger/outside/trailingControls, waiting >= 1000 ms, and navigating items with keyboard helpers
        click.clickToggle()
        let openAt0ms = click.isOpen
        click.pointerEntered(.trigger)
        click.pointerEntered(.outside)
        click.pointerEntered(.trailingControls)
        click.advance(by: .milliseconds(1_200))
        let stillOpenAt1200ms = click.isOpen
        click.moveSelection(delta: 1, items: items)
        let secondCommand = click.selectedCommandID(in: items)
        click.selectLast(items: items)
        let lastCommand = click.selectedCommandID(in: items)
        click.selectFirst(items: items)
        let firstCommand = click.selectedCommandID(in: items)

        // THEN submenu opens in 0 ms, stays persistently open past 1000 ms regardless of hover exit, navigates cleanly, and keeps exact 36 pt height
        #expect(openAt0ms == true)
        #expect(stillOpenAt1200ms == true)
        #expect(firstCommand == .newDocument)
        #expect(secondCommand == .openFile)
        #expect(lastCommand == .showCheatSheet)
        #expect(HeaderSubmenuStateMachine.topBarHeight == 36.0)
    }

    @Test("N1: prolonged hover (>= 700 ms) and active drag never auto-open submenu; Escape, outside dismiss, and resign-key close cleanly; zero 20ms .task polling")
    func n1HoverNeverOpensAndExplicitDismissClosesCleanly() throws {
        // GIVEN closed state machines exposed to prolonged hover/drag plus open instances for dismiss checks
        var hoverMachine = HeaderSubmenuStateMachine()
        var dragMachine = HeaderSubmenuStateMachine()
        var escapeMachine = HeaderSubmenuStateMachine()
        var resignMachine = HeaderSubmenuStateMachine()

        // WHEN hovering brand trigger and trailing controls for >= 700 ms, dragging, then testing Escape and window resign-key
        hoverMachine.pointerEntered(.trigger)
        hoverMachine.advance(by: .milliseconds(750))
        hoverMachine.pointerEntered(.trailingControls)
        hoverMachine.advance(by: .milliseconds(500))

        dragMachine.setDragging(true)
        dragMachine.pointerEntered(.trigger)
        dragMachine.advance(by: .milliseconds(500))

        escapeMachine.clickToggle()
        escapeMachine.escapePressed()

        resignMachine.clickToggle()
        resignMachine.windowResignedKey()

        let rootViewURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/SwiftEditUI/Views/SwiftEditRootView.swift")
        let rootSource = try String(contentsOf: rootViewURL, encoding: .utf8)

        // THEN hover and drag never open submenu, Escape/resign-key close immediately, and SwiftEditRootView contains zero 20ms .task polling
        #expect(hoverMachine.isOpen == false)
        #expect(dragMachine.isOpen == false)
        #expect(escapeMachine.isOpen == false)
        #expect(resignMachine.isOpen == false)
        #expect(!rootSource.contains(".milliseconds(20)"))
        #expect(!rootSource.contains("model.headerSubmenu.advance("))
    }

    // MARK: - Command catalog, single-source shortcuts, format section

    @MainActor
    private static func makeModel(
        savePanelCalls: SavePanelSpy = SavePanelSpy(),
        recoveryDir: URL
    ) -> SwiftEditWorkbenchModel {
        SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir,
            systemDarkDetector: { false },
            savePanelProvider: { _ in
                savePanelCalls.count += 1
                return nil
            }
        )
    }

    final class SavePanelSpy: @unchecked Sendable {
        var count = 0
    }

    private static var repoTmp: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftEditHeader-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("P2/P3/P9: descriptive catalog titles and badges, default-off Cmd+P preview, format section in one revision, and CheatSheet entries")
    @MainActor
    func p2CatalogBadgesPreviewToggleFormatSectionAndCheatSheet() throws {
        // GIVEN a model holding two malformed headings with the selection on line 1
        let dir = Self.repoTmp
        let model = Self.makeModel(recoveryDir: dir)
        defer {
            try? FileManager.default.removeItem(at: dir)
        }
        model.newUntitledTab()
        model.handleEditorTextChanged("#BadHeading\n\n#Untouched")
        model.handleSelectionChanged(SwiftEditCore.TextRange(location: 0, length: 11))
        let revisionBefore = try #require(model.activeDocumentSession?.revision)
        let previewInitially = model.showMarkdownPreview

        // WHEN reading the catalog, toggling preview, and formatting the selected section
        let items = HeaderCommandCatalog.items(canSave: true, canFormat: true, showMarkdownPreview: model.showMarkdownPreview)
        model.toggleMarkdownPreview()
        let previewAfter = model.showMarkdownPreview
        let hideItem = HeaderCommandCatalog.items(canSave: true, canFormat: true, showMarkdownPreview: true)
            .first { $0.id == .toggleMarkdownPreview }
        model.formatActiveSection()
        let session = try #require(model.activeDocumentSession)
        let shortcuts = KeyboardShortcutsCheatSheetCatalog.allSections.flatMap(\.items).map(\.shortcut)

        // THEN titles/badges are descriptive, preview defaults off and toggles on, only line 1 is formatted in +1 revision, and the CheatSheet lists the new shortcuts
        func item(_ id: HeaderCommandID) -> HeaderCommandItem? { items.first { $0.id == id } }
        #expect(item(.duplicateLineOrSelection)?.title == "Duplicate Line or Selection")
        #expect(item(.duplicateLineOrSelection)?.shortcutBadge == "⌘D")
        #expect(item(.formatDocument)?.title == "Format Markdown Document")
        #expect(item(.formatDocument)?.shortcutBadge == "⇧⌘F")
        #expect(item(.formatSection)?.title == "Format Markdown Section")
        #expect(item(.formatSection)?.shortcutBadge == "⌥⇧⌘F")
        #expect(item(.toggleMarkdownPreview)?.title == "Show Markdown Preview")
        #expect(item(.toggleMarkdownPreview)?.shortcutBadge == "⌘P")
        #expect(hideItem?.title == "Hide Markdown Preview")
        #expect(items.allSatisfy { $0.isEnabled })
        #expect(previewInitially == false)
        #expect(previewAfter == true)
        #expect(session.text == "# BadHeading\n\n#Untouched")
        #expect(session.revision == revisionBefore.next())
        #expect(shortcuts.contains("Cmd+P"))
        #expect(shortcuts.contains("Cmd+Option+Shift+F"))
    }

    @Test("N3: formatActiveSection on an already formatted section preserves text and revision with a status message")
    @MainActor
    func n3FormatSectionOnFormattedTextIsNoOp() throws {
        // GIVEN an already formatted document with the selection on line 1
        let dir = Self.repoTmp
        let model = Self.makeModel(recoveryDir: dir)
        defer {
            try? FileManager.default.removeItem(at: dir)
        }
        model.newUntitledTab()
        model.handleEditorTextChanged("# Good\n\ntext")
        model.handleSelectionChanged(SwiftEditCore.TextRange(location: 0, length: 6))
        let revisionBefore = try #require(model.activeDocumentSession?.revision)

        // WHEN formatting the section
        model.formatActiveSection()

        // THEN nothing changes and a non-destructive message is recorded
        let session = try #require(model.activeDocumentSession)
        #expect(session.text == "# Good\n\ntext")
        #expect(session.revision == revisionBefore)
        #expect(model.statusBannerMessage != nil)
    }

    @Test("N2/N11 [Security]: binary read-only tab disables and blocks save, save-as, duplicate, and both format commands")
    @MainActor
    func n2BinaryQuarantineDisablesAndBlocksMutatingCommands() throws {
        // GIVEN an opened NUL-bearing binary file and a counting save-panel spy
        let dir = Self.repoTmp
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let binaryURL = dir.appendingPathComponent("payload.bin")
        try Data([0x50, 0x4B, 0x00, 0x04, 0x41]).write(to: binaryURL)
        let spy = SavePanelSpy()
        let model = Self.makeModel(savePanelCalls: spy, recoveryDir: dir.appendingPathComponent("rec"))
        defer {
            try? FileManager.default.removeItem(at: dir)
        }
        model.openFile(at: binaryURL, withinScope: dir)
        let session = try #require(model.activeDocumentSession)
        let revisionBefore = session.revision
        let textBefore = session.text

        // WHEN reading the catalog and invoking every mutating command
        let items = HeaderCommandCatalog.items(
            canSave: model.safetyBanner.canSave,
            canFormat: model.safetyBanner.canFormat,
            showMarkdownPreview: false
        )
        model.saveActiveDocument()
        model.saveActiveDocumentAsViaPanel()
        model.performCommandD()
        model.formatActiveDocument()
        model.formatActiveSection()
        let after = try #require(model.activeDocumentSession)

        // THEN mutating items are disabled, non-mutating ones stay enabled, and nothing changed or opened a panel
        func enabled(_ id: HeaderCommandID) -> Bool? { items.first { $0.id == id }?.isEnabled }
        #expect(model.safetyBanner.isBinaryReadOnlyBannerVisible == true)
        #expect(enabled(.saveDocument) == false)
        #expect(enabled(.saveDocumentAs) == false)
        #expect(enabled(.duplicateLineOrSelection) == false)
        #expect(enabled(.formatDocument) == false)
        #expect(enabled(.formatSection) == false)
        #expect(enabled(.newDocument) == true)
        #expect(enabled(.openFile) == true)
        #expect(enabled(.showCheatSheet) == true)
        #expect(after.revision == revisionBefore)
        #expect(after.text == textBefore)
        #expect(spy.count == 0)
    }
}
