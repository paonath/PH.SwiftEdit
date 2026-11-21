import Foundation
import Testing
@testable import SwiftEditCore

private final class MutableTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(initial: Date) {
        self.current = initial
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }
}

private struct FakeBookmarkCoder: SecurityScopedBookmarkCoding {
    var overrideResolvedPath: String? = nil
    var shouldFailResolve: Bool = false

    func makeBookmark(for url: URL) throws -> Data {
        Data(url.standardizedFileURL.path.utf8)
    }

    func resolveBookmark(_ data: Data) throws -> URL {
        if shouldFailResolve {
            throw DomainError.ioFailure("Stale or unresolvable bookmark")
        }
        if let overrideResolvedPath {
            return URL(fileURLWithPath: overrideResolvedPath)
        }
        guard let path = String(data: data, encoding: .utf8), !path.isEmpty else {
            throw DomainError.ioFailure("Invalid UTF-8 bookmark payload")
        }
        return URL(fileURLWithPath: path)
    }
}

private final class CountingSecurityScopeFake: SecurityScopedResourceAccessing, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var startCount: Int = 0
    private(set) var stopCount: Int = 0

    func startAccessing(url: URL) -> Bool {
        _ = url
        lock.lock()
        defer { lock.unlock() }
        startCount += 1
        return true
    }

    func stopAccessing(url: URL) {
        _ = url
        lock.lock()
        defer { lock.unlock() }
        stopCount += 1
    }
}

@Suite("RecentFilesStoreTests")
struct RecentFilesStoreTests {

    private static func seedTenFiles(in fs: InMemoryFileSystemFake, store: RecentFilesStore, clock: MutableTestClock) throws -> [URL] {
        let names = [
            "oldest.md", "f2.md", "f3.md", "f4.md", "f5.md",
            "notes.md", "f7.md", "f8.md", "f9.md", "f10.md",
        ]
        var urls: [URL] = []
        for name in names {
            let url = URL(fileURLWithPath: "/workspace/\(name)")
            fs.seed(url: url, data: Data("text \(name)".utf8))
            _ = try store.record(url: url)
            clock.advance(by: 10)
            urls.append(url)
        }
        return urls
    }

    @Test("P3: Reopening an existing file deduplicates and moves it to index 0, and recording an 11th file evicts the oldest")
    func p3ReopenDeduplicatesToTopAndEleventhEvictsOldest() throws {
        // GIVEN an isolated RecentFilesStore already holding 10 text files including notes.md at index 4
        let fs = InMemoryFileSystemFake()
        let clock = MutableTestClock(initial: Date(timeIntervalSince1970: 1_700_000_000))
        let store = RecentFilesStore(
            store: InMemoryKeyValueStore(),
            fileSystem: fs,
            bookmarkCoder: FakeBookmarkCoder(),
            now: { clock.now() }
        )
        let initialURLs = try Self.seedTenFiles(in: fs, store: store, clock: clock)
        let notesURL = initialURLs[5]
        let eleventhURL = URL(fileURLWithPath: "/workspace/eleventh.md")
        fs.seed(url: eleventhURL, data: Data("eleventh".utf8))
        clock.advance(by: 60)
        let reopenInstant = clock.now()

        // WHEN notes.md is reopened and subsequently an 11th file is recorded
        let afterReopen = try store.record(url: notesURL)
        clock.advance(by: 60)
        let afterEleventh = try store.record(url: eleventhURL)

        // THEN notes.md moved to index 0 with refreshed timestamp without duplication, and oldest.md was evicted at 11
        #expect(afterReopen.count == 10)
        #expect(afterReopen.first?.standardizedPath == "/workspace/notes.md")
        #expect(afterReopen.first?.lastOpenedAt == reopenInstant)
        #expect(afterEleventh.count == 10)
        #expect(afterEleventh.first?.standardizedPath == "/workspace/eleventh.md")
        #expect(afterEleventh.contains { $0.standardizedPath == "/workspace/oldest.md" } == false)
    }

    @Test("N3: Binary files are rejected with binaryFileSaveForbidden and deleted files are omitted from entries()")
    func n3BinaryAndDeletedFilesAreExcluded() throws {
        // GIVEN a recorded text file that is later deleted and a binary file containing a NUL byte
        let fs = InMemoryFileSystemFake()
        let store = RecentFilesStore(
            store: InMemoryKeyValueStore(),
            fileSystem: fs,
            bookmarkCoder: FakeBookmarkCoder()
        )
        let ephemeralTextURL = URL(fileURLWithPath: "/workspace/ephemeral.md")
        let survivingTextURL = URL(fileURLWithPath: "/workspace/surviving.md")
        let binaryURL = URL(fileURLWithPath: "/workspace/image.bin")
        fs.seed(url: ephemeralTextURL, data: Data("hello".utf8))
        fs.seed(url: survivingTextURL, data: Data("keep".utf8))
        fs.seed(url: binaryURL, data: Data([0x89, 0x50, 0x00, 0x01]))
        _ = try store.record(url: ephemeralTextURL)
        _ = try store.record(url: survivingTextURL)
        fs.removeFile(at: ephemeralTextURL)

        // WHEN attempting to record the binary file and listing entries after deletion
        #expect(throws: DomainError.binaryFileSaveForbidden) {
            _ = try store.record(url: binaryURL)
        }
        let listed = store.entries()

