import Foundation
import os
import SwiftEditCore

/// Bounded descriptor accounting snapshot for `LogTailWorker` rotation verification (`CWE-400`, `REQ-007`).
struct LogTailDescriptorMetrics: Equatable, Sendable {
    var openCount = 0
    var rotationDisarms = 0
}

/// Background engine of one live tail (`tail -F` semantics) (`REQ-LOG`, `UI-012`, `CWE-400`, `CWE-674`).
///
/// All file access runs on a private serial queue: a kqueue `DispatchSource` (`O_EVTONLY | O_CLOEXEC`, which never blocks
/// writers, renames, or deletions) wakes it on writes, and a 1 s timer covers rotation and file systems without vnode
/// events — the same strategy as macOS `tail -F`. Rotation/delete events disarm the active `vnode` non-recursively and
/// release `fd` via `setCancelHandler` so rapid rotations cannot recurse or leak descriptors (`CWE-400`, `CWE-674`).
final class LogTailWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "it.ph.SwiftEdit.logtail", qos: .utility)
    private let url: URL
    private let reader: any LogFileReading
    private var session: LogTailSession
    private var timer: DispatchSourceTimer?
    private var vnode: DispatchSourceFileSystemObject?
    private var running = false
    /// Monotonic delivery counter, so the main actor can discard snapshots that arrive out of order.
    private var sequence: UInt64 = 0
    private let metricsLock = OSAllocatedUnfairLock(initialState: LogTailDescriptorMetrics())
    private let deliver: @Sendable (Result<LogTailBuffer, Error>, UInt64) -> Void
    var isWatchingFileEvents: Bool { queue.sync { vnode != nil } }
    var descriptorMetrics: LogTailDescriptorMetrics {
        queue.sync {}
        return metricsLock.withLock { $0 }
    }

    init(url: URL, reader: any LogFileReading, deliver: @escaping @Sendable (Result<LogTailBuffer, Error>, UInt64) -> Void) {
        self.url = url
        self.reader = reader
        self.session = LogTailSession(url: url)
        self.deliver = deliver
    }

    deinit {
        timer?.cancel()
        vnode?.cancel()
    }

    func start() {
        queue.async { [weak self] in
            guard let self, !running else { return }
            running = true
            pollLocked(force: true)
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(200))
            timer.setEventHandler { [weak self] in self?.pollLocked(force: false) }
            timer.resume()
            self.timer = timer
            armVnodeLocked()
        }
    }

    func stop() {
        queue.sync {
            running = false
            timer?.cancel(); timer = nil
            vnode?.cancel(); vnode = nil
        }
        queue.sync {}
    }

    /// Synchronous poll returning the current buffer (tests and explicit refreshes); does not use `deliver`.
    func pollNow() -> Result<LogTailBuffer, Error> {
        queue.sync {
            if running, vnode == nil { armVnodeLocked() }
            do {
                try session.poll(using: reader)
                return .success(session.buffer)
            } catch {
                return .failure(error)
            }
        }
    }

    private func armVnodeLocked() {
        vnode?.cancel(); vnode = nil
        let fd = open(url.path, O_EVTONLY | O_CLOEXEC)
        guard fd >= 0 else { return }
        let lock = metricsLock
        lock.withLock { $0.openCount += 1 }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename, .attrib], queue: queue)
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            let events = source.data
            self.readAndDeliverSnapshotLocked(force: false)
            if events.contains(.delete) || events.contains(.rename) {
                // Disarm rotated/deleted descriptor without recursive re-entry; timer/pollNow re-arms on the new file (`REQ-007`, `CWE-400`).
                lock.withLock { $0.rotationDisarms += 1 }
                self.vnode?.cancel()
                self.vnode = nil
            }
        }
        source.setCancelHandler {
            close(fd)
            lock.withLock { $0.openCount = max(0, $0.openCount - 1) }
        }
        source.resume()
        vnode = source
    }

    private func pollLocked(force: Bool) {
        guard running else { return }
        // The log may not exist yet or may have been recreated after rotation: keep trying to watch its events.
        if vnode == nil { armVnodeLocked() }
        readAndDeliverSnapshotLocked(force: force)
    }

    /// Leaf snapshot reader shared by `pollLocked` and `armVnodeLocked` to maintain a strictly acyclic call graph (`REQ-007`).
    private func readAndDeliverSnapshotLocked(force: Bool) {
        guard running else { return }
        do {
            let changed = try session.poll(using: reader)
            if changed || force { sequence &+= 1; deliver(.success(session.buffer), sequence) }
        } catch {
            sequence &+= 1
            deliver(.failure(error), sequence)
        }
    }
}

