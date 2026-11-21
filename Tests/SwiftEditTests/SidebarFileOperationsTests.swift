import Foundation
import Testing
@testable import SwiftEditCore

private final class RecordingTrasherFake: ItemTrashing, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var trashedURLs: [URL] = []

    func trashItem(at url: URL) throws {
        lock.lock()
        trashedURLs.append(url)
        lock.unlock()
        try FileManager.default.removeItem(at: url)
    }
}

@Suite("SidebarFileOperationsTests")
struct SidebarFileOperationsTests {

    private static func makeWorkspace(label: String) throws -> URL {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".tmp/test-results/\(label)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("P9: createDirectory, createFile, and renameItem succeed inside workspace scope on both LocalFileSystemAdapter and InMemoryFileSystemFake")
    func p9CreateFolderCreateFileAndRenameInsideScope() throws {
        // GIVEN an authorized workspace folder on disk and an InMemoryFileSystemFake
        let root = try Self.makeWorkspace(label: "sidebar-p9")
        defer { try? FileManager.default.removeItem(at: root) }
        let adapter = LocalFileSystemAdapter()
        let fake = InMemoryFileSystemFake()
        let fakeRoot = URL(fileURLWithPath: "/mem")

        // WHEN creating folder 'docs', creating file 'notes.md', and renaming 'notes.md' to 'final.md'
        let docsURL = try adapter.createDirectory(named: "docs", in: root, withinScope: root)
        let notesURL = try adapter.createFile(named: "notes.md", contents: Data("draft".utf8), in: root, withinScope: root)
        let finalURL = try adapter.renameItem(at: notesURL, toName: "final.md", withinScope: root)
        _ = try fake.createDirectory(named: "docs", in: fakeRoot, withinScope: fakeRoot)
        let fakeNotes = try fake.createFile(named: "notes.md", contents: Data("draft".utf8), in: fakeRoot, withinScope: fakeRoot)
        let fakeFinal = try fake.renameItem(at: fakeNotes, toName: "final.md", withinScope: fakeRoot)

        // THEN 'docs' and 'final.md' exist, 'notes.md' is gone, and returned URLs are standardized
        #expect(FileManager.default.fileExists(atPath: docsURL.path))
        #expect(FileManager.default.fileExists(atPath: finalURL.path))
        #expect(FileManager.default.fileExists(atPath: notesURL.path) == false)
        #expect(finalURL.lastPathComponent == "final.md")
        #expect(fake.storedData(at: fakeFinal) == Data("draft".utf8))
        #expect(fake.storedData(at: fakeNotes) == nil)
    }

    @Test(
        "N10: Invalid single-segment names throw DomainError.invalidItemName without mutating disk",
        arguments: [
            "",
            ".",
            "..",
            "a/b",
            "a:b",
            "bad\u{0000}nul.txt",
            "bad\u{001F}ctrl.txt",
            "bad\u{202E}bidi.txt",
            String(repeating: "x", count: 256),
        ]
    )
    func n10InvalidItemNamesThrowInvalidItemName(badName: String) throws {
        // GIVEN an empty granted workspace folder
        let root = try Self.makeWorkspace(label: "sidebar-n10-bad")
        defer { try? FileManager.default.removeItem(at: root) }
        let adapter = LocalFileSystemAdapter()

        // WHEN attempting to create a file with an invalid single-segment name
        // THEN DomainError.invalidItemName is thrown and the workspace stays empty
        #expect(throws: DomainError.invalidItemName(badName)) {
            _ = try adapter.createFile(named: badName, contents: Data(), in: root, withinScope: root)
        }
        let entries = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(entries.isEmpty)
    }

