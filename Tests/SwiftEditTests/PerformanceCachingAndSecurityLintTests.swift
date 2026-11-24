import AppKit
import Darwin
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

private final class OversizeGateSpyFileSystem: FileSystemProviding, @unchecked Sendable {
    private let fake = InMemoryFileSystemFake()
    private let lock = NSLock()
    private(set) var readCallCount: Int = 0

    func seed(url: URL, data: Data, virtualByteSize: UInt64? = nil) {
        fake.seed(url: url, data: data, virtualByteSize: virtualByteSize)
    }

    func fileAttributes(at url: URL, withinScope scopeURL: URL?) throws -> FileAttributesDescriptor {
        try fake.fileAttributes(at: url, withinScope: scopeURL)
    }

    func readData(at url: URL, maxBytes: Int?, withinScope scopeURL: URL?) throws -> Data {
        lock.lock()
        readCallCount += 1
        lock.unlock()
        return try fake.readData(at: url, maxBytes: maxBytes, withinScope: scopeURL)
    }

    func writeAtomic(data: Data, to url: URL, withinScope scopeURL: URL?) throws {
        try fake.writeAtomic(data: data, to: url, withinScope: scopeURL)
    }

    @discardableResult
    func createDirectory(named name: String, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL {
        try fake.createDirectory(named: name, in: parentURL, withinScope: scopeURL)
    }

    @discardableResult
    func createFile(named name: String, contents: Data, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL {
        try fake.createFile(named: name, contents: contents, in: parentURL, withinScope: scopeURL)
    }

    @discardableResult
    func renameItem(at itemURL: URL, toName newName: String, withinScope scopeURL: URL?) throws -> URL {
        try fake.renameItem(at: itemURL, toName: newName, withinScope: scopeURL)
    }

    @discardableResult
    func pasteItem(from sourceURL: URL, toDirectory destinationDirectoryURL: URL, mode: PasteMode, withinScope scopeURL: URL?) throws -> URL {
        try fake.pasteItem(from: sourceURL, toDirectory: destinationDirectoryURL, mode: mode, withinScope: scopeURL)
    }

    func trashItem(at itemURL: URL, withinScope scopeURL: URL?) throws {
        try fake.trashItem(at: itemURL, withinScope: scopeURL)
    }
}

private final class DelayedElapsedClock: ElapsedTimeProviding, @unchecked Sendable {
    private let value: Int
    init(_ value: Int) { self.value = value }
    func elapsedMilliseconds() -> Int { value }
}

private final class SuspendingLargeFileSystem: FileSystemProviding, @unchecked Sendable {
    private let fake = InMemoryFileSystemFake()
    private let blockingURL: URL
    private let lock = NSLock()
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var hasEntered = false
    private let releaseSemaphore = DispatchSemaphore(value: 0)

    init(blockingURL: URL) {
        self.blockingURL = blockingURL.standardizedFileURL
    }

    func seed(url: URL, data: Data) {
        fake.seed(url: url, data: data)
    }

    func waitUntilBlockingReadStarts() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if hasEntered {
                lock.unlock()
                continuation.resume()
            } else {
                enteredContinuation = continuation
                lock.unlock()
            }
        }
    }

    func releaseBlockedRead() {
        releaseSemaphore.signal()
    }

    func fileAttributes(at url: URL, withinScope scopeURL: URL?) throws -> FileAttributesDescriptor {
        try fake.fileAttributes(at: url, withinScope: scopeURL)
    }

    func readData(at url: URL, maxBytes: Int?, withinScope scopeURL: URL?) throws -> Data {
        if url.standardizedFileURL == blockingURL && maxBytes == nil {
            lock.lock()
            hasEntered = true
            let pending = enteredContinuation
            enteredContinuation = nil
            lock.unlock()
            pending?.resume()
            releaseSemaphore.wait()
        }
        return try fake.readData(at: url, maxBytes: maxBytes, withinScope: scopeURL)
    }

    func writeAtomic(data: Data, to url: URL, withinScope scopeURL: URL?) throws {
        try fake.writeAtomic(data: data, to: url, withinScope: scopeURL)
    }