        // THEN no binary bookmark is stored and the deleted file is absent from entries()
        #expect(listed.count == 1)
        #expect(listed.first?.standardizedPath == "/workspace/surviving.md")
    }

    @Test("P4 & P5: resolve(entry:) brackets security-scoped access (1 == 1) and clear() erases persisted bookmark blobs")
    func p4AndP5BalancedResolveAndClearErasesBookmarks() throws {
        // GIVEN a store with a counting security-scope fake and one recorded entry
        let kvStore = InMemoryKeyValueStore()
        let fs = InMemoryFileSystemFake()
        let scope = CountingSecurityScopeFake()
        let store = RecentFilesStore(
            store: kvStore,
            fileSystem: fs,
            bookmarkCoder: FakeBookmarkCoder(),
            securityScope: scope
        )
        let notesURL = URL(fileURLWithPath: "/workspace/notes.md")
        fs.seed(url: notesURL, data: Data("notes".utf8))
        let recorded = try store.record(url: notesURL)
        let entry = try #require(recorded.first)

        // WHEN resolving the entry and subsequently clearing recent documents
        let resolvedURL = try store.resolve(entry: entry)
        store.clear()

        // THEN start/stop counts are both 1, entries() is empty, and the preferences key is removed
        #expect(resolvedURL.standardizedFileURL.path == "/workspace/notes.md")
        #expect(scope.startCount == 1)
        #expect(scope.stopCount == 1)
        #expect(store.entries().isEmpty)
        #expect(kvStore.object(forKey: RecentFilesStore.recentFilesKey) == nil)
    }

    @Test("N4 & N5 [Security]: Stale or mismatched bookmarks prune with balanced release, and corrupted or >1 MiB blobs fail closed")
    func n4AndN5SecurityStaleMismatchedBookmarksAndCorruptedBlobsFailClosed() throws {
        // GIVEN recorded entries resolved against a failing coder and a path-spoofing coder, plus corrupted/oversized payloads
        let kvStore = InMemoryKeyValueStore()
        let fs = InMemoryFileSystemFake()
        let scope = CountingSecurityScopeFake()
        let aURL = URL(fileURLWithPath: "/workspace/a.md")
        let bURL = URL(fileURLWithPath: "/workspace/b.md")
        fs.seed(url: aURL, data: Data("a".utf8))
        fs.seed(url: bURL, data: Data("b".utf8))
        let writer = RecentFilesStore(store: kvStore, fileSystem: fs, bookmarkCoder: FakeBookmarkCoder(), securityScope: scope)
        _ = try writer.record(url: aURL)
        let recorded = try writer.record(url: bURL)
        let entryB = try #require(recorded.first)
        let entryA = try #require(recorded.last)
        let failingStore = RecentFilesStore(store: kvStore, fileSystem: fs, bookmarkCoder: FakeBookmarkCoder(shouldFailResolve: true), securityScope: scope)
        let mismatchedStore = RecentFilesStore(store: kvStore, fileSystem: fs, bookmarkCoder: FakeBookmarkCoder(overrideResolvedPath: "/etc/passwd"), securityScope: scope)

        // WHEN resolving stale/mismatched bookmarks and loading malformed or >1 MiB persisted payloads
        #expect(throws: DomainError.self) {
            _ = try failingStore.resolve(entry: entryA)
        }
        #expect(throws: DomainError.securityScopeViolation(path: "/etc/passwd")) {
            _ = try mismatchedStore.resolve(entry: entryB)
        }
        let prunedEntries = writer.entries()
        kvStore.set(Data("{corrupted".utf8), forKey: RecentFilesStore.recentFilesKey)
        let afterCorrupt = writer.entries()
        let corruptRemoved = (kvStore.object(forKey: RecentFilesStore.recentFilesKey) == nil)
        kvStore.set(Data(repeating: 0x41, count: RecentFilesStore.maxPersistedPayloadBytes + 1), forKey: RecentFilesStore.recentFilesKey)
        let afterOversized = writer.entries()
        let oversizedRemoved = (kvStore.object(forKey: RecentFilesStore.recentFilesKey) == nil)

        // THEN both entries were pruned, start/stop stayed equal, and both invalid UserDefaults blobs were purged
        #expect(prunedEntries.isEmpty)
        #expect(scope.startCount == scope.stopCount)
        #expect(afterCorrupt.isEmpty)
        #expect(corruptRemoved)
        #expect(afterOversized.isEmpty)
        #expect(oversizedRemoved)
    }
}