/// Non-observable background worker and sequencing state owned by `LogTailController` (`REQ-LOG`, `REQ-002`).
private struct LogTailRuntimeState {
    var buffer = LogTailBuffer()
    var worker: LogTailWorker?
    let reader: any LogFileReading
    var lastSequence: UInt64 = 0
    var sessionToken: UInt64 = 0
}

/// Main-actor state of the Log function for one tab: mode, line count, live text and errors (`REQ-LOG`).
@MainActor
@Observable
public final class LogTailController {
    public static let defaultLineCount = 80
    public let tabID: DocumentID
    public let url: URL
    /// Identity of the read-only tail view (distinct from the document so the editor never mixes undo stacks).
    public let viewID = DocumentID()
    public private(set) var mode: LogTailMode
    public private(set) var lineCount: Int
    public private(set) var isRunning = false
    public private(set) var text = ""
    public private(set) var visibleLineCount = 0
    public private(set) var errorMessage: String?
    /// Monotonic change counter used as the tail view's `BufferRevision`.
    public private(set) var generation: UInt64 = 1
    @ObservationIgnored nonisolated(unsafe) fileprivate var runtime: LogTailRuntimeState

    public init(tabID: DocumentID, url: URL, mode: LogTailMode, lineCount: Int = LogTailController.defaultLineCount, reader: any LogFileReading = LocalLogFileReader()) {
        self.tabID = tabID
        self.url = url
        self.mode = mode
        self.lineCount = Self.clamp(lineCount)
        self.runtime = LogTailRuntimeState(reader: reader)
    }

    deinit {
        runtime.worker?.stop()
    }
}

extension LogTailController {
    static func clamp(_ count: Int) -> Int { min(max(1, count), LogTailBuffer.maxLines) }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        runtime.sessionToken &+= 1
        let activeToken = runtime.sessionToken
        runtime.lastSequence = 0
        errorMessage = nil
        let worker = LogTailWorker(url: url, reader: runtime.reader) { [weak self] result, sequence in
            Task { @MainActor in self?.receive(result, sequence: sequence, sessionToken: activeToken) }
        }
        runtime.worker = worker
        worker.start()
    }

    /// Stops listening; the last snapshot stays visible until the panel is closed.
    public func stop() {
        runtime.sessionToken &+= 1
        runtime.worker?.stop()
        runtime.worker = nil
        isRunning = false
    }

    public func setMode(_ newMode: LogTailMode) {
        guard mode != newMode else { return }
        mode = newMode
        reproject()
    }

    public func setLineCount(_ count: Int) {
        let clamped = Self.clamp(count)
        guard clamped != lineCount else { return }
        lineCount = clamped
        reproject()
    }

    /// Performs one synchronous poll and applies it immediately (tests and the panel's refresh).
    func pollNow() {
        guard let worker = runtime.worker else { return }
        apply(worker.pollNow())
    }

    /// Applies a worker delivery unless it belongs to a superseded session or a newer sequence was already applied.
    func receive(_ result: Result<LogTailBuffer, Error>, sequence: UInt64, sessionToken: UInt64? = nil) {
        if let sessionToken, sessionToken != runtime.sessionToken { return }
        guard sequence > runtime.lastSequence else { return }
        runtime.lastSequence = sequence
        apply(result)
    }

    private func apply(_ result: Result<LogTailBuffer, Error>) {
        guard isRunning else { return }
        switch result {
        case .success(let snapshot):
            runtime.buffer = snapshot
            errorMessage = nil
            reproject()
        case .failure(let error):
            errorMessage = "Log tail paused: \(error)"
        }
    }

    private func reproject() {
        let projected = runtime.buffer.textAndCount(count: lineCount, mode: mode)
        guard projected.text != text || projected.lineCount != visibleLineCount else { return }
        text = projected.text
        visibleLineCount = projected.lineCount
        generation &+= 1
    }
}
