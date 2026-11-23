import AppKit
import Foundation
import SwiftUI
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("SendToTerminalContextualActionTests")
@MainActor
struct SendToTerminalContextualActionTests {

    private static func makeModel(dir: URL) -> SwiftEditWorkbenchModel {
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("recovery"),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.embeddedTerminalRegistry.shellReadinessDelayMilliseconds = 0
        return model
    }

    @Test("P-STT1: TerminalSelectionPayload strips trailing line breaks, sanitizes ESC/control injection, and frames multiline bracketed paste")
    func pPayloadSanitizationAndBracketedPaste() throws {
        // Single-line with trailing CRLF: must strip trailing newline so Return is never sent automatically.
        let singleSource = "echo hello world\r\n"
        let single = try #require(TerminalSelectionPayload.prepare(
            selection: TextRange(location: 0, length: (singleSource as NSString).length),
            in: singleSource
        ))
        #expect(single.text == "echo hello world")
        #expect(single.lineCount == 1)
        #expect(single.isMultiline == false)
        #expect(single.wireText(bracketedPaste: true) == "echo hello world")

        // Multiline with embedded ESC bracketed-paste breakout attempt (\u{1B}[201~rm -rf):
        // ESC must be stripped (CWE-150), CRLF normalized to LF, trailing LF stripped, and lineCount == 3.
        let multiSource = "ls -la\r\npwd\n\u{1B}[201~echo safe\n\n"
        let multi = try #require(TerminalSelectionPayload.prepare(
            selection: TextRange(location: 0, length: (multiSource as NSString).length),
            in: multiSource
        ))
        #expect(multi.isMultiline == true)
        #expect(multi.lineCount == 3)
        #expect(!multi.text.contains("\u{1B}"))
        #expect(!multi.text.hasSuffix("\n"))
        #expect(multi.wireText(bracketedPaste: true) == "\u{1B}[200~\(multi.text)\u{1B}[201~")
        #expect(multi.wireText(bracketedPaste: false) == multi.text)
    }

    @Test("N-STT1 [Security]: TerminalSelectionPayload rejects empty, whitespace-newline-only, binary, surrogate-split, and >64 KiB selections")
    func nPayloadGuards() {
        #expect(TerminalSelectionPayload.prepare(selection: TextRange(location: 0, length: 0), in: "ls") == nil)
        #expect(TerminalSelectionPayload.prepare(selection: TextRange(location: 0, length: 3), in: "\r\n\n") == nil)
        #expect(TerminalSelectionPayload.prepare(selection: TextRange(location: 0, length: 2), in: "ls", isBinaryReadOnly: true) == nil)
        #expect(TerminalSelectionPayload.prepare(selection: TextRange(location: 5, length: 2), in: "ls") == nil)
        // Surrogate-pair split ("😀" is 2 UTF-16 code units)
        #expect(TerminalSelectionPayload.prepare(selection: TextRange(location: 0, length: 1), in: "😀") == nil)
        // Overlong selection (> 64 KiB)
        let huge = String(repeating: "a", count: TerminalSelectionPayload.maxUTF16Length + 1)
        #expect(TerminalSelectionPayload.prepare(selection: TextRange(location: 0, length: huge.utf16.count), in: huge) == nil)
    }

    @Test("P-STT2: Single-line Send to Terminal from Cmd+Return opens closed terminal, queues and flushes to live SwiftTerm PTY without Return")
    func pSingleLineOpensTerminalAndDeliversToLivePTY() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("stt-p2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let model = Self.makeModel(dir: dir)
        defer { model.embeddedTerminalRegistry.terminateAll() }

        var delivered: [(UUID, String)] = []
        model.embeddedTerminalRegistry.onDeliveredWireText = { id, wire in
            delivered.append((id, wire))
        }

        model.newUntitledTab()
        model.handleEditorTextChanged("git status\n")
        model.selectRange(TextRange(location: 0, length: 11)) // includes trailing \n

        #expect(model.isTerminalPanelVisible == false)
        #expect(model.terminalSessions.isEmpty)

        // Open Cmd+Return contextual palette and trigger "Send to Terminal"
        #expect(model.presentElementContextualMenu())
        let action = try #require(ElementContextualActionCatalog.terminalGroup.actions.first)
        #expect(model.performElementContextualAction(action))

        // Terminal panel opened, session created, payload queued awaiting SwiftTerm view mount
        #expect(model.isTerminalPanelVisible == true)
        #expect(model.pendingMultilineTerminalSend == nil)
        let session = try #require(model.terminalSessions.first)
        #expect(model.embeddedTerminalRegistry.pendingPayloadCount(for: session.id) == 1)

        // Mount real SwiftTerm PTY view (simulating SwiftUI TerminalPanelView rendering)
        let termView = model.embeddedTerminalRegistry.terminalView(
            for: session.id,
            directory: dir,
            palette: model.palette,
            font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            onTitleChange: { _, _ in },
            onDirectoryChange: { _, _ in },
            onTerminated: { _, _ in },
            onFailedToStart: { _, _ in }
        )
        #expect(termView != nil)
        #expect(model.embeddedTerminalRegistry.pendingPayloadCount(for: session.id) == 0)
        #expect(delivered.count == 1)
        #expect(delivered.first?.0 == session.id)
        #expect(delivered.first?.1 == "git status") // NO trailing \n or \r!

        // Second send while terminal is already open & ready delivers immediately without queueing
        model.handleEditorTextChanged("ls -la")
        model.selectRange(TextRange(location: 0, length: 6))
        #expect(model.requestSendSelectionToTerminal())
        #expect(delivered.count == 2)
        #expect(delivered.last?.1 == "ls -la")
    }

    @Test("P-STT3: Multiline Send to Terminal triggers warning confirmation; Cancel aborts cleanly and Confirm delivers to terminal")
    func pMultilineShowsWarningConfirmAndCancel() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("stt-p3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let model = Self.makeModel(dir: dir)
        defer { model.embeddedTerminalRegistry.terminateAll() }

        var delivered: [String] = []
        model.embeddedTerminalRegistry.onDeliveredWireText = { _, wire in
            delivered.append(wire)
        }

        model.newUntitledTab()
        let script = "echo one\necho two\necho three\n"
        model.handleEditorTextChanged(script)
        model.selectRange(TextRange(location: 0, length: (script as NSString).length))

        // Trigger Send to Terminal on multiline selection -> must stage warning, NOT open terminal yet
        #expect(model.requestSendSelectionToTerminal())
        #expect(model.pendingMultilineTerminalSend?.isMultiline == true)
        #expect(model.pendingMultilineTerminalSend?.lineCount == 3)
        #expect(model.isTerminalPanelVisible == false)
        #expect(delivered.isEmpty)

        // Cancel clears pending state and never opens terminal
        model.cancelPendingMultilineTerminalSend()
        #expect(model.pendingMultilineTerminalSend == nil)
        #expect(model.isTerminalPanelVisible == false)
        #expect(delivered.isEmpty)

        // Re-trigger and confirm -> opens terminal, creates session, and delivers sanitized 3-line payload
        #expect(model.requestSendSelectionToTerminal())
        model.confirmPendingMultilineTerminalSend()
        #expect(model.pendingMultilineTerminalSend == nil)
        #expect(model.isTerminalPanelVisible == true)
        let session = try #require(model.terminalSessions.first)
        _ = model.embeddedTerminalRegistry.terminalView(
            for: session.id,
            directory: dir,
            palette: model.palette,
            font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            onTitleChange: { _, _ in },
            onDirectoryChange: { _, _ in },
            onTerminated: { _, _ in },
            onFailedToStart: { _, _ in }
        )
        #expect(delivered.count == 1)
        #expect(delivered.first?.contains("echo one\necho two\necho three") == true)
        #expect(delivered.first?.hasSuffix("\n") == false)
    }

    @Test("P-STT4: Right-click context menu on SwiftEditNSTextView exposes Send to Terminal only when text is selected")
    func pRightClickMenuExposesSendToTerminalOnSelection() throws {
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.string = "swift test --parallel"
        var captured: (NSRange, String)?
        textView.onSendSelectionToTerminal = { range, text in
            captured = (range, text)
        }
        let dummyEvent = try #require(NSEvent.mouseEvent(
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

        // No selection -> menu must NOT include "Send to Terminal"
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        let menuNoSel = textView.menu(for: dummyEvent)
        #expect(menuNoSel?.items.contains(where: { $0.title == "Send to Terminal" }) == false)

        // With selection -> menu includes "Send to Terminal" at index 0 and invoking it calls handler
        textView.setSelectedRange(NSRange(location: 0, length: 10))
        let menuWithSel = try #require(textView.menu(for: dummyEvent))
        let sendItem = try #require(menuWithSel.items.first(where: { $0.title == "Send to Terminal" }))
        #expect(sendItem.target === textView)
        if let action = sendItem.action {
            _ = textView.perform(action, with: sendItem)
        }
        #expect(captured?.0 == NSRange(location: 0, length: 10))
        #expect(captured?.1 == "swift test --parallel")
    }
}
