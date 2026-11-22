import Foundation

/// Tail presentation order: `direct` keeps file order (newest at the bottom), `inverse` shows the newest line first.
public enum LogTailMode: String, Codable, Sendable, CaseIterable {
    case direct, inverse
}

/// Bounded line buffer fed with raw bytes from the end of a log file (`REQ-LOG`, `CWE-400`).
///
/// Keeps at most `maxLines` complete lines (newest last) plus one pending partial line, so memory stays bounded however
/// large the file or however fast it grows; decoding is lossy UTF-8 and trailing `\r` is stripped (CRLF logs).
public struct LogTailBuffer: Sendable, Equatable {
    public static let maxLines = 10_000
    public private(set) var lines: [String] = []
    private var partial: [UInt8] = []

    public init() {}

    public mutating func reset() {
        lines.removeAll(keepingCapacity: true)
        partial.removeAll()
    }

    /// Appends `data`. When `startsMidLine` is `true` (a window that does not begin at a line start), the leading
    /// fragment up to the first newline is discarded.
    public mutating func ingest(_ data: Data, startsMidLine: Bool = false) {
        var bytes = [UInt8](data)
        if startsMidLine {
            guard let nl = bytes.firstIndex(of: 0x0A) else { return }
            bytes.removeSubrange(0...nl)
            partial.removeAll()
        }
        var segmentStart = 0
        var newLines: [String] = []
        for (i, b) in bytes.enumerated() where b == 0x0A {
            var lineBytes = partial + bytes[segmentStart..<i]
            partial.removeAll()
            if lineBytes.last == 0x0D { lineBytes.removeLast() }
            newLines.append(String(decoding: lineBytes, as: UTF8.self))
            segmentStart = i + 1
        }
        partial += bytes[segmentStart...]
        if partial.count > 1 << 20 { // a pathological single line: keep the last 1 MiB only
            partial.removeFirst(partial.count - (1 << 20))
        }
        lines += newLines
        if lines.count > Self.maxLines { lines.removeFirst(lines.count - Self.maxLines) }
    }

    /// The last `count` complete lines in `mode` order.
    public func projected(count: Int, mode: LogTailMode) -> [String] {
        let tail = Array(lines.suffix(max(0, min(count, Self.maxLines))))
        return mode == .direct ? tail : tail.reversed()
    }

    public func text(count: Int, mode: LogTailMode) -> String {
        projected(count: count, mode: mode).joined(separator: "\n")
    }
}

/// File identity and size used to detect growth, truncation and rotation.
public struct LogFileStatus: Equatable, Sendable {
    public let size: UInt64
    /// Device + inode: changes when the file is rotated (moved away and recreated).
    public let identity: UInt64
    public init(size: UInt64, identity: UInt64) {
        self.size = size
        self.identity = identity
    }
}

/// Read-only, lock-free access to a growing file (`AR-007`): writers are never blocked (no `flock`, positional reads).
public protocol LogFileReading: Sendable {
    func status(of url: URL) throws -> LogFileStatus
    func read(_ url: URL, offset: UInt64, length: Int) throws -> Data
}

/// Production reader using `open(O_RDONLY)` + `fstat` + `pread`, closing the descriptor after every call so the app
/// never holds the file open between polls (rotation and deletion by the writer always succeed).
public struct LocalLogFileReader: LogFileReading {
    public init() {}

    public func status(of url: URL) throws -> LogFileStatus {
        var info = stat()
        guard stat(url.path, &info) == 0 else { throw DomainError.ioFailure("Cannot stat log file (errno \(errno))") }
        guard (info.st_mode & S_IFMT) == S_IFREG else { throw DomainError.ioFailure("Not a regular file") }
        return LogFileStatus(size: UInt64(info.st_size), identity: (UInt64(UInt32(bitPattern: info.st_dev)) << 32) ^ UInt64(info.st_ino))
    }

    public func read(_ url: URL, offset: UInt64, length: Int) throws -> Data {
        let fd = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw DomainError.ioFailure("Cannot open log file (errno \(errno))") }
        defer { close(fd) }
        var data = Data(count: length)
        let read = data.withUnsafeMutableBytes { pread(fd, $0.baseAddress, length, off_t(offset)) }
        guard read >= 0 else { throw DomainError.ioFailure("Cannot read log file (errno \(errno))") }
        data.removeSubrange(read..<length)
        return data
    }
}

/// `tail -F`-like state machine: initial window from the end, then incremental reads of appended bytes, restarting
/// from the end on truncation or rotation (`tail -F` semantics). Each step reads at most `maxWindowBytes`.
public struct LogTailSession: Sendable {
    public static let maxWindowBytes = 8 * 1024 * 1024
    public let url: URL
    public private(set) var buffer = LogTailBuffer()
    public private(set) var offset: UInt64 = 0
    private var identity: UInt64?
    /// Number of truncation/rotation restarts observed (diagnostics and tests).
    public private(set) var restarts = 0

    public init(url: URL) {
        self.url = url
    }

    /// Reads whatever changed since the last poll. Returns `true` when the buffer changed.
    @discardableResult
    public mutating func poll(using reader: any LogFileReading) throws -> Bool {
        let status = try reader.status(of: url)
        if let identity, identity != status.identity || status.size < offset {
            restarts += 1
            buffer.reset()
            self.identity = nil
        }
        if self.identity == nil {
            self.identity = status.identity
            let start = status.size > UInt64(Self.maxWindowBytes) ? status.size - UInt64(Self.maxWindowBytes) : 0
            offset = start
            let data = try reader.read(url, offset: start, length: Int(status.size - start))
            buffer.ingest(data, startsMidLine: start > 0)
            offset = start + UInt64(data.count)
            return true
        }
        guard status.size > offset else { return false }
        var start = offset
        var midLine = false
        if status.size - offset > UInt64(Self.maxWindowBytes) {
            start = status.size - UInt64(Self.maxWindowBytes)
            buffer.reset()
            midLine = true
        }
        let data = try reader.read(url, offset: start, length: Int(status.size - start))
        buffer.ingest(data, startsMidLine: midLine)
        offset = start + UInt64(data.count)
        return !data.isEmpty
    }
}
