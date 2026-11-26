import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PerfPass3EditorNativeSyncTests", .serialized)
@MainActor
struct PerfPass3EditorNativeSyncTests {

    private static func makeEditor(_ text: String) -> (SwiftEditNSTextView, TextKit2EditorView.Coordinator, DocumentID) {
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.allowsUndo = true
        textView.isEditable = true
        let coordinator = TextKit2EditorView.Coordinator(onTextChange: { _ in }, onSelectionChange: { _ in }, onSmartNewline: { _ in nil }, onListIndent: { _ in .notApplicable })
        let id = DocumentID()
        textView.delegate = coordinator
        coordinator.applyProgrammaticTextUpdate(text, to: textView, documentID: id, isInitialSetup: true)
        return (textView, coordinator, id)
    }

    @Test("P11 pass 3: the editor builds its line index and checks model sync from native text at least 20% faster than via textView.string", .enabled(if: ReleasePipelineTestGate.shouldRunE2EUIAndStressTests))
    func p11NativeEditorSyncBeatsBridging() {
        // GIVEN a hosted 20k-line editor and the model's native text for the same revision
        let native = PerfBench016.markdown
        let (textView, coordinator, id) = Self.makeEditor(native)
        let length = textView.textStorage?.length ?? 0
        // WHEN index rebuild plus model-sync comparison run through textView.string versus the coordinator's native mirror
        let legacy = PerfBench016.medianMilliseconds(runs: 5) {
            coordinator.invalidateLineIndex()
            _ = coordinator.lineIndex(textProvider: { textView.string }, expectedLength: length, documentID: id, revision: BufferRevision(2))
            _ = textView.string != native
        }
        let optimized = PerfBench016.medianMilliseconds(runs: 5) {
            coordinator.invalidateLineIndex()
            _ = coordinator.renderingLineIndex(for: textView, documentID: id, revision: BufferRevision(2))
            _ = !coordinator.isDisplaying(native, in: textView)
        }
        print("PERF016 pass3 legacy=\(legacy)ms optimized=\(optimized)ms")
        // THEN the native path needs at most 80% of the legacy time
        #expect(optimized <= legacy * 0.8)
    }

    @Test("N12 pass 3: after a same-length user edit the editor index and sync check reflect the new text, never the old one")
    func n12SameLengthEditNeverStale() {
        // GIVEN an editor showing 'ab\ncd' with an index built for it
        let (textView, coordinator, id) = Self.makeEditor("ab\ncd")
        _ = coordinator.renderingLineIndex(for: textView, documentID: id, revision: BufferRevision(1))
        // WHEN the user replaces the text with a same-length buffer and TextKit notifies the delegate
        textView.textStorage?.replaceCharacters(in: NSRange(location: 0, length: 5), with: "abc\nd")
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        coordinator.retagCachedLineIndexRevision(documentID: id, revision: BufferRevision(2), storageLength: 5)
        let index = coordinator.renderingLineIndex(for: textView, documentID: id, revision: BufferRevision(2))
        // THEN the index has the new break and the sync check accepts only the new text
        #expect(index.lineStarts == [0, 4])
        #expect(coordinator.isDisplaying("abc\nd", in: textView))
        #expect(!coordinator.isDisplaying("ab\ncd", in: textView))
    }
}