    @Test("N10: Creating or renaming onto an already-existing destination throws DomainError.destinationAlreadyExists")
    func n10ExistingDestinationThrowsDestinationAlreadyExists() throws {
        // GIVEN a workspace containing 'existing.md' and 'draft.md'
        let root = try Self.makeWorkspace(label: "sidebar-n10-dup")
        defer { try? FileManager.default.removeItem(at: root) }
        let existingURL = root.appendingPathComponent("existing.md").standardizedFileURL
        let draftURL = root.appendingPathComponent("draft.md").standardizedFileURL
        try Data("keep".utf8).write(to: existingURL)
        try Data("draft".utf8).write(to: draftURL)
        let adapter = LocalFileSystemAdapter()

        // WHEN attempting createFile or renameItem onto 'existing.md'
        // THEN both throw destinationAlreadyExists and 'existing.md' retains its original bytes
        #expect(throws: DomainError.destinationAlreadyExists(path: existingURL.path)) {
            _ = try adapter.createFile(named: "existing.md", contents: Data("overwrite".utf8), in: root, withinScope: root)
        }
        #expect(throws: DomainError.destinationAlreadyExists(path: existingURL.path)) {
            _ = try adapter.renameItem(at: draftURL, toName: "existing.md", withinScope: root)
        }
        #expect(try Data(contentsOf: existingURL) == Data("keep".utf8))
    }

    @Test("N11 [Security]: Creating inside a symlinked parent escaping scope or renaming the scope root itself throws securityScopeViolation")
    func n11SecurityEscapingParentAndScopeRootRenameAreBlocked() throws {
        // GIVEN a workspace root and an outside directory linked via a symlink inside the workspace
        let container = try Self.makeWorkspace(label: "sidebar-n11")
        defer { try? FileManager.default.removeItem(at: container) }
        let scopeRoot = container.appendingPathComponent("workspace")
        let outsideDir = container.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: scopeRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        let escapingLink = scopeRoot.appendingPathComponent("link-out")
        try FileManager.default.createSymbolicLink(at: escapingLink, withDestinationURL: outsideDir)
        let adapter = LocalFileSystemAdapter()

        // WHEN attempting to create a file inside 'link-out' or rename the granted scope root itself
        // THEN both throw DomainError.securityScopeViolation and 'outside' remains empty while 'workspace' stays intact
        #expect(throws: DomainError.securityScopeViolation(path: escapingLink.path)) {
            _ = try adapter.createFile(named: "pwn.txt", contents: Data("x".utf8), in: escapingLink, withinScope: scopeRoot)
        }
        #expect(throws: DomainError.securityScopeViolation(path: scopeRoot.path)) {
            _ = try adapter.renameItem(at: scopeRoot, toName: "hijacked", withinScope: scopeRoot)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outsideDir.path).isEmpty)
        #expect(FileManager.default.fileExists(atPath: scopeRoot.path))
    }

    @Test("P10: pasteItem copies twice with 'copy' and 'copy 2' suffixes and moves cut items cleanly")
    func p10CopyCollisionSuffixesAndCutMoveInsideScope() throws {
        // GIVEN a workspace containing 'final.md' and subfolder 'docs'
        let root = try Self.makeWorkspace(label: "sidebar-p10")
        defer { try? FileManager.default.removeItem(at: root) }
        let adapter = LocalFileSystemAdapter()
        let docsURL = try adapter.createDirectory(named: "docs", in: root, withinScope: root)
        let finalURL = try adapter.createFile(named: "final.md", contents: Data("v1".utf8), in: root, withinScope: root)

        // WHEN 'final.md' is copied twice into the same folder and the first copy is cut-pasted into 'docs'
        let copyOne = try adapter.pasteItem(from: finalURL, toDirectory: root, mode: .copy, withinScope: root)
        let copyTwo = try adapter.pasteItem(from: finalURL, toDirectory: root, mode: .copy, withinScope: root)
        let movedCopyOne = try adapter.pasteItem(from: copyOne, toDirectory: docsURL, mode: .cut, withinScope: root)

        // THEN copies use 'final copy.md' and 'final copy 2.md', original stays intact, and cut moved copyOne into 'docs'
        #expect(copyOne.lastPathComponent == "final copy.md")
        #expect(copyTwo.lastPathComponent == "final copy 2.md")
        #expect(FileManager.default.fileExists(atPath: finalURL.path))
        #expect(FileManager.default.fileExists(atPath: copyOne.path) == false)
        #expect(FileManager.default.fileExists(atPath: movedCopyOne.path))
        #expect(movedCopyOne.path == docsURL.appendingPathComponent("final copy.md").standardizedFileURL.path)
    }

    @Test("N12: Self-descendant directory paste throws invalidPasteTarget and cut onto existing destination throws destinationAlreadyExists")
    func n12SelfDescendantPasteAndCutCollisionAreRejected() throws {
        // GIVEN folder 'src/nested' and colliding 'docs/note.md' + 'note.md'
        let root = try Self.makeWorkspace(label: "sidebar-n12")
        defer { try? FileManager.default.removeItem(at: root) }
        let adapter = LocalFileSystemAdapter()
        let srcURL = try adapter.createDirectory(named: "src", in: root, withinScope: root)
        let nestedURL = try adapter.createDirectory(named: "nested", in: srcURL, withinScope: root)
        let docsURL = try adapter.createDirectory(named: "docs", in: root, withinScope: root)
        let topNote = try adapter.createFile(named: "note.md", contents: Data("new".utf8), in: root, withinScope: root)
        let docsNote = try adapter.createFile(named: "note.md", contents: Data("keep".utf8), in: docsURL, withinScope: root)

        // WHEN pasting 'src' into 'src/nested' and cut-pasting 'note.md' into 'docs' where 'note.md' already exists
        // THEN invalidPasteTarget and destinationAlreadyExists are thrown without overwriting or moving either file
        #expect(throws: DomainError.invalidPasteTarget(path: nestedURL.path)) {
            _ = try adapter.pasteItem(from: srcURL, toDirectory: nestedURL, mode: .copy, withinScope: root)
        }
        #expect(throws: DomainError.destinationAlreadyExists(path: docsNote.path)) {
            _ = try adapter.pasteItem(from: topNote, toDirectory: docsURL, mode: .cut, withinScope: root)
        }
        #expect(try Data(contentsOf: docsNote) == Data("keep".utf8))
        #expect(FileManager.default.fileExists(atPath: topNote.path))
    }

    @Test("P11 & N14 [Security]: trashItem invokes ItemTrashing once for confined items and blocks scope-root or escaping symlink targets")
    func p11AndN14SecurityTrashSeamAndScopeConfinement() throws {
        // GIVEN a workspace with 'draft.md', an outside file, and a symlink inside workspace pointing outside
        let container = try Self.makeWorkspace(label: "sidebar-trash-sec")
        defer { try? FileManager.default.removeItem(at: container) }
        let root = container.appendingPathComponent("workspace")
        let outsideFile = container.appendingPathComponent("outside.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("secret".utf8).write(to: outsideFile)
        let escapingLink = root.appendingPathComponent("escape.txt")
        try FileManager.default.createSymbolicLink(at: escapingLink, withDestinationURL: outsideFile)
        let trasher = RecordingTrasherFake()
        let adapter = LocalFileSystemAdapter(trasher: trasher)
        let draftURL = try adapter.createFile(named: "draft.md", contents: Data("bye".utf8), in: root, withinScope: root)

        // WHEN trashing 'draft.md', attempting to trash the scope root, and attempting to trash the escaping symlink
        try adapter.trashItem(at: draftURL, withinScope: root)

        // THEN trasher received only 'draft.md' once, while scope-root and escaping-symlink trash calls throw securityScopeViolation
        #expect(trasher.trashedURLs == [draftURL.standardizedFileURL])
        #expect(FileManager.default.fileExists(atPath: draftURL.path) == false)
        #expect(throws: DomainError.securityScopeViolation(path: root.path)) {
            try adapter.trashItem(at: root, withinScope: root)
        }
        #expect(throws: DomainError.securityScopeViolation(path: escapingLink.path)) {
            try adapter.trashItem(at: escapingLink, withinScope: root)
        }
        #expect(trasher.trashedURLs.count == 1)
    }

    @Test("N13 [Security]: pasteItem rejects source trees with symlinks, item/byte cap overflows, and out-of-scope destinations with zero partial copy")
    func n13SecurityHostileCopySourceAndOutOfScopeDestinationRejected() throws {
        // GIVEN a folder with a symlink, a folder exceeding maxCopyItems (3 > 2), and an out-of-scope destination
        let container = try Self.makeWorkspace(label: "sidebar-paste-sec")
        defer { try? FileManager.default.removeItem(at: container) }
        let root = container.appendingPathComponent("workspace")
        let outsideDir = container.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        let adapter = LocalFileSystemAdapter(maxCopyItems: 2, maxCopyBytes: 256)
        let destDir = try adapter.createDirectory(named: "dest", in: root, withinScope: root)
        let symlinkSrcDir = try adapter.createDirectory(named: "with-link", in: root, withinScope: root)
        let okFile = try adapter.createFile(named: "ok.txt", contents: Data("ok".utf8), in: root, withinScope: root)
        try FileManager.default.createSymbolicLink(
            at: symlinkSrcDir.appendingPathComponent("sym.txt"),
            withDestinationURL: okFile
        )
        let bigDir = try adapter.createDirectory(named: "too-many", in: root, withinScope: root)
        _ = try adapter.createFile(named: "1.txt", contents: Data("1".utf8), in: bigDir, withinScope: root)
        _ = try adapter.createFile(named: "2.txt", contents: Data("2".utf8), in: bigDir, withinScope: root)
        _ = try adapter.createFile(named: "3.txt", contents: Data("3".utf8), in: bigDir, withinScope: root)

        // WHEN pasting the symlinked folder, the 3-item folder (cap 2), and pasting 'ok.txt' into 'outside'
        // THEN securityScopeViolation and batchLimitExceeded are thrown before any file is copied into 'dest' or 'outside'
        #expect(throws: DomainError.securityScopeViolation(path: symlinkSrcDir.appendingPathComponent("sym.txt").path)) {
            _ = try adapter.pasteItem(from: symlinkSrcDir, toDirectory: destDir, mode: .copy, withinScope: root)
        }
        #expect(throws: DomainError.batchLimitExceeded(maxBytes: 256)) {
            _ = try adapter.pasteItem(from: bigDir, toDirectory: destDir, mode: .copy, withinScope: root)
        }
        #expect(throws: DomainError.securityScopeViolation(path: outsideDir.path)) {
            _ = try adapter.pasteItem(from: okFile, toDirectory: outsideDir, mode: .copy, withinScope: root)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: destDir.path).isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: outsideDir.path).isEmpty)
    }
}
