import Foundation
import Testing
@testable import SwiftEditCore

@Suite("DocumentSessionAndCommandDTests")
struct DocumentSessionAndCommandDTests {

    @Test("P3: applyEdit replaces UTF-16 range, marks session dirty, increments BufferRevision, and emits textEdited event")
    func p3ApplyEditMutatesBufferAndIncrementsRevision() throws {
        // GIVEN a clean DocumentSession at revision 1
        var session = DocumentSession(text: "Hello world", lineEnding: .lf)
        let targetRange = TextRange(location: 6, length: 5)

        // WHEN applying a text replacement
        let event = try session.applyEdit(replacing: targetRange, with: "Swift 6")

        // THEN buffer text, dirty state, revision, snapshot, and event reflect the edit
        #expect(session.text == "Hello Swift 6")
        #expect(session.isDirty == true)
        #expect(session.revision == BufferRevision(2))
        #expect(session.snapshot.revision == BufferRevision(2))
        #expect(event == .textEdited(session.id, BufferRevision(2), TextRange(location: 6, length: 7)))
    }

    @Test("P3: Cmd+D with collapsed caret duplicates current line preserving CRLF and advances caret onto duplicated line")
    func p3CommandDDuplicatesUnselectedCurrentLine() throws {
        // GIVEN a CRLF DocumentSession with caret at column 2 on the first line ("alpha")
        var session = DocumentSession(text: "alpha\r\nbeta", lineEnding: .crlf)
        let caret = TextRange(location: 2, length: 0)

        // WHEN invoking duplicateLineOrSelection (Cmd+D)
        let event = try session.duplicateLineOrSelection(selection: caret)

        // THEN "alpha" is duplicated on the next CRLF line and caret moves to column 2 of the new line
        #expect(session.text == "alpha\r\nalpha\r\nbeta")
        #expect(session.isDirty == true)
        #expect(session.revision == BufferRevision(2))
        #expect(event == .commandDDuplicated(session.id, BufferRevision(2), TextRange(location: 9, length: 0)))
    }

    @Test("P3: Cmd+D with active selection inserts selected text on a new line immediately after the cursor line")
    func p3CommandDInsertsSelectedTextOnNewLineAfterCursor() throws {
        // GIVEN a CRLF DocumentSession with "alp" selected on the first line
        var session = DocumentSession(text: "alpha\r\nbeta", lineEnding: .crlf)
        let selection = TextRange(location: 0, length: 3)

        // WHEN invoking duplicateLineOrSelection (Cmd+D)
        let event = try session.duplicateLineOrSelection(selection: selection)

        // THEN "alp" is inserted on a new CRLF-separated line immediately after "alpha"
        #expect(session.text == "alpha\r\nalp\r\nbeta")
        #expect(session.isDirty == true)
        #expect(session.revision == BufferRevision(2))
        #expect(event == .commandDDuplicated(session.id, BufferRevision(2), TextRange(location: 7, length: 3)))
    }

    @Test(
        "N5: Out-of-bounds TextRange throws DomainError.invalidTextRange without mutating text or BufferRevision",
        arguments: [
            SwiftEditCore.TextRange(location: -1, length: 2),
            SwiftEditCore.TextRange(location: 2, length: -1),
            SwiftEditCore.TextRange(location: 8, length: 5),
        ]
    )
    func n5OutOfBoundsRangeThrowsInvalidTextRangeWithoutMutation(invalidRange: SwiftEditCore.TextRange) {
        // GIVEN a 10-character DocumentSession at BufferRevision(1)
        var session = DocumentSession(text: "0123456789", lineEnding: .lf)

        // WHEN / THEN applyEdit and duplicateLineOrSelection both reject invalidRange and leave state untouched
        #expect(throws: DomainError.invalidTextRange(invalidRange)) {
            _ = try session.applyEdit(replacing: invalidRange, with: "X")
        }
        #expect(throws: DomainError.invalidTextRange(invalidRange)) {
            _ = try session.duplicateLineOrSelection(selection: invalidRange)
        }
        #expect(session.text == "0123456789")
        #expect(session.revision == BufferRevision(1))
        #expect(session.isDirty == false)
    }

    @Test("N6 [Security]: applyEdit and duplicateLineOrSelection on binary read-only session throw binaryFileSaveForbidden without state mutation")
    func n6SecurityBinaryReadOnlySessionRejectsApplyEditAndCommandD() {
        // GIVEN a binary read-only DocumentSession at BufferRevision(1)
        var binarySession = DocumentSession(
            text: ".PNG....",
            lineEnding: .lf,
            isDegradedPlainText: true,
            isBinaryReadOnly: true
        )

        // WHEN / THEN both applyEdit and duplicateLineOrSelection fail closed with binaryFileSaveForbidden
        #expect(throws: DomainError.binaryFileSaveForbidden) {
            _ = try binarySession.applyEdit(replacing: SwiftEditCore.TextRange(location: 0, length: 4), with: "TEXT")
        }
        #expect(throws: DomainError.binaryFileSaveForbidden) {
            _ = try binarySession.duplicateLineOrSelection(selection: SwiftEditCore.TextRange(location: 0, length: 0))
        }
        #expect(binarySession.text == ".PNG....")
        #expect(binarySession.revision == BufferRevision(1))
        #expect(binarySession.isDirty == false)
    }
}