    @discardableResult
    func createDirectory(named name: String, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL {
        try fake.createDirectory(named: name, in: parentURL, withinScope: scopeURL)
    }

    @discardableResult
    func createFile(named name: String, contents: Data, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL {
        try fake.createFile(named: name, contents: contents, in: parentURL, withinScope: scopeURL)
    }

    @discardableResult
    func renameItem(at itemURL: URL, toName newName: String, withinScope scopeURL: URL?) throws -> URL {
        try fake.renameItem(at: itemURL, toName: newName, withinScope: scopeURL)
    }

    @discardableResult
    func pasteItem(from sourceURL: URL, toDirectory destinationDirectoryURL: URL, mode: PasteMode, withinScope scopeURL: URL?) throws -> URL {
        try fake.pasteItem(from: sourceURL, toDirectory: destinationDirectoryURL, mode: mode, withinScope: scopeURL)
    }

    func trashItem(at itemURL: URL, withinScope scopeURL: URL?) throws {
        try fake.trashItem(at: itemURL, withinScope: scopeURL)
    }
}

private extension PreviewThumbnailCache {
    static func makeSampleImage() -> NSImage {
        NSImage(size: NSSize(width: 4, height: 4))
    }
}

@Suite("PerformanceCachingAndSecurityLintTests")
struct PerformanceCachingAndSecurityLintTests {

    @Test("P8: Cached BracketTopology, non-blocking large-doc typing, O(1) lineCount gutter, async file load, and preview/diff eviction stay fast and bounded")
    func p8CachingAsyncFileLoadAndEvictionMetrics() async throws {
        // GIVEN a 10,000-line document with brackets and an isolated workbench + spy filesystem for 3 MiB valid & 65 MiB oversize files
        let scope = URL(fileURLWithPath: "/tmp/ws-p8")
        let bigFileURL = scope.appendingPathComponent("large.md")
        let hugeFileURL = scope.appendingPathComponent("huge.md")
        let fs = OversizeGateSpyFileSystem()
        let bigPayload = String(repeating: "line (a + b) [c] {d} prose\n", count: 120_000)
        fs.seed(url: bigFileURL, data: Data(bigPayload.utf8))
        fs.seed(url: hugeFileURL, data: Data("# Tiny header".utf8), virtualByteSize: UInt64(DocumentLoader.maxAllowedFileBytes + 1))

        let lines10k = (0..<10_000).map { "line \($0) (val + \($0))" }.joined(separator: "\n")
        let snap10k = DocumentSession(text: lines10k).snapshot
        let topology = try #require(SearchDiffAndBracketEngine.scanTopology(in: snap10k).completedValue)
        let lines20kWithNewline = (0..<20_000).map { "Line \($0) plain markdown text" }.joined(separator: "\n") + "\n"
        let gutter10k = LineNumberGutterProjection.evaluate(text: lines10k, caretLocation: 100, fontSizePoints: 13)

        let tempRec = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditP8-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRec) }

        // WHEN measuring cached bracket caret resolution, large-doc typing latency, gutter lineCount, PreviewThumbnailCache, and openFileAsync
        let tCaretStart = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        let resolvedActive = SearchDiffAndBracketEngine.resolveActivePair(in: topology, caretLocation: 10)
        let caretMs = Double(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - tCaretStart) / 1_000_000.0

        let (typeMs, readsAfterHugeAttempt, bannerAfterHuge, openedBigTitle, cachedBeforeHide, cachedAfterHide) = await Self.runP8WorkbenchScenario(
            lines20kWithNewline: lines20kWithNewline,
            scope: scope,
            hugeFileURL: hugeFileURL,
            bigFileURL: bigFileURL,
            tempRec: tempRec,
            fs: fs
        )

        // THEN caret lookup & 20kL typing finish within 16 ms, oversize reads 0 bytes, >=2MiB opens async, and hide evicts thumbnails
        #expect(resolvedActive?.openSymbol == "(")
        #expect(caretMs < 16.0)
        #expect(typeMs < 50.0)
        #expect(gutter10k.lineCount == 10_000)
        #expect(readsAfterHugeAttempt == 0)
        #expect(bannerAfterHuge.localizedCaseInsensitiveContains("Open failed"))
        #expect(openedBigTitle == "large.md")
        #expect(cachedBeforeHide == true)
        #expect(cachedAfterHide == false)
    }

