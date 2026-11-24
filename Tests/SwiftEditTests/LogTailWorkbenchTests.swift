import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Growing in-memory log shared by all URLs (the workbench opens fixtures from an in-memory filesystem).
private final class SharedFakeLog: LogFileReading, @unchecked Sendable {
    var bytes = Data()
    func append(_ s: String) { bytes.append(Data(s.utf8)) }
    func status(of url: URL) throws -> LogFileStatus { LogFileStatus(size: UInt64(bytes.count), identity: 7) }
    func read(_ url: URL, offset: UInt64, length: Int) throws -> Data {
        let start = Int(offset), end = min(bytes.count, start + length)
        return start < end ? bytes.subdata(in: start..<end) : Data()
    }
}

@Suite("LogTailWorkbenchTests", .serialized)
@MainActor
struct LogTailWorkbenchTests {

    @Test("P-LOGWB1: Cmd+L tails the last lines live, inverse shows newest first, line count and stop apply, other tabs stay usable")
    func pLiveTailDirectInverseAndNonBlocking() throws {
        // GIVEN an open .log tab, a Markdown tab and 100 existing log lines
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("notes.md", "# a"), ("app.log", "seed")])
        defer { try? FileManager.default.removeItem(at: dir) }
        let log = SharedFakeLog()
        log.append((1...100).map { "2026-11-22 10:00:00|INFO|App|line \($0)\n" }.joined())
        model.logFileReader = log
        // WHEN the direct tail starts, a writer appends, the mode and line count change, and the tail stops
        model.startLogTail(mode: .direct)
        let tail = try #require(model.activeLogTail)
        tail.pollNow()
        let initial = tail.text.components(separatedBy: "\n")
        log.append("2026-11-22 10:00:01|ERROR|App|boom\n")
        tail.pollNow()
        let afterAppend = tail.text.components(separatedBy: "\n")
        tail.setMode(.inverse)
        let inverseFirst = tail.text.components(separatedBy: "\n").first
        tail.setLineCount(3)
        let three = tail.visibleLineCount
        let notesID = try #require(model.tabSession.tabs.first { $0.title == "notes.md" }?.id)
        model.activateTab(id: notesID)
        model.handleEditorTextChanged("# a edited while tailing")
        let otherTabEdited = model.activeDocumentSession?.text == "# a edited while tailing"
        let logID = tail.tabID
        model.activateTab(id: logID)
        model.stopLogTail()
        log.append("ignored after stop\n")
        tail.pollNow()
        // THEN the tail behaves as specified and never blocks other work
        #expect(model.activeDocumentLanguage == .log)
        #expect(model.activeLintStatus == .off)
        #expect(initial.count == 80 && initial.last == "2026-11-22 10:00:00|INFO|App|line 100")
        #expect(afterAppend.last == "2026-11-22 10:00:01|ERROR|App|boom")
        #expect(inverseFirst == "2026-11-22 10:00:01|ERROR|App|boom")
        #expect(three == 3)
        #expect(otherTabEdited)
        #expect(!tail.isRunning)
        #expect(!tail.text.contains("ignored after stop"))
    }

    @Test("N-LOGWB1: untitled tabs refuse the tail, closing a tab stops it, and oversized logs open tail-only and cannot be saved")
    func nGuards() throws {
        // GIVEN an untitled tab and an oversized log in the in-memory filesystem
        let (model, dir) = YAMLWorkbenchHarness.makeModel()
        defer { try? FileManager.default.removeItem(at: dir) }
        model.newUntitledTab()
        model.startLogTail(mode: .direct)
        let untitledHasTail = model.activeLogTail != nil
        let fs = InMemoryFileSystemFake()
        let bigURL = URL(fileURLWithPath: "/fixtures/big.log")
        fs.seed(url: bigURL, data: Data("x\n".utf8), virtualByteSize: 200 * 1024 * 1024)
        let big = SwiftEditWorkbenchModel(preferencesStore: InMemoryKeyValueStore(), recentFilesStore: InMemoryKeyValueStore(),
                                          recoveryDirectoryURL: dir.appendingPathComponent("r2"), fileSystem: fs,
                                          systemDarkDetector: { false }, savePanelProvider: { _ in nil })
        let log = SharedFakeLog()
        log.append("tail line\n")
        big.logFileReader = log
        // WHEN the oversized log is opened, saved, its panel closed, and then its tab closed
        big.openFile(at: bigURL, withinScope: URL(fileURLWithPath: "/fixtures"))
        let tailOnlyID = try #require(big.tabSession.activeTabID)
        let tailOnly = big.logTailOnlyTabIDs.contains(tailOnlyID) && big.activeLogTail?.isRunning == true
        big.saveActiveDocument()
        let saveBanner = big.statusBannerMessage ?? ""
        big.closeLogTail()
        let stillShown = big.activeLogTail != nil
        let controller = big.activeLogTail
        big.closeTab(id: tailOnlyID)
        // THEN every guard holds
        #expect(!untitledHasTail)
        #expect(model.statusBannerMessage?.contains("save the document") == true)
        #expect(tailOnly)
        #expect(saveBanner.contains("Save blocked"))
        #expect(stillShown)
        #expect(controller?.isRunning == false)
        #expect(big.logTails[tailOnlyID] == nil)
    }

    @Test("N8 [Security]: rapid log delete/rename rotations close descriptors and re-arm non-recursively without descriptor leaks (CWE-400 / CWE-674)")
    func n8RapidRotationClosesDescriptorsNonRecursively() throws {
        // GIVEN a live LogTailWorker watching a real temporary log file on disk
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("swiftedit-rot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let logURL = tempDir.appendingPathComponent("service.log")
        try Data("epoch-0\n".utf8).write(to: logURL)

        let worker = LogTailWorker(url: logURL, reader: LocalLogFileReader()) { _, _ in }
        worker.start()
        _ = worker.pollNow()
        let activeOpenBeforeRotations = worker.descriptorMetrics.openCount

        // WHEN 8 rapid rename + recreate rotations hit the watched file
        for epoch in 1...8 {
            let rotatedURL = tempDir.appendingPathComponent("service.log.\(epoch)")
            try FileManager.default.moveItem(at: logURL, to: rotatedURL)
            try Data("epoch-\(epoch)\n".utf8).write(to: logURL)
            usleep(8_000)
            _ = worker.pollNow()
        }
        let metricsWhileRunning = worker.descriptorMetrics
        let latestBuffer = try worker.pollNow().get()
        worker.stop()
        usleep(10_000)
        let metricsAfterStop = worker.descriptorMetrics

        // THEN at most 1 descriptor is open while active, rotations disarmed cleanly, latest epoch was read, and 0 descriptors remain open after stop
        #expect(activeOpenBeforeRotations == 1)
        #expect(metricsWhileRunning.openCount == 1)
        #expect(metricsWhileRunning.rotationDisarms >= 1)
        #expect(latestBuffer.text(count: 5, mode: .direct).contains("epoch-8"))
        #expect(metricsAfterStop.openCount == 0)
    }
}
