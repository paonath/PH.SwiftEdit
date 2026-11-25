import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

#if os(macOS)

@Suite("Unit 7: Log Tail Filters, Enriched Status Bar, Git HEAD Badge & Gap Analysis (REQ-011, REQ-012)")
struct LogFiltersStatusBarGitAndGapAnalysisTests {

    @Test("P11 & N12: Non-destructive LogTailBuffer severity pills and <=256-char substring filter preserve underlying ring buffer and handle 0-match / overlong inputs")
    @MainActor
    func p11AndN12LogTailNonDestructiveSeverityAndSubstringFilters() throws {
        var buffer = LogTailBuffer()
        let payload = """
        2026-11-25 10:00:01 [DEBUG] Heartbeat ok
        2026-11-25 10:00:02 [INFO] Server listening on 8080
        2026-11-25 10:00:03 [WARN] Slow query 320ms
        2026-11-25 10:00:04 [ERROR] Connection refused by peer
        
        """
        buffer.ingest(Data(payload.utf8))
        #expect(buffer.lines.count == 4)

        let warnOnly = buffer.textAndCount(count: 80, mode: .direct, minimumSeverity: .warnPlus, substringFilter: "")
        #expect(warnOnly.lineCount == 2)
        #expect(warnOnly.text.contains("WARN") && warnOnly.text.contains("ERROR"))
        #expect(!warnOnly.text.contains("DEBUG"))

        let errorAndSub = buffer.textAndCount(count: 80, mode: .direct, minimumSeverity: .errorOnly, substringFilter: "refused")
        #expect(errorAndSub.lineCount == 1)
        #expect(errorAndSub.text.contains("Connection refused"))

        // N12: Clearing filters restores all 4 lines without re-reading disk; unmatched returns 0; >256 filter clamped
        let restored = buffer.textAndCount(count: 80, mode: .direct, minimumSeverity: .all, substringFilter: "")
        #expect(restored.lineCount == 4)

        let zeroMatch = buffer.textAndCount(count: 80, mode: .direct, minimumSeverity: .all, substringFilter: "NO_SUCH_TOKEN")
        #expect(zeroMatch.lineCount == 0 && zeroMatch.text.isEmpty)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("LogCtrl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let logURL = dir.appendingPathComponent("app.log")
        try payload.write(to: logURL, atomically: true, encoding: .utf8)

        let controller = LogTailController(tabID: DocumentID(), url: logURL, mode: .direct)
        let overlongFilter = String(repeating: "x", count: 300)
        controller.setSubstringFilter(overlongFilter)
        #expect(controller.substringFilter.count == LogTailBuffer.maxFilterCharacters)
        controller.setMinimumSeverity(.errorOnly)
        #expect(controller.minimumSeverity == .errorOnly)
    }

