import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PerTabUndoAndLifecycleTests")
struct PerTabUndoAndLifecycleTests {

    @Test("P1: PerTabUndoManagerRegistry isolates undo stacks per DocumentID and undo-safe updates preserve selection and undoability")
    @MainActor
    func p1PerTabUndoIsolationAndSelectionPreservation() throws {
        // GIVEN two tabs docA and docB sharing a hosted SwiftEditNSTextView inside an NSWindow
        let docA = DocumentID()
        let docB = DocumentID()
        let registry = PerTabUndoManagerRegistry()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 320))
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.allowsUndo = true
        textView.isEditable = true
        scrollView.documentView = textView
        window.contentView = scrollView

        let coordinator = TextKit2EditorView.Coordinator(
            onTextChange: { _ in },
            onSelectionChange: { _ in },
            onSmartNewline: { _ in nil },
            onListIndent: { _ in .notApplicable }
        )
        coordinator.undoRegistry = registry
        coordinator.activeDocumentID = docA
        textView.delegate = coordinator
        textView.string = "alpha\nbeta"
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        // WHEN applying a programmatic edit on docA while "alpha" (length 5) is selected, then checking docB
        coordinator.applyProgrammaticTextUpdate("alpha\nalpha\nbeta", to: textView, documentID: docA)
        let selectionAfterEdit = textView.selectedRange()
        let undoA = try #require(coordinator.undoManager(for: textView))
        let undoB = registry.undoManager(for: docB)
        let canUndoA = undoA.canUndo
        undoA.undo()
        let textAfterUndo = textView.string

        // THEN undo managers are distinct from each other and NSWindow, selection length is preserved, and Cmd+Z restores docA
        #expect(undoA === registry.undoManager(for: docA))
        #expect(undoA !== undoB)
        #expect(undoA !== window.undoManager)
        #expect(selectionAfterEdit == NSRange(location: 0, length: 5))
        #expect(canUndoA == true)
        #expect(textAfterUndo == "alpha\nbeta")
    }

    @Test("N1: dismantleNSView clears delegate, onEscape, and renderingAttributesValidator cleanly")
    @MainActor
    func n1DismantleNSViewDetachesLifecycleHooks() {
        // GIVEN a hosted TextKit2EditorView scroll view with active delegate, escape hook, and GFM validator
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        scrollView.documentView = textView
        let coordinator = TextKit2EditorView.Coordinator(
            onTextChange: { _ in },
            onSelectionChange: { _ in },
            onSmartNewline: { _ in nil },
            onListIndent: { _ in .notApplicable }
        )
        textView.delegate = coordinator
        textView.onEscape = { true }
        textView.textLayoutManager?.renderingAttributesValidator = { _, _ in }

        // WHEN SwiftUI tears down the representable view
        TextKit2EditorView.dismantleNSView(scrollView, coordinator: coordinator)

        // THEN all callbacks, delegates, and validators are detached before deallocation
        #expect(textView.delegate == nil)
        #expect(textView.onEscape == nil)
        #expect(textView.textLayoutManager?.renderingAttributesValidator == nil)
    }

    @Test("N2 [Security]: closing tab B and editing FindBar never shares or retains stale undo targets against tab A")
    @MainActor
    func n2CrossTabCloseAndFindBarUndoIsolation() throws {
        // GIVEN docA and docB registered in PerTabUndoManagerRegistry and a separate FindBar field editor on NSWindow
        let docA = DocumentID()
        let docB = DocumentID()
        let registry = PerTabUndoManagerRegistry()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }

        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.allowsUndo = true
        textView.isEditable = true
        window.contentView = textView

        let coordinator = TextKit2EditorView.Coordinator(
            onTextChange: { _ in },
            onSelectionChange: { _ in },
            onSmartNewline: { _ in nil },
            onListIndent: { _ in .notApplicable }
        )
        coordinator.undoRegistry = registry
        coordinator.activeDocumentID = docA
        textView.delegate = coordinator
        textView.string = "one"
        coordinator.applyProgrammaticTextUpdate("one\none", to: textView, documentID: docA)

        // Switch to docB, record edit, then simulate tab B closure and FindBar editing on NSWindow.undoManager
        coordinator.applyProgrammaticTextUpdate("two", to: textView, documentID: docB)
        coordinator.applyProgrammaticTextUpdate("two-edited", to: textView, documentID: docB)
        let undoB = registry.undoManager(for: docB)
        registry.removeUndoManager(for: docB)
        window.undoManager?.registerUndo(withTarget: window) { _ in }

        // Switch back to docA and undo cleanly
        coordinator.applyProgrammaticTextUpdate("one\none", to: textView, documentID: docA)
        let activeUndoA = try #require(coordinator.undoManager(for: textView))
        activeUndoA.undo()

        // THEN evicted undoB is cleared, window undo never polluted docA, and docA undoes safely without UAF
        #expect(undoB.canUndo == false)
        #expect(registry.containsUndoManager(for: docB) == false)
        #expect(activeUndoA !== window.undoManager)
        #expect(textView.string == "one")
    }
}
