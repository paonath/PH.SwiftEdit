import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("TranslucentHeaderBrandSubmenuTests")
struct TranslucentHeaderBrandSubmenuTests {

    @Test("P1: HeaderSubmenuStateMachine opens at 120 ms dwell or 0 ms click, bridges 180 ms travel, ignores trailing controls, and keeps 36 pt header height")
    func p1DwellClickTravelAndZeroLayoutShift() {
        // GIVEN a closed state machine
        var dwell = HeaderSubmenuStateMachine()
        var click = HeaderSubmenuStateMachine()
        var travel = HeaderSubmenuStateMachine()
        var trailing = HeaderSubmenuStateMachine()

        // WHEN dwelling 119 ms then 1 ms, clicking, traveling to the panel within 180 ms, and hovering trailing controls
        dwell.pointerEntered(.trigger)
        dwell.advance(by: .milliseconds(119))
        let openAt119 = dwell.isOpen
        dwell.advance(by: .milliseconds(1))

        click.clickToggle()

        travel.clickToggle()
        travel.pointerEntered(.trigger)
        travel.pointerEntered(.outside)
        travel.advance(by: .milliseconds(179))
        travel.pointerEntered(.panel)
        travel.advance(by: .milliseconds(500))

        trailing.pointerEntered(.trailingControls)
        trailing.advance(by: .milliseconds(1000))

        // THEN open at exactly 120 ms, instantly on click, stays open through travel, never opens from trailing hover, header stays 36 pt
        #expect(openAt119 == false)
        #expect(dwell.isOpen == true)
        #expect(click.isOpen == true)
        #expect(travel.isOpen == true)
        #expect(trailing.isOpen == false)
        #expect(HeaderSubmenuStateMachine.topBarHeight == 36.0)
    }

    @Test("N1: sub-120 ms pass-through and active drag keep submenu closed, and Escape closes immediately and latches until pointer exit")
    func n1PassThroughDragAndEscapeLatch() {
        // GIVEN state machines for pass-through, drag, and an open submenu hovered on the trigger
        var passThrough = HeaderSubmenuStateMachine()
        var dragging = HeaderSubmenuStateMachine()
        var latched = HeaderSubmenuStateMachine()

        // WHEN 90 ms pass-through, drag with 500 ms dwell, and Escape while open over the trigger then more dwell, then pointer exit and re-entry
        passThrough.pointerEntered(.trigger)
        passThrough.advance(by: .milliseconds(90))
        passThrough.pointerEntered(.outside)
        passThrough.advance(by: .milliseconds(500))

        dragging.setDragging(true)
        dragging.pointerEntered(.trigger)
        dragging.advance(by: .milliseconds(500))

        latched.clickToggle()
        latched.pointerEntered(.trigger)
        latched.escapePressed()
        let closedAfterEscape = latched.isOpen
        let suppressedAfterEscape = latched.isSuppressedUntilPointerExit
        latched.advance(by: .milliseconds(500))
        let stillClosedWhileLatched = latched.isOpen
        latched.pointerEntered(.outside)
        latched.pointerEntered(.trigger)
        latched.advance(by: .milliseconds(120))

        // THEN pass-through and drag never open, Escape closes and latches, and re-entry after exit reopens after dwell
        #expect(passThrough.isOpen == false)
        #expect(dragging.isOpen == false)
        #expect(closedAfterEscape == false)
        #expect(suppressedAfterEscape == true)
        #expect(stillClosedWhileLatched == false)
        #expect(latched.isSuppressedUntilPointerExit == false)
        #expect(latched.isOpen == true)
    }

    @Test("N12: active sidebar divider drag blocks submenu hover opening")
    func n12DragBlocksHoverOpen() {
        // GIVEN a drag in progress
        var machine = HeaderSubmenuStateMachine()
        machine.setDragging(true)

        // WHEN the pointer dwells on the trigger for 120 ms
        machine.pointerEntered(.trigger)
        machine.advance(by: .milliseconds(120))

        // THEN the submenu stays closed
        #expect(machine.isOpen == false)
    }

    // MARK: - Command catalog, single-source shortcuts, format section

    @MainActor
    private static func makeModel(
        savePanelCalls: SavePanelSpy = SavePanelSpy(),
        recoveryDir: URL
    ) -> (SwiftEditWorkbenchModel, String) {
        let suite = "it.ph.SwiftEdit.test.header.\(UUID().uuidString)"
        let model = SwiftEditWorkbenchModel(
            preferencesSuiteName: suite,
            recentFilesSuiteName: "\(suite).recent",
            recoveryDirectoryURL: recoveryDir,
            systemDarkDetector: { false },
            savePanelProvider: { _ in
                savePanelCalls.count += 1
                return nil
            }
        )
        return (model, suite)
    }

    final class SavePanelSpy: @unchecked Sendable {
        var count = 0
    }

    private static var repoTmp: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".tmp/test-results/header-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("P2/P3/P9: descriptive catalog titles and badges, default-off Cmd+P preview, format section in one revision, and CheatSheet entries")
    @MainActor
    func p2CatalogBadgesPreviewToggleFormatSectionAndCheatSheet() throws {
        // GIVEN a model holding two malformed headings with the selection on line 1
        let dir = Self.repoTmp
        let (model, suite) = Self.makeModel(recoveryDir: dir)
        defer {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: dir)
        }
        model.handleEditorTextChanged("#BadHeading\n\n#Untouched")
        model.handleSelectionChanged(SwiftEditCore.TextRange(location: 0, length: 11))
        let revisionBefore = try #require(model.activeDocumentSession?.revision)
        let previewInitially = model.showMarkdownPreview

        // WHEN reading the catalog, toggling preview, and formatting the selected section
        let items = HeaderCommandCatalog.items(canSave: true, canFormat: true, showMarkdownPreview: model.showMarkdownPreview, showDiffPane: false)
        model.toggleMarkdownPreview()
        let previewAfter = model.showMarkdownPreview
        let hideItem = HeaderCommandCatalog.items(canSave: true, canFormat: true, showMarkdownPreview: true, showDiffPane: false)
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
        let (model, suite) = Self.makeModel(recoveryDir: dir)
        defer {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: dir)
        }
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
        let (model, suite) = Self.makeModel(savePanelCalls: spy, recoveryDir: dir.appendingPathComponent("rec"))
        defer {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
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
            showMarkdownPreview: false,
            showDiffPane: false
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
