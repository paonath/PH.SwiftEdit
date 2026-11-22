import Foundation
import Testing
@testable import SwiftEditCore

/// In-memory growing file used to exercise rotation and truncation without disk I/O (`TEST-004`).
private final class FakeLogFile: LogFileReading, @unchecked Sendable {
    var bytes = Data()
    var identity: UInt64 = 1
    func append(_ s: String) { bytes.append(Data(s.utf8)) }
    func status(of url: URL) throws -> LogFileStatus { LogFileStatus(size: UInt64(bytes.count), identity: identity) }
    func read(_ url: URL, offset: UInt64, length: Int) throws -> Data {
        let start = Int(offset), end = min(bytes.count, start + length)
        return start < end ? bytes.subdata(in: start..<end) : Data()
    }
}

@Suite("LogSyntaxHighlighterTests")
struct LogSyntaxHighlighterTests {

    private static func kinds(_ line: String) -> [MarkdownSyntaxKind] {
        LogSyntaxHighlighter.spans(index: MarkdownLineIndex(text: line), visibleRange: TextRange(location: 0, length: (line as NSString).length)).map(\.kind)
    }

    @Test("P-LOG1: NLog, Serilog, log4net, JSON and syslog lines expose their level and timestamp", arguments: [
        ("2026-11-22 10:00:00.1234|ERROR|App.Orders|Payment failed", LogLevel.error),
        ("[10:00:01 INF] Request started", .info),
        ("2026-11-22 10:00:02,123 [12] WARN  Shop.Cart - low stock", .warn),
        (#"{"time":"2026-11-22T10:00:03Z","level":"debug","msg":"cache hit"}"#, .debug),
        ("Nov 22 10:00:04 host app[42]: crit: disk failure", .critical),
        ("2026-11-22T10:00:05.000+01:00 [trace] tick", .trace),
        ("FATAL 2026-11-22 boom", .critical),
    ])
    func pLevelsAndTimestamps(line: String, expected: LogLevel) {
        // GIVEN a line in a common logger layout
        // WHEN it is classified and tokenized
        let kinds = Self.kinds(line)
        // THEN the level is recognized and a timestamp token is present when the layout carries one
        #expect(LogSyntaxHighlighter.level(of: line) == expected)
        #expect(kinds.contains(.logLevel(expected)))
        #expect(kinds.contains(.logTimestamp) || line.hasPrefix("FATAL"))
    }

    @Test("P-LOG2: GUIDs, strings, exception names and stack frames are tokenized")
    func pGuidStringException() {
        // GIVEN an error line with a GUID, a quoted string and an exception, followed by a stack frame
        let line = #"ERROR 3f2504e0-4f89-11d3-9a0c-0305e82c3301 "order 7" System.InvalidOperationException: bad"#
        // WHEN both lines are tokenized
        // THEN each construct is classified
        #expect(Self.kinds(line).contains(.logGuid))
        #expect(Self.kinds(line).contains(.logString))
        #expect(Self.kinds(line).contains(.logException))
        #expect(Self.kinds("   at Shop.Orders.Pay() in Orders.cs:line 42") == [.logException])
    }

    @Test("N-LOG1: prose words, plural forms and overlong lines never produce level tokens")
    func nFalsePositivesAndBounds() {
        // GIVEN prose with lowercase level-like words, plurals and a 5000-unit line
        let prose = "an error occurred while the info desk was busy; ERRORS and INFORMATIONAL notes"
        let overlong = "ERROR " + String(repeating: "x", count: 5000)
        // WHEN they are classified
        // THEN no level is reported
        #expect(LogSyntaxHighlighter.level(of: prose) == nil)
        #expect(Self.kinds(overlong).isEmpty)
        #expect(Self.kinds("WARN then ERROR").filter { if case .logLevel = $0 { true } else { false } } == [.logLevel(.warn)])
    }
}

@Suite("LogTailTests")
struct LogTailTests {
    private static let url = URL(fileURLWithPath: "/tmp/fake.log")

