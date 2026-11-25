import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("ContextualRevealDictationAndSessionFilterTests")
@MainActor
struct ContextualRevealDictationAndSessionFilterTests {

    @Test("P1: ElementContextualActionCatalog.groups includes Reveal in Folder Navigator and Start Dictation Here conditionally in Document group")
    func p1CatalogConditionalGroups() {
        let withAll = ElementContextualActionCatalog.groups(
            hasSelection: true,
            canRevealInFolderNavigator: true,
            canStartDictation: true
        )
        #expect(withAll.map(\.id) == ["surround", "terminal", "document"])
        let docGroupAll = withAll.first(where: { $0.id == "document" })
        #expect(docGroupAll?.actions.map(\.kind) == [
            .duplicateDocument,
            .revealInFolderNavigator,
            .startDictationHere,
        ])
        #expect(docGroupAll?.actions.map(\.title) == [
            "Duplicate Document",
            "Reveal in Folder Navigator",
            "Start Dictation Here",
        ])
        #expect(docGroupAll?.actions.map(\.iconName) == [
            "duplicate",
            "folder",
            "microphone",
        ])

        let withoutSelection = ElementContextualActionCatalog.groups(
            hasSelection: false,
            canRevealInFolderNavigator: true,
            canStartDictation: false
        )
        #expect(withoutSelection.map(\.id) == ["document"])
        #expect(withoutSelection.first?.actions.map(\.kind) == [
            .duplicateDocument,
            .revealInFolderNavigator,
        ])
    }

    @Test("N1: ElementContextualActionCatalog omits conditional document actions by default and evaluate returns nil for non-text-edit kinds")
    func n1CatalogDefaultOmissionAndEvaluateNil() {
        let defaultGroups = ElementContextualActionCatalog.groups(hasSelection: true)
        let docActions = defaultGroups.first(where: { $0.id == "document" })?.actions ?? []
        #expect(docActions.map(\.kind) == [.duplicateDocument])

        let explicitFalse = ElementContextualActionCatalog.groups(
            hasSelection: false,
            canRevealInFolderNavigator: false,
            canStartDictation: false
        )
        #expect(explicitFalse.first(where: { $0.id == "document" })?.actions.map(\.kind) == [.duplicateDocument])

        let snapshot = DocumentSession(text: "hello world").snapshot
        let selection = TextRange(location: 0, length: 5)
        #expect(ElementContextualActionCatalog.evaluate(.revealInFolderNavigator, in: snapshot, selection: selection) == nil)
        #expect(ElementContextualActionCatalog.evaluate(.startDictationHere, in: snapshot, selection: selection) == nil)
    }

    private static func makeModel(
        dir: URL,
        parentPermissionChecker: @escaping (URL) -> Bool = DotfileFolderNavigator.isDirectoryReadable,
        dictationTrigger: (@MainActor (NSTextView) -> Bool)? = nil
    ) -> SwiftEditWorkbenchModel {
        if let dictationTrigger {
            return SwiftEditWorkbenchModel(
                preferencesStore: InMemoryKeyValueStore(),
                recentFilesStore: InMemoryKeyValueStore(),
                recoveryDirectoryURL: dir.appendingPathComponent("recovery"),
                parentPermissionChecker: parentPermissionChecker,
                systemDarkDetector: { false },
                savePanelProvider: { _ in nil },
                dictationTrigger: dictationTrigger
            )
        }
        return SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("recovery"),
            parentPermissionChecker: parentPermissionChecker,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
    }

    @Test("P2: Reveal in Folder Navigator expands sidebar, navigates to containing folder preserving ancestor scope root, refreshes entries, and highlights file from Cmd+Return and NSMenu")
    func p2RevealInFolderNavigatorExpandsNavigatesAndPreservesAncestorScope() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("rev-p2-\(UUID().uuidString)")
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        let sub = workspace.appendingPathComponent("sub", isDirectory: true)
        let other = root.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = sub.appendingPathComponent("notes.md")
        try "# Notes\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let model = Self.makeModel(dir: root)
        model.openFile(at: fileURL, withinScope: workspace)

        // Case A: Sidebar collapsed and selectedFolderURL == nil -> canReveal is true
        #expect(model.isLeftSidebarCollapsed == true)
        #expect(model.selectedFolderURL == nil)
        #expect(model.canRevealActiveDocumentInFolderNavigator == true)

        // Cmd+Return palette includes Reveal in Folder Navigator
        #expect(model.presentElementContextualMenu())
        let docGroup = try #require(model.elementContextualMenu?.groups.first(where: { $0.id == "document" }))
        #expect(docGroup.actions.contains(where: { $0.kind == .revealInFolderNavigator }))

        // Invoke via performElementContextualAction
        #expect(model.performElementContextualAction(ElementContextualActionCatalog.revealInFolderNavigatorAction))
        #expect(model.isLeftSidebarCollapsed == false)
        #expect(model.selectedFolderURL?.resolvingSymlinksInPath().standardizedFileURL == sub.resolvingSymlinksInPath().standardizedFileURL)
        #expect(model.selectedSidebarEntryURL?.resolvingSymlinksInPath().standardizedFileURL == fileURL.resolvingSymlinksInPath().standardizedFileURL)
        #expect(model.folderEntries.contains(where: { $0.name == "notes.md" }))
        // Once revealed and expanded on matching canonical folder, canReveal becomes false
        #expect(model.canRevealActiveDocumentInFolderNavigator == false)

        // Case B: Ancestor workspace is selectedFolderURL & grantedScopeRootURL -> canReveal is true and preserves grantedScopeRootURL
        model.selectWorkspaceFolder(workspace)
        #expect(model.grantedScopeRootURL?.resolvingSymlinksInPath().standardizedFileURL == workspace.resolvingSymlinksInPath().standardizedFileURL)
        #expect(model.canRevealActiveDocumentInFolderNavigator == true)
        #expect(model.revealActiveDocumentInFolderNavigator())
        #expect(model.selectedFolderURL?.resolvingSymlinksInPath().standardizedFileURL == sub.resolvingSymlinksInPath().standardizedFileURL)
        #expect(model.grantedScopeRootURL?.resolvingSymlinksInPath().standardizedFileURL == workspace.resolvingSymlinksInPath().standardizedFileURL)

        // Case C: Unrelated folder open -> reveal updates grantedScopeRootURL to containing folder
        model.selectWorkspaceFolder(other)
        #expect(model.canRevealActiveDocumentInFolderNavigator == true)
        #expect(model.revealActiveDocumentInFolderNavigator())
        #expect(model.selectedFolderURL?.resolvingSymlinksInPath().standardizedFileURL == sub.resolvingSymlinksInPath().standardizedFileURL)
        #expect(model.grantedScopeRootURL?.resolvingSymlinksInPath().standardizedFileURL == sub.resolvingSymlinksInPath().standardizedFileURL)

        // Case D: Right-click NSMenu on SwiftEditNSTextView exposes Reveal in Folder Navigator when callback is wired
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.string = "# Notes"
        var revealedFromContextMenu = false
        textView.onRevealInFolderNavigator = {
            revealedFromContextMenu = true
        }
        let event = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        ))
        let menu = try #require(textView.menu(for: event))
        let revealItem = try #require(menu.items.first(where: { $0.title == "Reveal in Folder Navigator" }))
        if let action = revealItem.action {
            _ = textView.perform(action, with: revealItem)
        }
        #expect(revealedFromContextMenu == true)
    }

    @Test("N2 [Security]: Reveal in Folder Navigator hides for untitled or symlink-equivalent open folder and fails closed when parent directory is missing or unreadable")
    func n2RevealInFolderNavigatorSecurityAndOmissionGuards() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("rev-n2-\(UUID().uuidString)")
        let realFolder = root.appendingPathComponent("real", isDirectory: true)
        let symlinkFolder = root.appendingPathComponent("symlink-to-real")
        let transientFolder = root.appendingPathComponent("transient", isDirectory: true)
        try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: transientFolder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlinkFolder, withDestinationURL: realFolder)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileInReal = realFolder.appendingPathComponent("doc.md")
        try "hello".write(to: fileInReal, atomically: true, encoding: .utf8)
        let fileInTransient = transientFolder.appendingPathComponent("gone.md")
        try "temp".write(to: fileInTransient, atomically: true, encoding: .utf8)

        var parentReadable = true
        let model = Self.makeModel(dir: root, parentPermissionChecker: { _ in parentReadable })

        // 1. Untitled tab -> cannot reveal
        model.newUntitledTab()
        model.handleEditorTextChanged("untitled text")
        #expect(model.canRevealActiveDocumentInFolderNavigator == false)
        #expect(model.revealActiveDocumentInFolderNavigator() == false)

        // 2. Symlink-equivalent open folder -> canonical path matches, so canReveal is false
        model.selectWorkspaceFolder(symlinkFolder)
        model.openFile(at: fileInReal, withinScope: realFolder)
        #expect(model.isLeftSidebarCollapsed == false)
        #expect(model.canRevealActiveDocumentInFolderNavigator == false)
        #expect(model.presentElementContextualMenu())
        let docActions = model.elementContextualMenu?.groups.first(where: { $0.id == "document" })?.actions ?? []
        #expect(docActions.contains(where: { $0.kind == .revealInFolderNavigator }) == false)
        _ = model.handleEscape()

        // 3. Unreadable parent directory fails closed with banner without mutating sidebar state
        model.openFile(at: fileInTransient, withinScope: transientFolder)
        let priorSelectedFolder = model.selectedFolderURL
        parentReadable = false
        #expect(model.revealActiveDocumentInFolderNavigator() == false)
        #expect(model.selectedFolderURL == priorSelectedFolder)
        #expect(model.statusBannerMessage?.isEmpty == false)

        // 4. Deleted parent directory fails closed with banner without mutating sidebar state
        parentReadable = true
        model.statusBannerMessage = nil
        try FileManager.default.removeItem(at: transientFolder)
        #expect(model.revealActiveDocumentInFolderNavigator() == false)
        #expect(model.selectedFolderURL == priorSelectedFolder)
        #expect(model.statusBannerMessage?.isEmpty == false)
    }

    @Test("P3: Start Dictation Here is exposed in Cmd+Return and NSMenu for writable documents, closes palette, focuses editor, and dispatches dictationTrigger")
    func p3StartDictationHereWritableDocumentDispatch() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dict-p3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var triggeredTextViews: [NSTextView] = []
        let model = Self.makeModel(dir: root, dictationTrigger: { textView in
            triggeredTextViews.append(textView)
            return true
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil) }
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.isEditable = true
        textView.frame = window.contentView!.bounds
        window.contentView!.addSubview(textView)
        model.hostWindow = window

        model.newUntitledTab()
        model.handleEditorTextChanged("Hello dictation")
        #expect(model.canStartDictationHere == true)

        // Cmd+Return palette includes Start Dictation Here with microphone icon
        #expect(model.presentElementContextualMenu())
        let docGroup = try #require(model.elementContextualMenu?.groups.first(where: { $0.id == "document" }))
        let dictationAction = try #require(docGroup.actions.first(where: { $0.kind == .startDictationHere }))
        #expect(dictationAction.iconName == "microphone")
        #expect(AppIcon(rawValue: dictationAction.iconName) == .microphone)

        // Invoke via performElementContextualAction -> closes palette, focuses textView, dispatches trigger
        #expect(model.performElementContextualAction(dictationAction) == true)
        #expect(model.elementContextualMenu == nil)
        #expect(triggeredTextViews.count == 1)
        #expect(triggeredTextViews.first === textView)
        #expect(window.firstResponder === textView)
        #expect(model.activeDocumentSession?.text == "Hello dictation")

        // Right-click NSMenu on editable SwiftEditNSTextView exposes Start Dictation Here and invokes callback
        var menuDictationInvoked = false
        textView.onStartDictationHere = {
            menuDictationInvoked = true
        }
        let event = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        ))
        let menu = try #require(textView.menu(for: event))
        let dictItem = try #require(menu.items.first(where: { $0.title == "Start Dictation Here" }))
        if let action = dictItem.action {
            _ = textView.perform(action, with: dictItem)
        }
        #expect(menuDictationInvoked == true)
    }

    @Test("N3 [Security]: Start Dictation Here is omitted and refuses dispatch on binary read-only, live log-tail, or missing editable SwiftEditNSTextView")
    func n3StartDictationHereSecurityGuards() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dict-n3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var triggerCallCount = 0
        let model = Self.makeModel(dir: root, dictationTrigger: { _ in
            triggerCallCount += 1
            return true
        })

        // 1. Missing editable SwiftEditNSTextView (hostWindow is nil) -> startDictationHere returns false without calling trigger
        model.newUntitledTab()
        model.handleEditorTextChanged("writable buffer")
        #expect(model.canStartDictationHere == true)
        #expect(model.startDictationHere() == false)
        #expect(triggerCallCount == 0)

        // Attach window with non-editable textView -> still fails closed
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil) }
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.isEditable = false
        textView.frame = window.contentView!.bounds
        window.contentView!.addSubview(textView)
        model.hostWindow = window

        var menuCallbackCalled = false
        textView.onStartDictationHere = { menuCallbackCalled = true }
        let event = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        ))
        // Right-click menu on non-editable text view must omit Start Dictation Here
        let readOnlyMenu = try #require(textView.menu(for: event))
        #expect(readOnlyMenu.items.contains(where: { $0.title == "Start Dictation Here" }) == false)
        #expect(menuCallbackCalled == false)
        #expect(model.startDictationHere() == false)
        #expect(triggerCallCount == 0)

        // 2. Binary read-only inspection -> canStartDictationHere is false and startDictationHere returns false
        textView.isEditable = true
        let binaryURL = root.appendingPathComponent("sample.bin")
        try Data([0x41, 0x00, 0x42]).write(to: binaryURL)
        model.openFile(at: binaryURL, withinScope: root)
        #expect(model.activeBinaryInspection != nil)
        #expect(model.canStartDictationHere == false)
        #expect(model.startDictationHere() == false)
        #expect(triggerCallCount == 0)
        model.dismissBinaryInspection()

        // 3. Live log-tail mode -> canStartDictationHere is false and startDictationHere returns false
        let logURL = root.appendingPathComponent("app.log")
        try "2026-11-25 INFO ready\n".write(to: logURL, atomically: true, encoding: .utf8)
        model.openFile(at: logURL, withinScope: root)
        model.startLogTail(mode: .direct)
        #expect(model.activeLogTail != nil)
        #expect(model.canStartDictationHere == false)
        #expect(model.startDictationHere() == false)
        #expect(triggerCallCount == 0)
        model.stopLogTail()
    }

    @Test("P4: SessionRecoveryEligibility and workbench recovery persist and restore non-empty untitled and disk-backed/pinned tabs while skipping empty untitled tabs")
    func p4SessionRecoveryPersistsNonEmptyUntitledAndDiskBackedTabs() throws {
        #expect(SessionRecoveryEligibility.isEmptyUntitled(fileURL: nil, text: "") == true)
        #expect(SessionRecoveryEligibility.isEmptyUntitled(fileURL: nil, text: " \n\t ") == true)
        #expect(SessionRecoveryEligibility.isEmptyUntitled(fileURL: nil, text: "Draft note") == false)
        let dummyURL = URL(fileURLWithPath: "/tmp/empty-file.md")
        #expect(SessionRecoveryEligibility.isEmptyUntitled(fileURL: dummyURL, text: "") == false)
        #expect(SessionRecoveryEligibility.shouldPersistManifestEntry(fileURL: dummyURL, text: "", isBinaryReadOnly: false) == true)
        #expect(SessionRecoveryEligibility.shouldPersistManifestEntry(fileURL: nil, text: "Draft note", isBinaryReadOnly: false) == true)
        #expect(SessionRecoveryEligibility.shouldPersistManifestEntry(fileURL: nil, text: "  \n ", isBinaryReadOnly: false) == false)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("rec-p4-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let pinnedDiskFile = root.appendingPathComponent("notes.md")
        try "".write(to: pinnedDiskFile, atomically: true, encoding: .utf8) // Even an empty disk-backed file must be kept!

        let model1 = Self.makeModel(dir: root)
        // 1. Non-empty untitled tab
        model1.newUntitledTab()
        model1.handleEditorTextChanged("Draft note")
        let nonEmptyUntitledID = try #require(model1.tabSession.activeTabID)

        // 2. Pinned disk-backed tab (empty file on disk)
        model1.openFile(at: pinnedDiskFile, withinScope: root)
        let pinnedDiskID = try #require(model1.tabSession.activeTabID)
        model1.togglePin(id: pinnedDiskID)

        // 3. Empty untitled tab
        model1.newUntitledTab()
        let emptyUntitledID = try #require(model1.tabSession.activeTabID)
        #expect(model1.tabSession.tabs.count == 3)

        model1.persistRecoveryState()

        let recoveryStore = SessionRecoveryStore(recoveryDirectoryURL: root.appendingPathComponent("recovery"))
        let savedManifest = try #require(try recoveryStore.loadManifest())
        // Pinned tabs are ordered before unpinned tabs in WorkspaceTabSession
        #expect(savedManifest.tabs.map(\.id) == [pinnedDiskID, nonEmptyUntitledID])
        #expect(savedManifest.tabs.contains(where: { $0.id == emptyUntitledID }) == false)
        #expect(savedManifest.activeTabID == nonEmptyUntitledID)

        // Relaunch into a fresh workbench model
        let model2 = Self.makeModel(dir: root)
        #expect(model2.tabSession.tabs.map(\.id) == [pinnedDiskID, nonEmptyUntitledID])
        #expect(model2.sessionsByID[nonEmptyUntitledID]?.text == "Draft note")
        #expect(model2.sessionsByID[pinnedDiskID]?.fileURL?.standardizedFileURL == pinnedDiskFile.standardizedFileURL)
    }

    @Test("N4 [Security]: Empty and whitespace-only untitled tabs are excluded on save and restore, clearing a non-empty untitled tab unlinks its .recovery file, and legacy empty snapshots are purged on startup")
    func n4SessionRecoveryExcludesEmptyUntitledUnlinksClearedAndPurgesLegacySnapshots() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("rec-n4-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let recoveryDir = root.appendingPathComponent("recovery")
        let recoveryStore = SessionRecoveryStore(recoveryDirectoryURL: recoveryDir)

        // Part A: Type non-empty text in untitled tab -> snapshot created; clear to whitespace-only -> snapshot immediately unlinked
        let model1 = Self.makeModel(dir: root)
        model1.newUntitledTab()
        let untitledID = try #require(model1.tabSession.activeTabID)
        model1.handleEditorTextChanged("Temporary secret")
        model1.persistRecoveryState()
        let snapshotURL = recoveryStore.snapshotFileURL(for: untitledID)
        #expect(FileManager.default.fileExists(atPath: snapshotURL.path) == true)

        // Clear to whitespace-only and persist
        model1.handleEditorTextChanged("   \n\t  ")
        model1.persistRecoveryState()
        #expect(FileManager.default.fileExists(atPath: snapshotURL.path) == false)
        let manifestAfterClear = try #require(try recoveryStore.loadManifest())
        #expect(manifestAfterClear.tabs.isEmpty)
        #expect(manifestAfterClear.activeTabID == nil)

        // Part B: Simulate a legacy on-disk manifest containing an empty untitled tab, a whitespace-only untitled tab, and a valid non-empty untitled tab
        let legacyEmptyID = DocumentID()
        let legacyWhitespaceID = DocumentID()
        let legacyValidID = DocumentID()
        try recoveryStore.saveRecoverySnapshot(DocumentSnapshot(
            id: legacyEmptyID,
            revision: BufferRevision(1),
            text: "",
            encoding: .utf8,
            lineEnding: .lf,
            isDegradedPlainText: false,
            isBinaryReadOnly: false
        ))
        try recoveryStore.saveRecoverySnapshot(DocumentSnapshot(
            id: legacyWhitespaceID,
            revision: BufferRevision(1),
            text: "  \n\t ",
            encoding: .utf8,
            lineEnding: .lf,
            isDegradedPlainText: false,
            isBinaryReadOnly: false
        ))
        try recoveryStore.saveRecoverySnapshot(DocumentSnapshot(
            id: legacyValidID,
            revision: BufferRevision(2),
            text: "Keep me",
            encoding: .utf8,
            lineEnding: .lf,
            isDegradedPlainText: false,
            isBinaryReadOnly: false
        ))
        let legacyManifest = SessionRecoveryManifest(
            tabs: [
                TabDescriptor(id: legacyEmptyID, title: "Untitled", fileURL: nil, isPinned: false, isDirty: false, revision: BufferRevision(1)),
                TabDescriptor(id: legacyWhitespaceID, title: "Untitled 2", fileURL: nil, isPinned: false, isDirty: true, revision: BufferRevision(1)),
                TabDescriptor(id: legacyValidID, title: "Keep me", fileURL: nil, isPinned: false, isDirty: true, revision: BufferRevision(2)),
            ],
            activeTabID: legacyWhitespaceID
        )
        try recoveryStore.saveManifest(legacyManifest)
        #expect(FileManager.default.fileExists(atPath: recoveryStore.snapshotFileURL(for: legacyEmptyID).path) == true)
        #expect(FileManager.default.fileExists(atPath: recoveryStore.snapshotFileURL(for: legacyWhitespaceID).path) == true)

        // Startup restoration must skip both empty/whitespace untitled tabs, fall back activeTabID to legacyValidID, and purge their .recovery files
        let model2 = Self.makeModel(dir: root)
        #expect(model2.tabSession.tabs.map(\.id) == [legacyValidID])
        #expect(model2.tabSession.activeTabID == legacyValidID)
        #expect(FileManager.default.fileExists(atPath: recoveryStore.snapshotFileURL(for: legacyEmptyID).path) == false)
        #expect(FileManager.default.fileExists(atPath: recoveryStore.snapshotFileURL(for: legacyWhitespaceID).path) == false)
        #expect(FileManager.default.fileExists(atPath: recoveryStore.snapshotFileURL(for: legacyValidID).path) == true)
    }
}
