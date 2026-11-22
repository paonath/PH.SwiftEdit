import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("AllKeyboardShortcutsDispatchTests")
@MainActor
struct AllKeyboardShortcutsDispatchTests {

    private static let scope = URL(fileURLWithPath: "/fixtures/shortcuts")

    private static func makeWorkbench(
        opening files: [(name: String, text: String)] = [("note.md", "# Heading\nhello world\n")],
        openPanelResult: URL? = nil,
        savePanelResult: URL? = nil
    ) -> (SwiftEditWorkbenchModel, InMemoryFileSystemFake, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("shortcuts-\(UUID().uuidString)")
        let fs = InMemoryFileSystemFake()
        for file in files {
            fs.seed(url: scope.appendingPathComponent(file.name), data: Data(file.text.utf8))
        }
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir,
            fileSystem: fs,
            systemDarkDetector: { false },
            savePanelProvider: { _ in savePanelResult },
            openPanelProvider: { _, _ in openPanelResult }
        )
        for file in files {
            model.openFile(at: scope.appendingPathComponent(file.name), withinScope: scope)
        }
        return (model, fs, dir)
    }

    @Test("P1: Option+Backslash toggles Document Navigator on Markdown and YAML tabs across ANSI and ISO layouts")
    func p1OptionBackslashTogglesNavigatorOnMarkdownAndYAML() {
        // GIVEN a workbench with both Markdown and YAML tabs
        let (model, _, dir) = Self.makeWorkbench(opening: [
            ("doc.md", "# Alpha\n## Beta\n"),
            ("config.yaml", "server:\n  port: 8080\n"),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }

        // WHEN pressing Option+\ on the YAML tab (ISO keyCode 10) and then Option+\ again (ANSI keyCode 42, Option char '«')
        let yamlOpened = SwiftEditShortcutDispatcher.dispatch(
            ShortcutKeyEvent(characters: "«", charactersIgnoringModifiers: "\\", keyCode: 10, modifiers: [.option]),
            model: model
        )
        let yamlTitles = model.navigatorState?.headings.map(\.title)
        let yamlClosed = SwiftEditShortcutDispatcher.dispatch(
            ShortcutKeyEvent(characters: "«", charactersIgnoringModifiers: "\\", keyCode: 42, modifiers: [.option]),
            model: model
        )

        // AND switching to the Markdown tab and toggling Option+\ open and closed
        let mdID = model.tabSession.tabs.first { $0.title == "doc.md" }!.id
        model.activateTab(id: mdID)
        let mdOpened = SwiftEditShortcutDispatcher.dispatch(
            ShortcutKeyEvent(characters: "«", charactersIgnoringModifiers: "\\", keyCode: 42, modifiers: [.option]),
            model: model
        )
        let mdTitles = model.navigatorState?.headings.map(\.title)
        let mdClosed = SwiftEditShortcutDispatcher.dispatch(
            ShortcutKeyEvent(characters: "«", charactersIgnoringModifiers: "\\", keyCode: 42, modifiers: [.option]),
            model: model
        )

        // THEN Document Navigator opens and closes cleanly on both Markdown and YAML tabs
        #expect(yamlOpened == true)
        #expect(yamlTitles == ["server"])
        #expect(yamlClosed == true)
        #expect(mdOpened == true)
        #expect(mdTitles == ["Alpha", "Beta"])
        #expect(mdClosed == true)
        #expect(model.navigatorState == nil)
    }

    @Test("P2: All File, Edit, Navigation, and View global shortcuts dispatch accurately")
    func p2AllFileEditNavigationAndViewShortcutsWork() throws {
        // GIVEN an isolated workspace folder on disk with two files and injectable open/save panels
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("shortcuts-disk-\(UUID().uuidString)", isDirectory: true)
        let folder = tempRoot.appendingPathComponent("workspace", isDirectory: true)
        let noteFile = tempRoot.appendingPathComponent("note.md")
        let saveAsFile = tempRoot.appendingPathComponent("saved-as.md")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("# Title\n\nline one\n".utf8).write(to: noteFile)
        try Data("# A\n".utf8).write(to: folder.appendingPathComponent("a.md"))
        try Data("# B\n".utf8).write(to: folder.appendingPathComponent("b.md"))
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempRoot.appendingPathComponent("recovery", isDirectory: true),
            systemDarkDetector: { false },
            savePanelProvider: { _ in saveAsFile },
            openPanelProvider: { _, _ in folder }
        )
        model.openFile(at: noteFile, withinScope: tempRoot)
        let noteID = try #require(model.tabSession.activeTabID)

        // WHEN dispatching Cmd+N, Cmd+W, Cmd+D, Cmd+S, Cmd+Shift+S, Cmd+Shift+O, Cmd+Shift+Option+O
        let cmdN = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "n", modifiers: [.command]), model: model)
        let countAfterN = model.tabSession.tabs.count
        let cmdWWrapOff = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "w", modifiers: [.command]), model: model)
        #expect(cmdWWrapOff && !model.isWordWrapEnabled)
        let cmdWWrapOn = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "w", modifiers: [.command]), model: model)
        #expect(cmdWWrapOn && model.isWordWrapEnabled)
        let cmdW = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "W", charactersIgnoringModifiers: "w", modifiers: [.command, .shift]), model: model)
        let dirtyPromptTriggered = (model.pendingDirtyCloseTabID != nil)
        model.resolvePendingDirtyClose(.dontSave)
        let countAfterW = model.tabSession.tabs.count
        model.activateTab(id: noteID)
        let cmdD = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "d", modifiers: [.command]), model: model)
        let textAfterD = model.activeDocumentSession?.text
        let cmdS = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "s", modifiers: [.command]), model: model)
        let dirtyAfterS = model.activeDocumentSession?.isDirty
        let cmdShiftS = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "S", charactersIgnoringModifiers: "s", modifiers: [.command, .shift]), model: model)
        let titleAfterSaveAs = model.activeTabTitle
        let cmdShiftO = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "O", charactersIgnoringModifiers: "o", modifiers: [.command, .shift]), model: model)
        let folderAfterShiftO = model.selectedFolderURL
        let cmdShiftOptO = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "O", charactersIgnoringModifiers: "o", modifiers: [.command, .shift, .option]), model: model)
        let countAfterBatch = model.tabSession.tabs.count

        // AND Find / Replace / Go to Line / Format / Sidebar / Zoom / Preview / CheatSheet / Distraction-Free
        let cmdF = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "f", modifiers: [.command]), model: model)
        let modeF = model.findReplaceState.mode
        let cmdOptF = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "ƒ", charactersIgnoringModifiers: "f", modifiers: [.command, .option]), model: model)
        let modeOptF = model.findReplaceState.mode
        let cmdG = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "g", modifiers: [.command]), model: model)
        let modeG = model.findReplaceState.mode
        let sidebarBefore = model.isLeftSidebarCollapsed
        let cmdB = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "b", modifiers: [.command]), model: model)
        let sidebarAfter = model.isLeftSidebarCollapsed
        let cmdPlusUS = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "=", modifiers: [.command]), model: model)
        let zoomAfterUS = model.zoomController.zoomPercent
        let cmdPlusShift = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "+", charactersIgnoringModifiers: "=", modifiers: [.command, .shift]), model: model)
        let zoomAfterShift = model.zoomController.zoomPercent
        let cmdMinus = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "-", modifiers: [.command]), model: model)
        let zoomAfterMinus = model.zoomController.zoomPercent
        let cmdZero = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "0", modifiers: [.command]), model: model)
        let zoomAfterZero = model.zoomController.zoomPercent
        let cmdP = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "p", modifiers: [.command]), model: model)
        let previewAfterP = model.showMarkdownPreview
        let cmdSlashUS = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "/", modifiers: [.command]), model: model)
        let cheatUS = model.isCheatSheetPresented
        model.isCheatSheetPresented = false
        let cmdSlashIT = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "/", charactersIgnoringModifiers: "7", keyCode: 26, modifiers: [.command, .shift]), model: model)
        let cheatIT = model.isCheatSheetPresented
        let opt1 = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "¡", charactersIgnoringModifiers: "1", keyCode: 18, modifiers: [.option]), model: model)
        let dfAfterOpt1 = model.isDistractionFree
        let cmdShiftF = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "F", charactersIgnoringModifiers: "f", modifiers: [.command, .shift]), model: model)
        let cmdShiftOptF = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "F", charactersIgnoringModifiers: "f", modifiers: [.command, .shift, .option]), model: model)

        // THEN every single command executes as specified
        #expect(cmdN && countAfterN == 3)
        #expect(cmdW && dirtyPromptTriggered && countAfterW == 2)
        #expect(cmdD && textAfterD == "# Title\n# Title\n\nline one\n")
        #expect(cmdS && dirtyAfterS == false)
        #expect(cmdShiftS && titleAfterSaveAs == "saved-as.md")
        #expect(cmdShiftO && folderAfterShiftO == folder.standardizedFileURL)
        #expect(cmdShiftOptO && countAfterBatch == 4)
        #expect(cmdF && modeF == .find)
        #expect(cmdOptF && modeOptF == .findAndReplace)
        #expect(cmdG && modeG == .goToLine)
        #expect(cmdB && sidebarAfter != sidebarBefore)
        #expect(cmdPlusUS && zoomAfterUS == 110)
        #expect(cmdPlusShift && zoomAfterShift == 120)
        #expect(cmdMinus && zoomAfterMinus == 110)
        #expect(cmdZero && zoomAfterZero == 100)
        #expect(cmdP && previewAfterP == true)
        #expect(cmdSlashUS && cheatUS == true)
        #expect(cmdSlashIT && cheatIT == true)
        #expect(opt1 && dfAfterOpt1 == true)
        #expect(cmdShiftF && cmdShiftOptF)
    }

    @Test("P3: Cmd+O opens file via openPanelProvider and all 16 Markdown formatting/heading/diagnostics shortcuts dispatch")
    func p3OpenFileAndAllMarkdownShortcutsDispatch() {
        // GIVEN a Markdown tab with a selected word
        let targetFile = Self.scope.appendingPathComponent("target.md")
        let (model, fs, dir) = Self.makeWorkbench(
            opening: [("md.md", "word\n")],
            openPanelResult: targetFile
        )
        defer { try? FileManager.default.removeItem(at: dir) }
        fs.seed(url: targetFile, data: Data("opened\n".utf8))

        // WHEN invoking Cmd+O
        let cmdO = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "o", modifiers: [.command]), model: model)
        let openedTitle = model.activeTabTitle

        // AND switching back to md.md and running every Markdown command shortcut
        let mdID = model.tabSession.tabs.first { $0.title == "md.md" }!.id
        model.activateTab(id: mdID)
        model.handleSelectionChanged(SwiftEditCore.TextRange(location: 0, length: 4))

        let bold = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "B", charactersIgnoringModifiers: "b", modifiers: [.command, .shift]), model: model)
        let italic = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "i", modifiers: [.command]), model: model)
        let strike = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "X", charactersIgnoringModifiers: "x", modifiers: [.command, .shift]), model: model)
        let inlineCode = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "e", modifiers: [.command]), model: model)
        let fence = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "C", charactersIgnoringModifiers: "c", modifiers: [.command, .shift]), model: model)
        let link = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "k", modifiers: [.command]), model: model)
        let image = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "I", charactersIgnoringModifiers: "i", modifiers: [.command, .shift]), model: model)
        let task = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "¬", charactersIgnoringModifiers: "l", modifiers: [.command, .option]), model: model)
        let quoteIT = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: ":", charactersIgnoringModifiers: ".", keyCode: 47, modifiers: [.command, .shift]), model: model)
        let table = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "†", charactersIgnoringModifiers: "t", modifiers: [.command, .option]), model: model)
        let diag = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "M", charactersIgnoringModifiers: "m", modifiers: [.command, .shift]), model: model)
        let popoverOpened = model.isDiagnosticsPopoverPresented
        let h1 = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "1", modifiers: [.command, .control]), model: model)
        let h2 = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "2", modifiers: [.command, .control]), model: model)
        let h3 = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "3", modifiers: [.command, .control]), model: model)
        let h4 = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "4", modifiers: [.command, .control]), model: model)
        let h5 = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "5", modifiers: [.command, .control]), model: model)
        let h6 = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "6", modifiers: [.command, .control]), model: model)

        // THEN every file-open and Markdown shortcut dispatches cleanly
        #expect(cmdO && openedTitle == "target.md")
        #expect(bold && italic && strike && inlineCode && fence)
        #expect(link && image && task && quoteIT && table)
        #expect(diag && popoverOpened == true)
        #expect(h1 && h2 && h3 && h4 && h5 && h6)
    }

    @Test("N1 [Security]: Binary read-only quarantine blocks mutating shortcuts and overlay text fields preserve text-editing keys")
    func n1QuarantineAndOverlayTextFieldGuards() {
        // GIVEN a quarantined binary file and an active overlay text field state
        let (model, fs, dir) = Self.makeWorkbench(opening: [("plain.md", "abc\n")])
        defer { try? FileManager.default.removeItem(at: dir) }
        let binURL = Self.scope.appendingPathComponent("img.bin")
        fs.seed(url: binURL, data: Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x01]))
        model.openFile(at: binURL, withinScope: Self.scope)

        // WHEN dispatching mutating and navigator shortcuts on a binary inspection
        let optBackslashOnBin = SwiftEditShortcutDispatcher.dispatch(
            ShortcutKeyEvent(characters: "«", charactersIgnoringModifiers: "\\", keyCode: 42, modifiers: [.option]),
            model: model
        )
        let cmdDOnBin = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "d", modifiers: [.command]), model: model)
        let boldOnBin = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "B", charactersIgnoringModifiers: "b", modifiers: [.command, .shift]), model: model)
        let navDuringBin = model.navigatorState
        let binActiveDuringMutate = (model.activeBinaryInspection != nil)

        // AND dispatching editor vs navigation shortcuts while an overlay text field has focus
        model.dismissBinaryInspection()
        let overlayBlocksBold = SwiftEditShortcutDispatcher.dispatch(
            ShortcutKeyEvent(characters: "B", charactersIgnoringModifiers: "b", modifiers: [.command, .shift]),
            model: model,
            isEditingOverlayTextField: true
        )
        let overlayBlocksInlineCode = SwiftEditShortcutDispatcher.dispatch(
            ShortcutKeyEvent(characters: "e", modifiers: [.command]),
            model: model,
            isEditingOverlayTextField: true
        )
        let overlayAllowsOptBackslash = SwiftEditShortcutDispatcher.dispatch(
            ShortcutKeyEvent(characters: "«", charactersIgnoringModifiers: "\\", keyCode: 42, modifiers: [.option]),
            model: model,
            isEditingOverlayTextField: true
        )

        // THEN binary quarantine blocks mutations/navigator while consuming the keys, and overlays pass editing keys through
        #expect(optBackslashOnBin && navDuringBin == nil)
        #expect(cmdDOnBin && boldOnBin && binActiveDuringMutate)
        #expect(overlayBlocksBold == false)
        #expect(overlayBlocksInlineCode == false)
        #expect(overlayAllowsOptBackslash == true && model.navigatorState != nil)
    }
}