    @Test("P-TAIL1: the buffer splits lines, strips CR, keeps partials and projects direct and inverse")
    func pBufferProjection() {
        // GIVEN a buffer fed in two chunks that split a line
        var buffer = LogTailBuffer()
        buffer.ingest(Data("a\r\nb\nc".utf8))
        buffer.ingest(Data("d\ne\n".utf8))
        // WHEN projected
        // THEN complete lines appear in both orders
        #expect(buffer.lines == ["a", "b", "cd", "e"])
        #expect(buffer.projected(count: 2, mode: .direct) == ["cd", "e"])
        #expect(buffer.projected(count: 3, mode: .inverse) == ["e", "cd", "b"])
    }

    @Test("N-TAIL1: a mid-line window drops its fragment and the buffer is capped")
    func nBufferBounds() {
        // GIVEN a window starting mid-line and 12,000 lines
        var buffer = LogTailBuffer()
        buffer.ingest(Data("ragment\nfull\n".utf8), startsMidLine: true)
        let first = buffer.lines
        buffer.ingest(Data((0..<12_000).map { "l\($0)\n" }.joined().utf8))
        // WHEN inspected
        // THEN the fragment is gone and only the newest 10,000 lines are kept
        #expect(first == ["full"])
        #expect(buffer.lines.count == LogTailBuffer.maxLines)
        #expect(buffer.lines.last == "l11999")
    }

    @Test("P-TAIL2: the session reads the initial tail, then only appended bytes")
    func pSessionAppend() throws {
        // GIVEN a log with 3 lines
        let file = FakeLogFile()
        file.append("one\ntwo\nthree\n")
        var session = LogTailSession(url: Self.url)
        try session.poll(using: file)
        // WHEN another writer appends two lines and the session polls twice
        file.append("four\nfive\n")
        let changed = try session.poll(using: file)
        let idle = try session.poll(using: file)
        // THEN the new lines appear exactly once and an idle poll reports no change
        #expect(changed)
        #expect(!idle)
        #expect(session.buffer.projected(count: 80, mode: .direct) == ["one", "two", "three", "four", "five"])
        #expect(session.buffer.projected(count: 2, mode: .inverse) == ["five", "four"])
    }

    @Test("N-TAIL2: truncation and rotation restart from the new file; huge growth jumps to the last window")
    func nSessionRotationTruncationGrowth() throws {
        // GIVEN a tailed file
        let file = FakeLogFile()
        file.append("old1\nold2\n")
        var session = LogTailSession(url: Self.url)
        try session.poll(using: file)
        // WHEN it is truncated, then rotated (new identity), then grows by more than the window
        file.bytes = Data("new1\n".utf8)
        try session.poll(using: file)
        let afterTruncate = session.buffer.lines
        file.identity = 2
        file.bytes = Data("rot1\nrot2\n".utf8)
        try session.poll(using: file)
        let afterRotate = session.buffer.lines
        file.append(String(repeating: "x", count: LogTailSession.maxWindowBytes) + "\nlast\n")
        try session.poll(using: file)
        // THEN each case restarts cleanly and the jump keeps only the newest window
        #expect(afterTruncate == ["new1"])
        #expect(afterRotate == ["rot1", "rot2"])
        #expect(session.restarts == 2)
        #expect(session.buffer.lines.last == "last")
        #expect(session.buffer.lines.count <= 2)
    }

    @Test("P-TAIL3: the local reader tails a real file while another handle keeps appending")
    func pLocalReaderConcurrentWriter() throws {
        // GIVEN a real temporary file held open for writing by another handle
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tail-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: url.path, contents: Data("a\n".utf8))
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try FileHandle(forWritingTo: url)
        defer { try? writer.close() }
        var session = LogTailSession(url: url)
        try session.poll(using: LocalLogFileReader())
        // WHEN the writer appends while the session polls
        try writer.seekToEnd()
        try writer.write(contentsOf: Data("b\nc\n".utf8))
        try session.poll(using: LocalLogFileReader())
        // THEN the appended lines are read without blocking the writer
        #expect(session.buffer.lines == ["a", "b", "c"])
    }
}
