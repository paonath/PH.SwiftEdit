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
        guard !data.isEmpty else { return }
        data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            let count = bytes.count
            guard let base = bytes.baseAddress, count > 0 else { return }
            var cursor = 0
            if startsMidLine {
                guard let hit = memchr(base, 0x0A, count) else { return }
                let foundNL = UnsafePointer(hit.assumingMemoryBound(to: UInt8.self)) - base
                cursor = foundNL + 1
                partial.removeAll(keepingCapacity: true)
            }

            // Collect newline positions in the remaining slice using SIMD-accelerated `memchr` so that if a single
            // chunk carries more than `maxLines` lines (e.g. initial 8 MiB tail window), we only decode the
            // trailing `maxLines` lines instead of allocating and immediately discarding the rest.
            var newlineOffsets: [Int] = []
            newlineOffsets.reserveCapacity(min(Self.maxLines + 1, max(16, (count - cursor) / 64)))
            var scan = cursor
            while scan < count {
                guard let hit = memchr(base + scan, 0x0A, count - scan) else { break }
                let nlPos = UnsafePointer(hit.assumingMemoryBound(to: UInt8.self)) - base
                newlineOffsets.append(nlPos)
                scan = nlPos + 1
            }

            if !newlineOffsets.isEmpty {
                let firstNewlineIndex: Int
                if newlineOffsets.count > Self.maxLines {
                    firstNewlineIndex = newlineOffsets.count - Self.maxLines
                    // Everything before `newlineOffsets[firstNewlineIndex - 1]` is dropped; partial is superseded.
                    lines.removeAll(keepingCapacity: true)
                    partial.removeAll(keepingCapacity: true)
                    cursor = newlineOffsets[firstNewlineIndex - 1] + 1
                } else {
                    firstNewlineIndex = 0
                }

                let decodedCount = newlineOffsets.count - firstNewlineIndex
                if lines.count + decodedCount > Self.maxLines {
                    let drop = lines.count + decodedCount - Self.maxLines
                    if drop >= lines.count {
                        lines.removeAll(keepingCapacity: true)
                    } else {
                        lines.removeFirst(drop)
                    }
                }
                lines.reserveCapacity(min(Self.maxLines, lines.count + decodedCount))

                var segStart = cursor
                for nlIdx in firstNewlineIndex..<newlineOffsets.count {
                    let nlPos = newlineOffsets[nlIdx]
                    if partial.isEmpty {
                        var segEnd = nlPos
                        if segEnd > segStart && bytes[segEnd - 1] == 0x0D {
                            segEnd -= 1
                        }
                        if segEnd == segStart {
                            lines.append("")
                        } else {
                            let slice = UnsafeBufferPointer(rebasing: bytes[segStart..<segEnd])
                            lines.append(String(decoding: slice, as: UTF8.self))
                        }
                    } else {
                        var segEnd = nlPos
                        if segEnd > segStart && bytes[segEnd - 1] == 0x0D {
                            segEnd -= 1
                            if segEnd > segStart {
                                partial.append(contentsOf: bytes[segStart..<segEnd])
                            }
                        } else if segEnd > segStart {
                            partial.append(contentsOf: bytes[segStart..<segEnd])
                        } else if partial.last == 0x0D {
                            partial.removeLast()
                        }
                        lines.append(String(decoding: partial, as: UTF8.self))
                        partial.removeAll(keepingCapacity: true)
                    }
                    segStart = nlPos + 1
                }
                cursor = segStart
            }

            if cursor < count {
                let remaining = count - cursor
                let cap = 1 << 20
                if remaining >= cap {
                    partial.removeAll(keepingCapacity: true)
                    partial.append(contentsOf: bytes[(count - cap)..<count])
                } else {
                    partial.append(contentsOf: bytes[cursor..<count])
                    if partial.count > cap {
                        partial.removeFirst(partial.count - cap)
                    }
                }
            }
        }
    }

    /// The last `count` complete lines in `mode` order.
    public func projected(count: Int, mode: LogTailMode) -> [String] {
        let clamped = max(0, min(count, Self.maxLines))
        let slice = lines.suffix(clamped)
        return mode == .direct ? Array(slice) : Array(slice.reversed())
    }

    /// Joins the last `count` complete lines in `mode` order without allocating an intermediate `[String]`.
    public func textAndCount(count: Int, mode: LogTailMode) -> (text: String, lineCount: Int) {
        let clamped = max(0, min(count, Self.maxLines))
        let slice = lines.suffix(clamped)
        let joined = mode == .direct ? slice.joined(separator: "\n") : slice.reversed().joined(separator: "\n")
        return (joined, slice.count)
    }

    public func text(count: Int, mode: LogTailMode) -> String {
        textAndCount(count: count, mode: mode).text
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
        guard length > 0 else { return Data() }
        let fd = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw DomainError.ioFailure("Cannot open log file (errno \(errno))") }
        defer { close(fd) }
        var data = Data(count: length)
        var totalRead = 0
        try data.withUnsafeMutableBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            while totalRead < length {
                let n = pread(fd, base.advanced(by: totalRead), length - totalRead, off_t(offset) + off_t(totalRead))
                if n > 0 {
                    totalRead += n
                } else if n == 0 {
                    break
                } else if errno == EINTR {
                    continue
                } else {
                    throw DomainError.ioFailure("Cannot read log file (errno \(errno))")
                }
            }
        }
        if totalRead < length {
            data.removeSubrange(totalRead..<length)
        }
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
