import Foundation
import Testing
@testable import SwiftEditCore

/// Test helpers keeping conditional result handling out of `@Test` bodies (`TEST-002`).
private extension FrontmatterWriteResult {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }

    /// Applies the edit (if any) through the single `DocumentSession` mutation path; rejections leave `session` untouched.
    func commit(to session: inout DocumentSession) throws {
        if case .edit(let edit) = self { _ = try session.applyTextEdits([edit], expectedRevision: session.revision) }
    }
}

/// Parses `session`, runs `operation` through the writer and commits the resulting edit.
private func applyFrontmatterOperation(_ operation: FrontmatterPropertyOperation, to session: inout DocumentSession) throws -> FrontmatterWriteResult {
    let model = try #require(FrontmatterPropertyParser.parse(snapshot: session.snapshot))
    let result = FrontmatterPropertyWriter.apply(operation, model: model, snapshot: session.snapshot)
    try result.commit(to: &session)
    return result
}

@Suite("FrontmatterPropertyWriterTests")
struct FrontmatterPropertyWriterTests {

    private static func apply(_ operation: FrontmatterPropertyOperation, to session: inout DocumentSession) throws -> FrontmatterWriteResult {
        try applyFrontmatterOperation(operation, to: &session)
    }

    @Test("P8: edit, rename, add and remove produce single minimal edits and re-parse to the edited model")
    func p8EditRenameAddRemove() throws {
        // GIVEN a frontmatter with a comment, a scalar and a flow list followed by a body
        var session = DocumentSession(text: "---\n# note\ntitle: Hello\ntags: [a, b]\n---\n# Body\nText\n")
        // WHEN the four operations are applied in successive revisions
        let r1 = try Self.apply(.setValue(key: "title", value: .scalar("Hi: there")), to: &session)
        let afterEdit = session.text
        let r2 = try Self.apply(.rename(from: "tags", to: "labels"), to: &session)
        let afterRename = session.text
        let r3 = try Self.apply(.add(key: "draft", value: .scalar("true")), to: &session)
        let afterAdd = session.text
        let r4 = try Self.apply(.remove(key: "labels"), to: &session)
        let final = try #require(FrontmatterPropertyParser.parse(snapshot: session.snapshot))
        // THEN each step is one edit, untouched lines are byte-identical and the model round-trips
        #expect([r1, r2, r3, r4].allSatisfy { $0.isEdit })
        #expect(afterEdit == "---\n# note\ntitle: \"Hi: there\"\ntags: [a, b]\n---\n# Body\nText\n")
        #expect(afterRename == "---\n# note\ntitle: \"Hi: there\"\nlabels: [a, b]\n---\n# Body\nText\n")
        #expect(afterAdd == "---\n# note\ntitle: \"Hi: there\"\nlabels: [a, b]\ndraft: true\n---\n# Body\nText\n")
        #expect(session.text == "---\n# note\ntitle: \"Hi: there\"\ndraft: true\n---\n# Body\nText\n")
        #expect(final.properties.map(\.kind) == [.scalar("Hi: there"), .scalar("true")])
        #expect(session.revision == BufferRevision(5))
    }

    @Test("P8b: block lists keep block style and inline comments are preserved")
    func p8bBlockListsAndComments() throws {
        // GIVEN a block list and a scalar with an inline comment
        var session = DocumentSession(text: "---\naliases:\n  - x\n  - y\nn: 3 # count\n---\n")
        // WHEN the list and the scalar are edited
        _ = try Self.apply(.setValue(key: "aliases", value: .list(["x", "z, w"])), to: &session)
        _ = try Self.apply(.setValue(key: "n", value: .scalar("4")), to: &session)
        // THEN block style and the comment survive (a comma is plain-safe outside flow collections)
        #expect(session.text == "---\naliases:\n  - x\n  - z, w\nn: 4 # count\n---\n")
    }

