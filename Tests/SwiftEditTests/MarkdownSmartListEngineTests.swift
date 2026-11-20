import Foundation
import Testing
@testable import SwiftEditCore

@Suite("MarkdownSmartListEngineTests")
struct MarkdownSmartListEngineTests {

    private static func snapshot(_ text: String) -> DocumentSnapshot {
        DocumentSession(text: text).snapshot
    }

    private static func apply(_ edits: [TextEdit], to text: String) -> String {
        let mutable = NSMutableString(string: text)
        for edit in edits.sorted(by: { $0.range.location > $1.range.location }) {
            mutable.replaceCharacters(in: NSRange(location: edit.range.location, length: edit.range.length), with: edit.replacement)
        }
        return mutable as String
    }

    private static func run(_ text: String, caretAt offset: Int? = nil, length: Int = 0, outdent: Bool = false) -> SmartListOutcome {
        let caret = offset ?? (text as NSString).length
        return MarkdownSmartListEngine.evaluateIndent(
            in: snapshot(text),
            selection: TextRange(location: caret, length: length),
            outdent: outdent,
            isMarkdownDocument: true
        )
    }

    private static func appliedText(_ outcome: SmartListOutcome, to text: String) -> String? {
        guard case .edit(let edit) = outcome else { return nil }
        return apply(edit.edits, to: text)
    }

    @Test("P1: Tab nests by four spaces, Shift+Tab outdents resuming parent numbering, and task items keep their checkbox")
    func p1TabNestsAndShiftTabOutdentsWithParentNumbering() {
        // GIVEN an ordered list ending in an empty third item and a task list ending in an empty task
        let ordered = "1. Primo punto\n2. Secondo punto\n3. "
        let tasks = "- [ ] task\n- [ ] "

        // WHEN pressing Tab on the empty third item, Shift+Tab on the result, and Tab on the empty task
        let tabbed = Self.appliedText(Self.run(ordered), to: ordered)
        let outdented = tabbed.flatMap { Self.appliedText(Self.run($0, outdent: true), to: $0) }
        let taskTabbed = Self.appliedText(Self.run(tasks), to: tasks)

        // THEN the item nests as "    1. ", Shift+Tab resumes "3. ", and the task becomes "    - [ ] "
        #expect(tabbed == "1. Primo punto\n2. Secondo punto\n    1. ")
        #expect(outdented == ordered)
        #expect(taskTabbed == "- [ ] task\n    - [ ] ")
    }

    @Test("P2: multi-line selection indents all list lines in one batch preserving each valid marker")
    func p2MultiLineSelectionIndentsPreservingMarkers() throws {
        // GIVEN a root item followed by three differently-marked items with lines 2..4 selected
        let text = "- root\n* a\n* b\n+ c"
        let length = (text as NSString).length - 7

        // WHEN pressing Tab
        let outcome = Self.run(text, caretAt: 7, length: length)

        // THEN one batch indents the three lines and the selection grows by the inserted prefix length
        guard case .edit(let edit) = outcome else {
            Issue.record("Expected an edit outcome, got \(outcome)")
            return
        }
        #expect(Self.apply(edit.edits, to: text) == "- root\n    * a\n    * b\n    + c")
        #expect(edit.edits.count == 3)
        #expect(edit.newSelection == TextRange(location: 7, length: length + 12))
    }

    @Test("P4: a valid sibling at the same deep level still allows nesting one more level")
    func p4ValidDeepListStillNests() {
        // GIVEN a three-level list whose last item has a same-level sibling
        let text = "- a\n    - b\n        - c\n        - d"

        // WHEN pressing Tab on the last item
        let result = Self.appliedText(Self.run(text), to: text)

        // THEN it gains exactly four spaces and keeps its marker
        #expect(result == "- a\n    - b\n        - c\n            - d")
    }

    @Test("N1: root first item is consumed as a no-op while prose, fenced code, and non-Markdown buffers are not applicable")
    func n1RootProseFenceAndNonMarkdownAreSafe() {
        // GIVEN a root list item, a prose line, a fenced list-like line, and a non-Markdown flag
        let root = "1. Primo punto"
        let prose = "just some prose"
        let fenced = "```\n- x\n```"
        let fencedCaret = 6

        // WHEN pressing Tab in each situation
        let rootOutcome = Self.run(root, caretAt: 0)
        let proseOutcome = Self.run(prose)
        let fencedOutcome = Self.run(fenced, caretAt: fencedCaret)
        let nonMarkdown = MarkdownSmartListEngine.evaluateIndent(
            in: Self.snapshot("- a\n- b"),
            selection: TextRange(location: 7, length: 0),
            outdent: false,
            isMarkdownDocument: false
        )

        // THEN the root item is consumed and the rest are not applicable
        #expect(rootOutcome == .consumedNoOp)
        #expect(proseOutcome == .notApplicable)
        #expect(fencedOutcome == .notApplicable)
        #expect(nonMarkdown == .notApplicable)
    }

    @Test("N2 [Security]: binary, degraded, overlong, level-32, overflowing, and out-of-range inputs never produce an edit")
    func n2BoundedSafeEvaluation() {
        // GIVEN hostile inputs
        let binary = DocumentSession(text: "- a\n- b", isBinaryReadOnly: true).snapshot
        let base = Self.snapshot("- a\n- b")
        let degraded = DocumentSnapshot(
            id: base.id, revision: base.revision, text: base.text, encoding: base.encoding,
            lineEnding: base.lineEnding, isDegradedPlainText: true, isBinaryReadOnly: false
        )
        let longLine = "- a\n- " + String(repeating: "a", count: 4100)
        let deepIndent = String(repeating: "    ", count: 32)
        let level32 = "- r\n\(deepIndent)- p\n\(deepIndent)- x"
        let overflow = "999999999. a\n    1. x"
        let tenDigits = "1. a\n1000000000. x"

        // WHEN evaluating Tab, Shift+Tab, and an out-of-range selection
        func isEdit(_ outcome: SmartListOutcome) -> Bool {
            if case .edit = outcome { return true }
            return false
        }
        let outcomes: [SmartListOutcome] = [
            MarkdownSmartListEngine.evaluateIndent(in: binary, selection: TextRange(location: 7, length: 0), outdent: false, isMarkdownDocument: true),
            MarkdownSmartListEngine.evaluateIndent(in: degraded, selection: TextRange(location: 7, length: 0), outdent: false, isMarkdownDocument: true),
            Self.run(longLine),
            Self.run(level32),
            Self.run(overflow, outdent: true),
            Self.run(tenDigits),
            MarkdownSmartListEngine.evaluateIndent(in: base, selection: TextRange(location: 99, length: 0), outdent: false, isMarkdownDocument: true),
        ]

        // THEN none of them yields an edit while a benign control input does
        #expect(outcomes.contains(where: isEdit) == false)
        #expect(isEdit(Self.run("- a\n- b")))
    }
}
