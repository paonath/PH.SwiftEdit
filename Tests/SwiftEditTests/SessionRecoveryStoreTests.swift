import Foundation
import Testing
@testable import SwiftEditCore

enum RecoveryTestSandbox {
    static func makeRecoveryDirectory(label: String) -> URL {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repoRoot.appendingPathComponent(".tmp/test-results/recovery-\(label)-\(UUID().uuidString)/SessionRecovery")
    }
}

private extension DomainError {
    var quotaExceededByteCount: UInt64? {
        if case .sessionRecoveryQuotaExceeded(let byteCount) = self { return byteCount }
        return nil
    }
}

@Suite("SessionRecoveryStoreTests")
struct SessionRecoveryStoreTests {

    @Test("P2: SessionRecoveryStore saves/restores manifest and snapshots with 0700/0600 permissions, backup exclusion, close-unlink, and startup orphan GC")
    func p2SaveRestoreCloseUnlinkAndStartupOrphanGarbageCollection() throws {
        // GIVEN an isolated SessionRecovery directory, two active text snapshots, and one unreferenced orphan .recovery file
        let recoveryDir = RecoveryTestSandbox.makeRecoveryDirectory(label: "p2")
        defer { try? FileManager.default.removeItem(at: recoveryDir.deletingLastPathComponent()) }
        let store = SessionRecoveryStore(recoveryDirectoryURL: recoveryDir)

        let docA = DocumentSession(revision: BufferRevision(2), text: "unsaved draft A", encoding: .utf8WithBOM, lineEnding: .crlf).snapshot
        let docB = DocumentSession(text: "untitled B").snapshot
        let orphanID = DocumentID()

        var tabSession = WorkspaceTabSession()
        try tabSession.openOrActivate(snapshot: docA, title: "DraftA.md", isDirty: true, caretLocation: 7)
        try tabSession.setPinned(true, for: docA.id)
        try tabSession.openOrActivate(snapshot: docB, title: "Untitled-1", isDirty: true, caretLocation: 3)

        // WHEN persisting snapshots + manifest, seeding an orphan snapshot, running startup GC, and closing docA
        try store.saveRecoverySnapshot(docA)
        try store.saveRecoverySnapshot(docB)
        try store.saveRecoverySnapshot(DocumentSession(id: orphanID, text: "stale orphan").snapshot)
        let manifest = SessionRecoveryManifest(tabs: tabSession.tabs, activeTabID: tabSession.activeTabID)
        try store.saveManifest(manifest)

        let dirPerms = try FileManager.default.attributesOfItem(atPath: recoveryDir.path)[.posixPermissions] as? Int
        let filePerms = try FileManager.default.attributesOfItem(atPath: store.snapshotFileURL(for: docA.id).path)[.posixPermissions] as? Int
        let dirBackupExcluded = try recoveryDir.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        let fileBackupExcluded = try store.snapshotFileURL(for: docA.id).resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup

        let purgedCount = try store.purgeOrphanedSnapshots(keeping: [docA.id, docB.id])
        let loadedManifest = try #require(try store.loadManifest())
        let restoredDocA = try #require(try store.loadRecoverySnapshot(for: docA.id))
        try store.removeRecoverySnapshot(for: docA.id)
        let afterCloseDocA = try store.loadRecoverySnapshot(for: docA.id)
        let afterGCOrphan = try store.loadRecoverySnapshot(for: orphanID)
        let remainingDocB = try store.loadRecoverySnapshot(for: docB.id)

        // THEN permissions are 0700/0600, backup exclusion is set, startup GC removes the orphan, and tab close unlinks docA immediately
        #expect(dirPerms == 0o700)
        #expect(filePerms == 0o600)
        #expect(dirBackupExcluded == true)
        #expect(fileBackupExcluded == true)
        #expect(purgedCount == 1)
        #expect(loadedManifest == manifest)
        #expect(restoredDocA == RecoveredDocumentSnapshot(
            id: docA.id,
            revision: BufferRevision(2),
            text: "unsaved draft A",
            encoding: .utf8WithBOM,
            lineEnding: .crlf
        ))
        #expect(afterCloseDocA == nil)
        #expect(afterGCOrphan == nil)
        #expect(remainingDocB?.text == "untitled B")
    }

    @Test("N3: Corrupted session-manifest.json or recovery snapshot JSON throws DomainError.corruptedRecoveryManifest")
    func n3CorruptedManifestOrSnapshotFailsClosed() throws {
        // GIVEN a SessionRecovery directory seeded with malformed JSON in session-manifest.json
        let recoveryDir = RecoveryTestSandbox.makeRecoveryDirectory(label: "n3")
        defer { try? FileManager.default.removeItem(at: recoveryDir.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: recoveryDir, withIntermediateDirectories: true)
        let store = SessionRecoveryStore(recoveryDirectoryURL: recoveryDir)
        try Data("{broken-json".utf8).write(to: store.manifestFileURL)

        // WHEN / THEN loadManifest fails closed with corruptedRecoveryManifest
        #expect(throws: DomainError.corruptedRecoveryManifest) {
            _ = try store.loadManifest()
        }
    }

    @Test("N4 [Security]: SessionRecoveryStore rejects binary snapshots, quota overflows (> 64 MiB default), and symlinked recovery paths")
    func n4SecurityBinarySnapshotQuotaAndSymlinkRecoveryGuards() throws {
        // GIVEN a quota-capped recovery store, a binary snapshot, an oversized text snapshot, and a symlinked recovery directory
        let recoveryDir = RecoveryTestSandbox.makeRecoveryDirectory(label: "n4")
        let rootDir = recoveryDir.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: rootDir) }
        let quotaStore = SessionRecoveryStore(recoveryDirectoryURL: recoveryDir, maxQuotaBytes: 400)

        let binarySnapshot = DocumentSession(text: "ELF", isBinaryReadOnly: true).snapshot
        let oversizedText = String(repeating: "x", count: 500)
        let oversizedSnapshot = DocumentSession(text: oversizedText).snapshot

        let outsideTarget = rootDir.appendingPathComponent("outside-target")
        try FileManager.default.createDirectory(at: outsideTarget, withIntermediateDirectories: true)
        let symlinkRecoveryDir = rootDir.appendingPathComponent("SymlinkRecovery")
        try FileManager.default.createSymbolicLink(at: symlinkRecoveryDir, withDestinationURL: outsideTarget)
        let symlinkStore = SessionRecoveryStore(recoveryDirectoryURL: symlinkRecoveryDir)
        let cleanSnapshot = DocumentSession(text: "hello").snapshot

        // WHEN / THEN binary snapshots, quota overflows, and symlinked recovery paths all fail closed
        #expect(SessionRecoveryStore.defaultMaxQuotaBytes == 67_108_864)
        #expect(throws: DomainError.binaryFileSaveForbidden) {
            try quotaStore.saveRecoverySnapshot(binarySnapshot)
        }
        try quotaStore.saveRecoverySnapshot(cleanSnapshot)
        try quotaStore.saveRecoverySnapshot(cleanSnapshot)
        let thrownQuotaError = try #require(#expect(throws: DomainError.self) {
            try quotaStore.saveRecoverySnapshot(oversizedSnapshot)
        })
        #expect((thrownQuotaError.quotaExceededByteCount ?? 0) > 400)
        #expect(try quotaStore.loadRecoverySnapshot(for: oversizedSnapshot.id) == nil)
        #expect(throws: DomainError.securityScopeViolation(path: symlinkRecoveryDir.path)) {
            try symlinkStore.saveRecoverySnapshot(cleanSnapshot)
        }
    }
}
