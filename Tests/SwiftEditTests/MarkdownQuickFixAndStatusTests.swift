import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("MarkdownQuickFixAndStatusTests")
struct MarkdownQuickFixAndStatusTests {

    private static func snapshot(_ text: String) -> DocumentSnapshot { DocumentSession(text: text).snapshot }

    private static func apply(_ edit: MarkdownAuthoringEdit, to text: String) -> String {
        let m = NSMutableString(string: text)
        for e in edit.edits.sorted(by: { $0.range.location > $1.range.location }) {
            m.replaceCharacters(in: NSRange(location: e.range.location, length: e.range.length), with: e.replacement)
        }
        return m as String
    }

    @Test("P2: Fix All is idempotent, one batch, and creates no duplicate blank lines")
    func p2FixAllIdempotent() {
        let text = "#Title\ntext\n- a\n- b\ntext"
        let snap = Self.snapshot(text)
        guard case .edit(let edit) = MarkdownQuickFixResolver.fixAll(snapshot: snap, expectedRevision: snap.revision) else {
            Issue.record("expected an edit"); return
        }
        let fixed = Self.apply(edit, to: text)
        #expect(fixed == "# Title\n\ntext\n\n- a\n- b\n\ntext")
        #expect(!fixed.contains("\n\n\n"))
        let second = Self.snapshot(fixed)
        #expect(MarkdownQuickFixResolver.fixAll(snapshot: second, expectedRevision: second.revision) == .noFix)
    }

    @Test("N3: a stale expected revision is rejected")
    func n3StaleRevision() {
        let snap = Self.snapshot("#Title")
        let stale = BufferRevision(snap.revision.value + 1)
        #expect(MarkdownQuickFixResolver.fixAll(snapshot: snap, expectedRevision: stale) == .stale)
    }

    @Test("N4 [Security]: security diagnostics offer no quick-fix and Fix All leaves them untouched")
    func n4SecurityOffersNoFix() {
        let text = "[x](javascript:alert(1))\n![x](../a.png)\n[e]()"
        let snap = Self.snapshot(text)
        let result = MarkdownLintAndFormatEngine.lint(snapshot: snap, profile: .allConstructs).completedValue!
        #expect(!result.diagnostics.isEmpty)
        #expect(result.diagnostics.filter { $0.rule.isSecurityRule }.allSatisfy { $0.quickFix == nil })
        #expect(MarkdownQuickFixResolver.fixAll(snapshot: snap, expectedRevision: snap.revision) == .noFix)
    }

    @Test("P3: lint status is Off, Paused or Active with the diagnostic count")
    func p3Status() {
        let md = Self.snapshot("# a")
        let degraded = DocumentSnapshot(id: DocumentID(), revision: BufferRevision(0), text: "# a", encoding: .utf8, lineEnding: .lf, isDegradedPlainText: true, isBinaryReadOnly: false)
        #expect(ActiveLintStatus.classify(isMarkdownDocument: false, snapshot: md, diagnosticCount: 5) == .off)
        #expect(ActiveLintStatus.classify(isMarkdownDocument: true, snapshot: degraded, diagnosticCount: 0) == .paused)
        let active = ActiveLintStatus.classify(isMarkdownDocument: true, snapshot: md, diagnosticCount: 3)
        #expect(active == .active(count: 3))
        #expect(active.label == "Lint: 3")
        #expect(ActiveLintStatus.off.label == "Lint: Off")
        #expect(ActiveLintStatus.paused.label == "Lint: Paused")
        #expect(ActiveLintStatus.active(count: 0).label == "Lint: 0")
        // V-01: the label never embeds a warning/check glyph (the status bar draws a single icon).
        #expect(!active.label.contains("⚠") && !ActiveLintStatus.active(count: 0).label.contains("✓"))
    }

    @Test("N5 [Security]: active-line suppression hides transient warnings but never security errors")
    func n5SuppressionKeepsSecurityErrors() {
        let warning = MarkdownLintDiagnostic(rule: .trailingSpaces, line: 2, message: "w")
        let error = MarkdownLintDiagnostic(rule: .unsafeLinkScheme, line: 2, message: "e")
        let other = MarkdownLintDiagnostic(rule: .trailingSpaces, line: 5, message: "w")
        let visible = ActiveLineLintSuppressionPolicy.visibleDiagnostics([warning, error, other], caretLine: 2)
        #expect(visible == [error, other])
    }
}

@Suite("DiagnosticsUIWiringTests")
struct DiagnosticsUIWiringTests {

    private static var tmp: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".tmp/test-results/diagwiring-\(UUID().uuidString)", isDirectory: true)
    }

    @MainActor
    private static func makeModel(recovery: URL) -> SwiftEditWorkbenchModel {
        SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recovery,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
    }

    @Test("P4: Shift+Cmd+M popover toggles, Jump-to-Range selects the diagnostic, and Fix All adds exactly one revision")
    @MainActor
    func p4PopoverJumpAndFixAll() throws {
        let dir = Self.tmp
        let model = Self.makeModel(recovery: dir)
        defer {
            try? FileManager.default.removeItem(at: dir)
        }
        model.handleEditorTextChanged("#Heading\n\n![](a.png)\n")
        let rules = model.lintDiagnostics.map(\.rule)
        #expect(rules.contains(.missingHeadingSpace))
        #expect(rules.contains(.missingImageAltText))
        #expect(model.activeLintStatus == .active(count: model.lintDiagnostics.count))

        #expect(model.isDiagnosticsPopoverPresented == false)
        model.toggleDiagnosticsPopover()
        #expect(model.isDiagnosticsPopoverPresented == true)

        let target = try #require(model.lintDiagnostics.first { $0.rule == .missingImageAltText })
        model.jumpToDiagnostic(target)
        #expect(model.currentSelection.location == target.range?.location)

        let before = try #require(model.activeDocumentSession?.revision)
        #expect(model.applyFixAll())
        let after = try #require(model.activeDocumentSession?.revision)
        #expect(after.value == before.value + 1)
        #expect(model.activeDocumentSession?.text.hasPrefix("# Heading") == true)
        #expect(!model.lintDiagnostics.contains { $0.rule == .missingHeadingSpace })
    }

    @Test("N6 [Security]: binary and non-Markdown tabs show Lint: Off and ignore popover and fixes")
    @MainActor
    func n6BinaryAndNonMarkdownInert() throws {
        let dir = Self.tmp
        let model = Self.makeModel(recovery: dir)
        defer {
            try? FileManager.default.removeItem(at: dir)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let swiftURL = dir.appendingPathComponent("Main.swift")
        try Data("#Heading\n".utf8).write(to: swiftURL)
        model.openFile(at: swiftURL, withinScope: dir)
        #expect(model.activeLintStatus == .off)
        #expect(model.lintDiagnostics.isEmpty)

        let binaryURL = dir.appendingPathComponent("payload.bin")
        try Data([0x50, 0x4B, 0x00, 0x04, 0x41]).write(to: binaryURL)
        model.openFile(at: binaryURL, withinScope: dir)
        let revision = try #require(model.activeDocumentSession?.revision)
        model.toggleDiagnosticsPopover()
        #expect(model.activeLintStatus == .off)
        #expect(model.isDiagnosticsPopoverPresented == false)
        #expect(model.applyFixAll() == false)
        #expect(model.activeDocumentSession?.revision == revision)
    }
}