    @Test("N8: injection, invalid keys, duplicates and stale revisions are rejected or neutralized")
    func n8InjectionDuplicateAndStale() throws {
        // GIVEN a frontmatter at revision 7
        var session = DocumentSession(revision: BufferRevision(7), text: "---\ntitle: a\ntags: [x]\n---\nbody\n")
        let model = try #require(FrontmatterPropertyParser.parse(snapshot: session.snapshot))
        let staleModel = try #require(FrontmatterPropertyParser.parse(snapshot: DocumentSession(id: session.id, revision: BufferRevision(6), text: session.text).snapshot))
        // WHEN hostile operations are submitted
        let injected = FrontmatterPropertyWriter.apply(.setValue(key: "title", value: .scalar("x\n---\nmalicious: true")), model: model, snapshot: session.snapshot)
        let colonKey = FrontmatterPropertyWriter.apply(.add(key: "a: b", value: .scalar("1")), model: model, snapshot: session.snapshot)
        let bellKey = FrontmatterPropertyWriter.apply(.add(key: "k\u{7}", value: .scalar("1")), model: model, snapshot: session.snapshot)
        let dashKey = FrontmatterPropertyWriter.apply(.add(key: "- k", value: .scalar("1")), model: model, snapshot: session.snapshot)
        let duplicate = FrontmatterPropertyWriter.apply(.rename(from: "tags", to: "title"), model: model, snapshot: session.snapshot)
        let stale = FrontmatterPropertyWriter.apply(.setValue(key: "title", value: .scalar("b")), model: staleModel, snapshot: session.snapshot)
        try injected.commit(to: &session)
        let reparsed = try #require(FrontmatterPropertyParser.parse(snapshot: session.snapshot))
        // THEN the value stays one escaped scalar, invalid keys and duplicates are rejected, and the stale write is refused
        #expect(session.text == "---\ntitle: \"x\\n---\\nmalicious: true\"\ntags: [x]\n---\nbody\n")
        #expect(session.text.components(separatedBy: "\n").filter { $0 == "---" }.count == 2)
        #expect(reparsed.properties.map(\.key) == ["title", "tags"])
        #expect(reparsed.properties.first?.kind == .scalar("x\n---\nmalicious: true"))
        #expect(colonKey == .rejected(.invalidKey))
        #expect(bellKey == .rejected(.invalidKey))
        #expect(dashKey == .rejected(.invalidKey))
        #expect(duplicate == .rejected(.duplicateKey))
        #expect(stale == .staleRevision)
    }

    @Test("N8b: read-only entries and read-only models are never rewritten")
    func n8bReadOnlyNeverRewritten() throws {
        // GIVEN a nested map entry and a malformed (duplicate-key) model
        let nested = DocumentSession(text: "---\nmeta:\n  a: 1\n---\n").snapshot
        let malformed = DocumentSession(text: "---\na: 1\na: 2\n---\n").snapshot
        // WHEN writes target them
        let nestedResult = FrontmatterPropertyWriter.apply(.setValue(key: "meta", value: .scalar("x")), model: try #require(FrontmatterPropertyParser.parse(snapshot: nested)), snapshot: nested)
        let malformedResult = FrontmatterPropertyWriter.apply(.add(key: "b", value: .scalar("1")), model: try #require(FrontmatterPropertyParser.parse(snapshot: malformed)), snapshot: malformed)
        // THEN both are rejected as read-only
        #expect(nestedResult == .rejected(.readOnly))
        #expect(malformedResult == .rejected(.readOnly))
    }
}

@Suite("FrontmatterPropertyRoundTripTests")
struct FrontmatterPropertyRoundTripTests {
    @Test("P8c: hostile and ordinary scalar values round-trip exactly through writer and parser", arguments: [
        "plain", "Hi: there", "a # b", "  edge  ", "\"quoted\"", "back\\slash", "line\nbreak", "tab\there", "bell\u{7}", "-dash", "", "true",
    ])
    func p8cScalarRoundTrip(value: String) throws {
        // GIVEN a frontmatter with one scalar
        var session = DocumentSession(text: "---\nk: v\n---\n")
        // WHEN the value is written and re-parsed
        let result = try applyFrontmatterOperation(.setValue(key: "k", value: .scalar(value)), to: &session)
        let reparsed = try #require(FrontmatterPropertyParser.parse(snapshot: session.snapshot))
        // THEN one edit was produced, the parsed value equals the written value and the block keeps exactly two delimiters
        #expect(result.isEdit)
        #expect(reparsed.properties.map(\.kind) == [.scalar(value)])
        #expect(session.text.components(separatedBy: "\n").filter { $0 == "---" }.count == 2)
    }
}