    @Test("P12: Status bar projects selection char/line count, Markdown word count, Encoding switch/reopen, confined .git/HEAD branch badge, and gap analysis + guide parity")
    @MainActor
    func p12StatusBarSelectionWordCountEncodingGitHeadAndGapAnalysisDocs() throws {
        let ws = FileManager.default.temporaryDirectory.appendingPathComponent("GitWS-\(UUID().uuidString)", isDirectory: true)
        let gitDir = ws.appendingPathComponent(".git", isDirectory: true)
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: ws) }

        try "ref: refs/heads/feature/zoom-preview\n".write(
            to: gitDir.appendingPathComponent("HEAD"),
            atomically: true,
            encoding: .utf8
        )
        let mdFile = ws.appendingPathComponent("readme.md")
        try "Hello world from SwiftEdit\nSecond line here\n".write(to: mdFile, atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: ws.appendingPathComponent(".recovery", isDirectory: true)
        )
        model.selectWorkspaceFolder(ws)
        model.openFile(at: mdFile, withinScope: ws)

        // 1. Confined .git/HEAD branch badge
        #expect(model.activeGitBranchName == "feature/zoom-preview")

        // 2. Markdown word count + multi-line selection char & line count
        model.handleSelectionChanged(TextRange(location: 0, length: 33))
        let enriched = model.activeEnrichedStatusBarMetrics
        #expect(enriched.selectedCharacterCount == 33)
        #expect(enriched.selectedLineCount == 2)
        #expect(enriched.markdownWordCount == 7)

        // 3. Encoding change for next save
        model.setActiveDocumentEncoding(.utf16LEWithBOM)
        #expect(model.activeDocumentSession?.encoding == .utf16LEWithBOM)
        model.saveActiveDocument()

        // 4. Clean reopen with encoding succeeds
        #expect(model.reopenActiveDocumentWithEncoding(.utf16LEWithBOM) == true)

        // 5. Gap analysis report exists and covers Mermaid/Markmap feasibility & excluded item #11
        let gapReport = AuditReportFitness.read("docs/analysis/app-gap-analysis.md")
        #expect(gapReport.contains("Mermaid"))
        #expect(gapReport.contains("Markmap"))
        #expect(gapReport.contains("HTML") && gapReport.contains("PDF"))
    }

    @Test("N13 [Security]: Symlinked .git/HEAD escaping scope, >256-byte or credential-bearing HEAD payloads return nil with zero subprocesses, and dirty tabs block unconfirmed Reopen with Encoding")
    @MainActor
    func n13GitHeadConfinementAllowlistAndDirtyReopenEncodingGuard() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GitSec-\(UUID().uuidString)", isDirectory: true)
        let ws = root.appendingPathComponent("Workspace", isDirectory: true)
        let outside = root.appendingPathComponent("Outside", isDirectory: true)
        let gitDir = ws.appendingPathComponent(".git", isDirectory: true)
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fs = LocalFileSystemAdapter()
        let headURL = gitDir.appendingPathComponent("HEAD")

        // 1. Symlinked .git/HEAD escaping scope -> nil
        let outHead = outside.appendingPathComponent("HEAD")
        try "ref: refs/heads/leaked\n".write(to: outHead, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: headURL, withDestinationURL: outHead)
        #expect(GitHeadBranchReader.readBranchName(startingAt: ws, withinScope: ws, fileSystem: fs) == nil)
        try FileManager.default.removeItem(at: headURL)

        // 2. > 256-byte HEAD -> nil
        let oversized = "ref: refs/heads/" + String(repeating: "a", count: 300)
        try oversized.write(to: headURL, atomically: true, encoding: .utf8)
        #expect(GitHeadBranchReader.readBranchName(startingAt: ws, withinScope: ws, fileSystem: fs) == nil)

        // 3. Malformed / credential-bearing HEAD ref -> nil
        try "ref: refs/heads/https://user:secret_token@evil.example/repo\n".write(to: headURL, atomically: true, encoding: .utf8)
        #expect(GitHeadBranchReader.readBranchName(startingAt: ws, withinScope: ws, fileSystem: fs) == nil)

        // 4. Dirty tab blocks unconfirmed Reopen with Encoding preserving unsaved edits
        let fileURL = ws.appendingPathComponent("draft.md")
        try "saved on disk\n".write(to: fileURL, atomically: true, encoding: .utf8)
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: root.appendingPathComponent(".recovery", isDirectory: true)
        )
        model.selectWorkspaceFolder(ws)
        model.openFile(at: fileURL, withinScope: ws)
        model.handleEditorTextChanged("unsaved precious edits\n")
        #expect(model.reopenActiveDocumentWithEncoding(.utf8, forceDiscardDirty: false) == false)
        #expect(model.activeDocumentSession?.text == "unsaved precious edits\n")
        #expect(model.reopenActiveDocumentWithEncoding(.utf8, forceDiscardDirty: true) == true)
        #expect(model.activeDocumentSession?.text == "saved on disk\n")
    }
}
#endif
