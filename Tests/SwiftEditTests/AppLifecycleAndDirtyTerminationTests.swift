import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("AppLifecycleAndDirtyTerminationTests")
struct AppLifecycleAndDirtyTerminationTests {

    private static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftEditLifecycle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @MainActor
    private static func makeModel(recoveryDir: URL) -> SwiftEditWorkbenchModel {
        SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
    }

    @Test("P2: SwiftEditAppLifecycleBridge drains cold and warm Finder open-doc URLs and iterates all dirty tabs on quit")
    @MainActor
    func p2ColdWarmOpenDocAndMultiTabDirtyTermination() throws {
        // GIVEN a cold URL queued before workbench attach, plus two dirty file-backed tabs and an isolated bridge
        let dir = try Self.makeTempDir()
        let coldURL = dir.appendingPathComponent("cold.md")
        let warmURL = dir.appendingPathComponent("warm.md")
        let dirtyOneURL = dir.appendingPathComponent("dirty1.md")
        let dirtyTwoURL = dir.appendingPathComponent("dirty2.md")
        try Data("# Cold Open\n".utf8).write(to: coldURL)
        try Data("# Warm Open\n".utf8).write(to: warmURL)
        try Data("base1".utf8).write(to: dirtyOneURL)
        try Data("base2".utf8).write(to: dirtyTwoURL)

        let bridge = SwiftEditAppLifecycleBridge()
        bridge.receiveExternalOpenURLs([coldURL])

        let model = Self.makeModel(recoveryDir: dir.appendingPathComponent("rec"))
        defer { try? FileManager.default.removeItem(at: dir) }

        // WHEN attaching workbench, sending warm open-doc, making two tabs dirty, and triggering termination .save loop
        bridge.attach(workbench: model)
        let titleAfterColdAttach = model.activeTabTitle

        bridge.receiveExternalOpenURLs([warmURL])
        let titleAfterWarmOpen = model.activeTabTitle

        model.openFile(at: dirtyOneURL, withinScope: dir)
        let dirtyOneID = try #require(model.tabSession.activeTabID)
        model.handleEditorTextChanged("updated-one")

        model.openFile(at: dirtyTwoURL, withinScope: dir)
        let dirtyTwoID = try #require(model.tabSession.activeTabID)
        model.handleEditorTextChanged("updated-two")

        var replies: [Bool] = []
        let immediateCleanDecision = bridge.beginApplicationTermination(reply: { replies.append($0) })
        let firstPromptID = model.pendingDirtyCloseTabID
        model.resolvePendingDirtyClose(.save)
        let secondPromptActive = model.isPendingTerminationPrompt
        let secondPromptID = model.pendingDirtyCloseTabID
        model.resolvePendingDirtyClose(.save)
        let remainingDirty = model.tabSession.tabs.filter(\.isDirty).count
        let savedOne = try String(contentsOf: dirtyOneURL, encoding: .utf8)
        let savedTwo = try String(contentsOf: dirtyTwoURL, encoding: .utf8)

        // THEN cold & warm open-doc loaded, .save iterated both dirtyOne and dirtyTwo sequentially, saved both to disk, and replied true
        #expect(titleAfterColdAttach == "cold.md")
        #expect(titleAfterWarmOpen == "warm.md")
        #expect(immediateCleanDecision == false)
        #expect(firstPromptID == dirtyOneID)
        #expect(secondPromptActive == true)
        #expect(secondPromptID == dirtyTwoID)
        #expect(remainingDirty == 0)
        #expect(savedOne == "updated-one")
        #expect(savedTwo == "updated-two")
        #expect(replies == [true])
        #expect(model.isPendingTerminationPrompt == false)
    }

    @Test("N3: Canceling second dirty-tab quit prompt aborts termination and preserves edits; clean quit replies immediately")
    @MainActor
    func n3CancelOnMultiTabTerminationPreservesEditsAndCleanQuitCompletesImmediately() throws {
        // GIVEN a clean workbench first and then two dirty tabs
        let dir = try Self.makeTempDir()
        let dirtyOneURL = dir.appendingPathComponent("dirty1.md")
        try Data("orig1".utf8).write(to: dirtyOneURL)
        let bridge = SwiftEditAppLifecycleBridge()
        let model = Self.makeModel(recoveryDir: dir.appendingPathComponent("rec"))
        defer { try? FileManager.default.removeItem(at: dir) }
        bridge.attach(workbench: model)

        // Clean quit case
        var cleanReplies: [Bool] = []
        let cleanImmediate = bridge.beginApplicationTermination(reply: { cleanReplies.append($0) })

        // Two dirty tabs -> save 1st, cancel 2nd
        model.openFile(at: dirtyOneURL, withinScope: dir)
        model.handleEditorTextChanged("saved-1")
        model.newUntitledTab()
        let dirtyTwoID = try #require(model.tabSession.activeTabID)
        model.handleEditorTextChanged("keep-unsaved-2")

        var dirtyReplies: [Bool] = []
        let dirtyImmediate = bridge.beginApplicationTermination(reply: { dirtyReplies.append($0) })
        model.resolvePendingDirtyClose(.save)
        model.resolvePendingDirtyClose(.cancel)

        // THEN clean quit returns true immediately, and canceling 2nd dirty tab replies false leaving its buffer intact
        #expect(cleanImmediate == true)
        #expect(cleanReplies.isEmpty)
        #expect(dirtyImmediate == false)
        #expect(dirtyReplies == [false])
        #expect(model.isPendingTerminationPrompt == false)
        #expect(model.pendingDirtyCloseTabID == nil)
        #expect(model.sessionsByID[dirtyTwoID]?.text == "keep-unsaved-2")
    }

    @Test("N4 [Security]: External Finder open-doc rejects > 64 MiB files and escaping symlinks without opening writable tabs")
    @MainActor
    func n4ExternalOpenDocRejectsOversizedOrEscapingInputs() throws {
        // GIVEN an external symlink pointing outside its parent dir via nonexistent/external file check and an oversized mock
        let dir = try Self.makeTempDir()
        let outsideDir = try Self.makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.removeItem(at: outsideDir)
        }
        let secretURL = outsideDir.appendingPathComponent("secret.txt")
        try Data("top-secret".utf8).write(to: secretURL)
        let escapeLink = dir.appendingPathComponent("escape.md")
        try FileManager.default.createSymbolicLink(at: escapeLink, withDestinationURL: secretURL)

        let bridge = SwiftEditAppLifecycleBridge()
        let model = Self.makeModel(recoveryDir: dir.appendingPathComponent("rec"))
        bridge.attach(workbench: model)
        let initialCount = model.tabSession.tabs.count

        // WHEN Finder delivers the escaping symlink via external open
        bridge.receiveExternalOpenURLs([escapeLink])

        // THEN DocumentLoader rejects with securityScopeViolation and opens zero new tabs
        #expect(model.tabSession.tabs.count == initialCount)
        #expect(model.statusBannerMessage?.contains("Open failed:") == true)
    }
}