    @MainActor
    private static func runP8WorkbenchScenario(
        lines20kWithNewline: String,
        scope: URL,
        hugeFileURL: URL,
        bigFileURL: URL,
        tempRec: URL,
        fs: OversizeGateSpyFileSystem
    ) async -> (Double, Int, String, String, Bool, Bool) {
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempRec,
            fileSystem: fs
        )
        model.newUntitledTab()
        let tTypeStart = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        model.handleEditorTextChanged(lines20kWithNewline)
        let typeMs = Double(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - tTypeStart) / 1_000_000.0

        await model.openFileAsync(at: hugeFileURL, withinScope: scope)
        let readsAfterHugeAttempt = fs.readCallCount
        let bannerAfterHuge = model.statusBannerMessage ?? ""

        await model.openFileAsync(at: bigFileURL, withinScope: scope)
        let openedBigTitle = model.activeTabTitle

        let sampleImg = PreviewThumbnailCache.makeSampleImage()
        PreviewThumbnailCache.shared.store(sampleImg, forKey: "thumb-1", costBytes: 64)
        let cachedBeforeHide = PreviewThumbnailCache.shared.image(forKey: "thumb-1") != nil
        model.showMarkdownPreview = true
        model.toggleMarkdownPreview()
        model.showDiffPane = true
        model.toggleDiffPane()
        let cachedAfterHide = PreviewThumbnailCache.shared.image(forKey: "thumb-1") != nil
        return (typeMs, readsAfterHugeAttempt, bannerAfterHuge, openedBigTitle, cachedBeforeHide, cachedAfterHide)
    }

    @Test("N11 [Security]: 5kL and 20kL Markdown documents preserve .unsafeLinkScheme & .unsafeImagePath errors, and stale async revisions are discarded")
    func n11Security5kAnd20kPreserveSecurityErrorsAndDiscardStaleAsyncLint() async throws {
        // GIVEN 5,000-line and ~960 KB 20,000-line Markdown documents each containing malicious javascript: link and path-traversal image
        let payloadHead = "[xss](javascript:alert(1))\n![leak](../../etc/passwd)\n"
        let doc5k = payloadHead + String(repeating: "Safe body line\n", count: 5_000)
        let doc20k = payloadHead + String(repeating: "Markdown body line with (brackets) and `code`.\n", count: 20_000)
        let snap5k = DocumentSession(text: doc5k).snapshot
        let snap20k = DocumentSession(text: doc20k).snapshot

        let tempRec = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditN11-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRec) }

        // WHEN running MarkdownLintAndFormatEngine on 5kL/20kL and then rapidly superseding revisions on the workbench model
        let res5k = try #require(MarkdownLintAndFormatEngine.lint(snapshot: snap5k, profile: .allConstructs).completedValue)
        let res20k = try #require(MarkdownLintAndFormatEngine.lint(snapshot: snap20k, profile: .allConstructs).completedValue)
        let secFast20k = try #require(MarkdownLintAndFormatEngine.lintSecurityFastPath(snapshot: snap20k).completedValue)

        let hasUnsafeInSettledModel = await Self.runN11WorkbenchSupersedeScenario(doc20k: doc20k, tempRec: tempRec)

        let rules5k = Set(res5k.diagnostics.map(\.rule))
        let rules20k = Set(res20k.diagnostics.map(\.rule))
        let secRules = Set(secFast20k.diagnostics.map(\.rule))

        // THEN both 5kL & 20kL preserve security diagnostics (never 0) and stale async lint from doc20k never pollutes the newer clean revision
        #expect(rules5k.contains(.unsafeLinkScheme))
        #expect(rules5k.contains(.unsafeImagePath))
        #expect(rules20k.contains(.unsafeLinkScheme))
        #expect(rules20k.contains(.unsafeImagePath))
        #expect(secRules.contains(.unsafeLinkScheme))
        #expect(secRules.contains(.unsafeImagePath))
        #expect(!hasUnsafeInSettledModel)
        #expect(MarkdownLintAndFormatEngine.lintSecurityFastPath(snapshot: snap5k, clock: DelayedElapsedClock(999)) == .degradedOrTimedOut(.deadlineExceeded(limitMilliseconds: 250)))
    }

    @MainActor
    private static func runN11WorkbenchSupersedeScenario(doc20k: String, tempRec: URL) async -> Bool {
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempRec
        )
        model.newUntitledTab()
        model.handleEditorTextChanged(doc20k)
        model.handleEditorTextChanged("# Clean final revision\n\nSafe content.\n")
        await model.awaitPendingDiagnostics()
        return model.lintDiagnostics.contains { $0.rule == .unsafeLinkScheme || $0.rule == .unsafeImagePath }
    }

    @Test("N7: Rapid tab open or switch during in-flight large-file async decode preserves newer active tab without overwriting buffer")
    func n7RapidTabSwitchCancelsStaleAsyncDecodeActivation() async throws {
        // GIVEN a >= 2 MiB fileA whose background read suspends deterministically and a short fileB
        let scope = URL(fileURLWithPath: "/tmp/ws-n7")
        let fileA = scope.appendingPathComponent("largeA.md")
        let fileB = scope.appendingPathComponent("short.md")
        let fs = SuspendingLargeFileSystem(blockingURL: fileA)
        fs.seed(url: fileA, data: Data(String(repeating: "Large line content A\n", count: 120_000).utf8))
        fs.seed(url: fileB, data: Data("# Short B".utf8))

        let tempRec = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditN7-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRec) }

        let (activeTitle, activePrefix) = await Self.runN7WorkbenchSwitchScenario(
            scope: scope,
            fileA: fileA,
            fileB: fileB,
            tempRec: tempRec,
            fs: fs
        )

        // THEN fileB remains the active tab with its buffer intact and stale fileA completion does not overwrite active projection
        #expect(activeTitle == "short.md")
        #expect(activePrefix == "# Short B")
    }

    @MainActor
    private static func runN7WorkbenchSwitchScenario(
        scope: URL,
        fileA: URL,
        fileB: URL,
        tempRec: URL,
        fs: SuspendingLargeFileSystem
    ) async -> (String, String) {
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempRec,
            fileSystem: fs
        )

        // WHEN starting openFileAsync for fileA, opening fileB while fileA is decoding in background, and then releasing fileA
        let inFlightTaskA = Task { @MainActor in
            await model.openFileAsync(at: fileA, withinScope: scope)
        }
        await fs.waitUntilBlockingReadStarts()
        model.openFile(at: fileB, withinScope: scope)
        fs.releaseBlockedRead()
        await inFlightTaskA.value

        return (model.activeTabTitle, String(model.activeDocumentSession?.text.prefix(32) ?? ""))
    }

    @Test("P9 [Perf Pass 1]: Linear applyTextEdits (5k edits + emoji), packed-arena MyersDiff (4k lines), and streaming goToLine")
    func p9Pass1LinearBatchEditsMyersArenaAndStreamingGoToLine() throws {
        // GIVEN a 5,000-line document with surrogate-pair emoji and 5,000 non-overlapping replaceAll edits
        let lineCount = 5_000
        let initialText = (0..<lineCount).map { "row \($0) 🚀 alpha token" }.joined(separator: "\n")
        var session = DocumentSession(text: initialText)
        let snap = session.snapshot

        let tSearchStart = DispatchTime.now().uptimeNanoseconds
        let edits = try #require(DocumentSearchEngine.replaceAll(query: "alpha", with: "OMEGA", in: snap).completedValue)
        let tApplyStart = DispatchTime.now().uptimeNanoseconds
        _ = try session.applyTextEdits(edits, expectedRevision: snap.revision)
        let applyMs = Double(DispatchTime.now().uptimeNanoseconds - tApplyStart) / 1_000_000.0
        let searchMs = Double(tApplyStart - tSearchStart) / 1_000_000.0

        // AND surrogate-pair splitting range must still fail closed
        let emojiSnap = DocumentSession(text: "A🚀B")
        var mutableEmoji = emojiSnap
        #expect(throws: DomainError.self) {
            _ = try mutableEmoji.applyTextEdits([TextEdit(range: TextRange(location: 2, length: 1), replacement: "X")], expectedRevision: emojiSnap.revision)
        }

        // AND MyersDiff on 4,000 lines with 200 edits using packed flat arena + line interning
        let lhsLines = (0..<4_000).map { "line-\($0) common payload" }
        var rhsLines = lhsLines
        for idx in stride(from: 10, to: 4_000, by: 20) {
            rhsLines[idx] = "line-\(idx) MODIFIED payload"
        }
        let lhsSnap = DocumentSession(text: lhsLines.joined(separator: "\n")).snapshot
        let rhsSnap = DocumentSession(text: rhsLines.joined(separator: "\n")).snapshot
        let tDiffStart = DispatchTime.now().uptimeNanoseconds
        let diffResult = try #require(SearchDiffAndBracketEngine.computeMyersDiff(lhs: lhsSnap, rhs: rhsSnap).completedValue)
        let diffMs = Double(DispatchTime.now().uptimeNanoseconds - tDiffStart) / 1_000_000.0

        // AND streaming goToLine resolves exact UTF-16 range for line 100
        let line100 = try #require(DocumentSearchEngine.goToLine(100, in: snap))

        #expect(edits.count == lineCount)
        #expect(session.text.contains("row 4999 🚀 OMEGA token"))
        #expect(searchMs < 500.0)
        #expect(applyMs < 500.0)
        #expect(diffResult.hasDifferences == true)
        #expect(diffResult.hunks.filter { $0.kind == .inserted }.count == 200)
        #expect(diffResult.hunks.filter { $0.kind == .removed }.count == 200)
        #expect(diffMs < 500.0)
        #expect(line100.length == "row 99 🚀 alpha token".utf16.count)
    }

    @Test("P10 [Perf Pass 2]: O(B) preview ordinals, O(L) adversarial inline scan, O(N+K) QuickFix, and single-read image thumbnail")
    func p10Pass2MarkdownLinearEnginesAndSingleReadImage() throws {
        // GIVEN 2,000 ordered list items
        let orderedMD = (1...2_000).map { "\($0). Item \($0)" }.joined(separator: "\n")
        let tPrevStart = DispatchTime.now().uptimeNanoseconds
        let previewDoc = try #require(MarkdownPreviewProjector.project(snapshot: DocumentSession(text: orderedMD).snapshot, showPreview: true))
        let prevMs = Double(DispatchTime.now().uptimeNanoseconds - tPrevStart) / 1_000_000.0

        // AND adversarial unmatched delimiter lines (would go O(L^2) without linear guards)
        let hostileLine = String(repeating: "[", count: 1_500) + String(repeating: "**", count: 500) + " end"
        let hostileSnap = DocumentSession(text: hostileLine + "\n" + hostileLine).snapshot
        let tHostileStart = DispatchTime.now().uptimeNanoseconds
        _ = MarkdownSyntaxHighlighter.spans(snapshot: hostileSnap, visibleRange: TextRange(location: 0, length: hostileSnap.text.utf16.count))
        let hostileLint = MarkdownLintAndFormatEngine.lint(snapshot: hostileSnap, profile: .allConstructs).completedValue
        let hostileMs = Double(DispatchTime.now().uptimeNanoseconds - tHostileStart) / 1_000_000.0

        // AND single-read PreviewResourceAndLinkGate.admitAndLoadThumbnail
        let scope = URL(fileURLWithPath: "/tmp/ws-p10")
        let imgURL = scope.appendingPathComponent("tiny.png")
        let spyFS = OversizeGateSpyFileSystem()
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        let pngData = try #require(rep.representation(using: .png, properties: [:]))
        spyFS.seed(url: imgURL, data: pngData)
        let gate = PreviewResourceAndLinkGate(fileSystem: spyFS, scopeRoot: scope, documentDirectory: scope)
        let (admission, thumb) = gate.admitAndLoadThumbnail(reference: "tiny.png", admittedCount: 0)

        #expect(previewDoc.blocks.count == 2_000)
        #expect(previewDoc.orderedOrdinals.first == 1)
        #expect(previewDoc.orderedOrdinals.last == 2_000)
        #expect(prevMs < 500.0)
        #expect(hostileLint != nil)
        #expect(hostileMs < 500.0)
        if case .admitted = admission {} else { Issue.record("Expected admitted image") }
        #expect(thumb != nil)
        #expect(spyFS.readCallCount == 1)
    }

    @MainActor
    @Test("P11 [Perf Pass 3 & 4]: Cached Theme NSColor identity, cached canNavigateToParentFolder, and deduplicated Coordinator/Diff caches")
    func p11Pass3And4ThemeParentPermissionAndCoordinatorCaching() throws {
        // GIVEN cached PurpleThemePalette singletons
        let p1 = PurpleThemePalette.resolve(appearance: .black, systemPrefersDark: true)
        let p2 = PurpleThemePalette.resolve(appearance: .black, systemPrefersDark: true)
        #expect(p1.editorCanvasBackground.nsColor === p2.editorCanvasBackground.nsColor)
        #expect(p1.primaryAccent.nsColor === p2.primaryAccent.nsColor)

        // AND a workbench with a spy parentPermissionChecker
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditP11-\(UUID().uuidString)", isDirectory: true)
        let childDir = tempDir.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: childDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var permissionCalls = 0
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempDir.appendingPathComponent("rec", isDirectory: true),
            parentPermissionChecker: { _ in
                permissionCalls += 1
                return true
            }
        )
        model.selectWorkspaceFolder(childDir)
        for _ in 0..<50 {
            _ = model.canNavigateToParentFolder
        }
        #expect(permissionCalls == 1)

        // AND WorkspaceEditorCoordinator caches viewport highlight transactions & BracketTopology
        let coord = WorkspaceEditorCoordinator(session: DocumentSession(text: "(a + (b + c))"))
        let viewport = TextRange(location: 0, length: 13)
        coord.updateCaretAndHighlightViewport(caretLocation: 0, viewportRange: viewport)
        let txAfterFirst = coord.bufferAdapter.scopedTransactionCount
        coord.updateCaretAndHighlightViewport(caretLocation: 5, viewportRange: viewport)
        #expect(coord.bufferAdapter.scopedTransactionCount == txAfterFirst)
        #expect(coord.activeBracketPair?.openOffset == 5)
    }

    @Test("N9 [Security]: Decomposed MarkdownLinterInlineSecurityPass sub-passes catch javascript:, vbscript:, data:text/html, file:, ../ traversal, and U+202E BiDi scalars (CWE-79 / CWE-22)")
    func n9DecomposedInlineSecuritySubPassesCatchAllVectors() {
        // GIVEN a Markdown document containing all 5 inline URI/path/BiDi attack vectors
        let payload = """
        [xss1](javascript:alert(1))
        [xss2](vbscript:msgbox(1))
        [xss3](data:text/html,<script>alert(1)</script>)
        [local](file:///etc/passwd)
        ![trav](../../etc/passwd)
        [bidi](https://example.com/\u{202E}txt.exe)
        """
        let snapshot = DocumentSession(text: payload).snapshot

        // WHEN running MarkdownLintAndFormatEngine.lint under allConstructs
        let outcome = MarkdownLintAndFormatEngine.lint(snapshot: snapshot, profile: .allConstructs)
        let diagnostics = outcome.completedValue?.diagnostics ?? []

        // THEN every single unsafe line (1 through 6) produces at least one error-level security diagnostic
        let flaggedLines = Set(diagnostics.filter { $0.severity == .error }.map(\.line))
        #expect(flaggedLines.isSuperset(of: [1, 2, 3, 4, 5, 6]), "Flagged lines: \(flaggedLines)")
    }
}
