import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Records terminal launches and can simulate a failing terminal.
@MainActor
private final class TerminalSpy: DesktopWorkspaceIntegrating {
    var launches: [URL] = []
    var failure: Error?
    func revealInFinder(itemURL: URL, withinScope scopeURL: URL?) throws {}
    func openFolderInFinder(folderURL: URL, withinScope scopeURL: URL?) throws {}
    func openInTerminal(targetURL: URL, withinScope scopeURL: URL?, explicitBundleIdentifier: String?) throws -> TerminalLaunchResolution {
        if let failure { throw failure }
        launches.append(targetURL)
        return TerminalLaunchResolution(directoryURL: targetURL, bundleIdentifier: TerminalCatalog.iTerm2BundleIdentifier)
    }
}

@Suite("TerminalPanelTests")
@MainActor
struct TerminalPanelTests {

    private static func makeModel(_ spy: TerminalSpy) -> (SwiftEditWorkbenchModel, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("term-\(UUID().uuidString)")
        let model = SwiftEditWorkbenchModel(preferencesStore: InMemoryKeyValueStore(), recentFilesStore: InMemoryKeyValueStore(),
                                            recoveryDirectoryURL: dir, desktopWorkspace: spy,
                                            systemDarkDetector: { false }, savePanelProvider: { _ in nil })
        model.userHomeDirectoryProvider = { URL(fileURLWithPath: "/Users/tester", isDirectory: true) }
        return (model, dir)
    }

    @Test("P-TERM1: Cmd+J opens the panel with a terminal in home (no folder) or the current folder, supports several sessions and closes them")
    func pToggleHomeFolderAndMultipleSessions() throws {
        // GIVEN a workbench without a folder
        let spy = TerminalSpy()
        let (model, dir) = Self.makeModel(spy)
        defer { try? FileManager.default.removeItem(at: dir) }
        // WHEN Cmd+J is pressed, a folder is opened, a second session is added, and Cmd+J is pressed again
        model.toggleTerminalPanel()
        let first = try #require(model.terminalSessions.first)
        model.selectWorkspaceFolder(dir)
        let second = model.openTerminalSession()
        let countWhileOpen = model.terminalSessions.count
        model.terminalApplicationDidTerminate(bundleIdentifier: TerminalCatalog.iTerm2BundleIdentifier)
        let afterQuit = model.terminalSessions.map(\.state)
        model.toggleTerminalPanel()
        // THEN sessions start in home then in the folder, a quit is reported per session, and closing clears them
        #expect(spy.launches.map(\.path) == ["/Users/tester", dir.standardizedFileURL.path])
        #expect(first.title == "Terminal 1" && second.title == "Terminal 2")
        #expect(countWhileOpen == 2)
        #expect(afterQuit.allSatisfy { if case .failed(let m) = $0 { m.contains("iTerm2 quit or crashed") } else { false } })
        #expect(!model.isTerminalPanelVisible && model.terminalSessions.isEmpty)
    }

    @Test("N-TERM1: a failing terminal launch is reported on the session and never crashes or blocks the app")
    func nLaunchFailureIsReported() {
        // GIVEN a terminal that cannot start
        let spy = TerminalSpy()
        spy.failure = DomainError.ioFailure("Terminal application unavailable: com.googlecode.iterm2")
        let (model, dir) = Self.makeModel(spy)
        defer { try? FileManager.default.removeItem(at: dir) }
        // WHEN the panel opens and the user keeps working
        model.toggleTerminalPanel()
        model.handleEditorTextChanged("still editing")
        // THEN the session shows the error and the editor still works
        #expect(model.isTerminalPanelVisible)
        #expect(model.terminalSessions.first.map { if case .failed(let m) = $0.state { m.contains("Terminal could not start") } else { false } } == true)
        #expect(model.activeDocumentSession?.text == "still editing")
    }
}
