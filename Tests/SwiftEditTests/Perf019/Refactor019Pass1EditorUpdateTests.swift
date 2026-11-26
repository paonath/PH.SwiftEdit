import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("Refactor019Pass1EditorUpdateTests", .serialized)
@MainActor
struct Refactor019Pass1EditorUpdateTests {

    private static func makeHostedEditor(editable: Bool) -> (NSWindow, SwiftEditNSTextView, TextKit2EditorView.Coordinator) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.frame = scroll.bounds
        textView.allowsUndo = true
        textView.isEditable = editable
        scroll.documentView = textView
        window.contentView = scroll
        let coordinator = TextKit2EditorView.Coordinator(onTextChange: { _ in }, onSelectionChange: { _ in }, onSmartNewline: { _ in nil }, onListIndent: { _ in .notApplicable })
        textView.delegate = coordinator
        return (window, textView, coordinator)
    }

    private static let tail = (0..<10_000).map { "2026-11-22 10:00:00.0000|INFO|App.Logger|message number \($0)" }.joined(separator: "\n")

    @Test("N-R1 [bug]: live updates of a read-only tail view never register undo actions")
    func nReadOnlyUpdatesRegisterNoUndo() {
        // GIVEN a hosted read-only editor showing a tail
        let (window, textView, coordinator) = Self.makeHostedEditor(editable: false)
        defer { window.close() }
        let id = DocumentID()
        coordinator.applyProgrammaticTextUpdate(Self.tail, to: textView, documentID: id, isInitialSetup: true)
        // WHEN five live updates arrive
        for i in 0..<5 {
            coordinator.applyProgrammaticTextUpdate(Self.tail + "\nnew \(i)", to: textView, documentID: id)
            RunLoop.current.run(until: Date().addingTimeInterval(0.01)) // close the event-based undo group
        }
        // THEN neither the window nor the text view can undo anything and the text is current
        #expect(window.undoManager?.canUndo != true)
        #expect(textView.undoManager?.canUndo != true)
        #expect(textView.string.hasSuffix("new 4"))
    }

    @Test("P-R1 [perf]: an appended line replaces only the changed range and is at least 20% faster than a full replacement", .enabled(if: ReleasePipelineTestGate.shouldRunE2EUIAndStressTests))
    func pMinimalRangeUpdateIsFaster() {
        // GIVEN a hosted 10k-line tail scrolled to the end
        let (window, textView, coordinator) = Self.makeHostedEditor(editable: false)
        defer { window.close() }
        let id = DocumentID()
        coordinator.applyProgrammaticTextUpdate(Self.tail, to: textView, documentID: id, isInitialSetup: true)
        textView.scrollToEndOfDocument(nil)
        let grown = Self.tail + "\n2026-11-22 10:00:01|ERROR|App|boom"
        // WHEN a full replacement (legacy) and the workbench update path each apply the appended line and lay out the viewport
        let legacy = PerfBench016.medianMilliseconds(runs: 7) {
            for text in [grown, Self.tail] {
                let full = NSRange(location: 0, length: textView.textStorage!.length)
                textView.textStorage!.replaceCharacters(in: full, with: text)
                textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
            }
        }
        let optimized = PerfBench016.medianMilliseconds(runs: 7) {
            for text in [grown, Self.tail] {
                coordinator.applyProgrammaticTextUpdate(text, to: textView, documentID: id)
                textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
            }
        }
        print("REFACTOR019 pass1 legacy=\(legacy)ms optimized=\(optimized)ms")
        // THEN the minimal update is at least 20% faster
        #expect(optimized <= legacy * 0.8)
    }

    @Test("P-R1b: minimal-range updates produce exactly the new text for prefix, suffix, middle, unicode and empty edits", arguments: [
        ("abc\ndef", "abc\ndef\nghi"), ("abc\ndef", "zzz\nabc\ndef"), ("abc\ndef\nghi", "abc\nXY\nghi"), ("é😀 a", "é😀 b"), ("abc", ""), ("", "new"), ("same", "same"),
    ])
    func pMinimalRangeEquivalence(old: String, new: String) {
        // GIVEN an editable editor with an undo manager showing `old`
        let (window, textView, coordinator) = Self.makeHostedEditor(editable: true)
        defer { window.close() }
        let id = DocumentID()
        coordinator.applyProgrammaticTextUpdate(old, to: textView, documentID: id, isInitialSetup: true)
        // WHEN `new` is applied programmatically and then undone once
        coordinator.applyProgrammaticTextUpdate(new, to: textView, documentID: id)
        let applied = textView.string
        textView.undoManager?.undo()
        // THEN the text equals `new` and a single undo restores `old`
        #expect(applied == new)
        #expect(textView.string == old)
    }
}
