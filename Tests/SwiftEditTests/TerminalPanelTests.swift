import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("TerminalPanelTests", .serialized)
@MainActor
struct TerminalPanelTests {

    private static func makeModel() -> (SwiftEditWorkbenchModel, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("term-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.userHomeDirectoryProvider = { URL(fileURLWithPath: "/Users/tester", isDirectory: true) }
        return (model, dir)
    }

    @Test("P-TERM1: Cmd+J opens embedded terminal in home or current folder, supports multiple sessions, and closes all cleanly")
    func pToggleHomeFolderAndMultipleSessions() throws {
        let (model, dir) = Self.makeModel()
        defer { try? FileManager.default.removeItem(at: dir) }

        model.toggleTerminalPanel()
        let first = try #require(model.terminalSessions.first)
        model.selectWorkspaceFolder(dir)
        let second = model.openTerminalSession()
        let countWhileOpen = model.terminalSessions.count

        // Simulate normal exit (code 0) on first session -> auto-closes that tab
        model.embeddedTerminalDidTerminate(id: first.id, exitCode: 0)
        #expect(model.terminalSessions.count == 1)
        #expect(model.terminalSessions.first?.id == second.id)

        // Simulate non-zero exit on second session -> surfaces actionable message
        model.embeddedTerminalDidTerminate(id: second.id, exitCode: 127)
        if case .failed(let message) = model.terminalSessions.first?.state {
            #expect(message.contains("127"))
        } else {
            Issue.record("Expected failed state on non-zero exit")
        }

        // Toggle panel closed -> clears all sessions and terminates registry
        model.toggleTerminalPanel()
        #expect(first.directory.path == "/Users/tester")
        #expect(second.directory.path == dir.standardizedFileURL.path)
        #expect(first.title == "Terminal 1" && second.title == "Terminal 2")
        #expect(countWhileOpen == 2)
        #expect(!model.isTerminalPanelVisible && model.terminalSessions.isEmpty)
        #expect(model.embeddedTerminalRegistry.activeViewCount == 0)
    }

    @Test("N-TERM1: embedded terminal launch failure is reported on the session and never crashes or blocks the editor")
    func nLaunchFailureIsReported() throws {
        let (model, dir) = Self.makeModel()
        defer { try? FileManager.default.removeItem(at: dir) }

        model.newUntitledTab()
        model.toggleTerminalPanel()
        let session = try #require(model.terminalSessions.first)
        model.embeddedTerminalDidFail(id: session.id, message: "PTY unavailable")
        model.handleEditorTextChanged("still editing")

        #expect(model.isTerminalPanelVisible)
        #expect(model.terminalSessions.first.map {
            if case .failed(let m) = $0.state { m.contains("Terminal could not start") } else { false }
        } == true)
        #expect(model.activeDocumentSession?.text == "still editing")
    }

    @Test("P-TERM2: EmbeddedTerminalRegistry spawns a real SwiftTerm PTY view and terminates it cleanly on close")
    func pEmbeddedPTYSpawnAndCleanTerminate() throws {
        let registry = EmbeddedTerminalRegistry()
        let id = UUID()
        let dir = FileManager.default.temporaryDirectory
        let palette = PurpleThemePalette.resolve(appearance: .light, systemPrefersDark: false)
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        let view = try #require(registry.terminalView(
            for: id,
            directory: dir,
            palette: palette,
            font: font,
            onTitleChange: { _, _ in },
            onDirectoryChange: { _, _ in },
            onTerminated: { _, _ in },
            onFailedToStart: { _, _ in }
        ))
        #expect(registry.activeViewCount == 1)
        #expect(view.process != nil)

        registry.terminate(sessionID: id)
        #expect(registry.activeViewCount == 0)
        // Regression BUG-G2: a late SwiftUI updateNSView after terminate() must never resurrect the shell
        let resurrected = registry.terminalView(
            for: id,
            directory: dir,
            palette: palette,
            font: font,
            onTitleChange: { _, _ in },
            onDirectoryChange: { _, _ in },
            onTerminated: { _, _ in },
            onFailedToStart: { _, _ in }
        )
        #expect(resurrected == nil)
        #expect(registry.activeViewCount == 0)
    }
}
