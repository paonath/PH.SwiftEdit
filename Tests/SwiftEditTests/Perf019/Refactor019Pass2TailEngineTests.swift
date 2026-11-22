import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("Refactor019Pass2TailEngineTests", .serialized)
@MainActor
struct Refactor019Pass2TailEngineTests {

    private static func buffer(_ lines: [String]) -> LogTailBuffer {
        var b = LogTailBuffer()
        b.ingest(Data((lines.joined(separator: "\n") + "\n").utf8))
        return b
    }

    @Test("N-R2a [bug]: a stale snapshot delivered after a newer one never overwrites it")
    func nOutOfOrderDeliveriesAreIgnored() {
        // GIVEN a running controller
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("order-\(UUID().uuidString).log")
        let controller = LogTailController(tabID: DocumentID(), url: url, mode: .direct)
        controller.start()
        defer { controller.stop() }
        // WHEN snapshot 3 arrives before the older snapshot 2
        controller.receive(.success(Self.buffer(["a", "b", "c"])), sequence: 3)
        controller.receive(.success(Self.buffer(["a", "b"])), sequence: 2)
        // THEN the newest content stays visible
        #expect(controller.text == "a\nb\nc")
    }

    @Test("N-R2b [bug]: file events are watched again once a missing or rotated log file reappears")
    func nVnodeRearmsAfterRecreation() throws {
        // GIVEN a worker started on a path that does not exist yet
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rearm-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: url) }
        let worker = LogTailWorker(url: url, reader: LocalLogFileReader()) { _, _ in }
        worker.start()
        defer { worker.stop() }
        _ = worker.pollNow()
        let watchingBefore = worker.isWatchingFileEvents
        // WHEN the file is created and the next poll runs
        FileManager.default.createFile(atPath: url.path, contents: Data("hello\n".utf8))
        let result = worker.pollNow()
        // THEN the kqueue watch is re-armed and the content is read
        #expect(!watchingBefore)
        #expect(worker.isWatchingFileEvents)
        #expect((try? result.get().lines) == ["hello"])
    }

    @Test("P-R2: in-order deliveries apply normally")
    func pInOrderDeliveries() {
        // GIVEN a running controller
        let controller = LogTailController(tabID: DocumentID(), url: URL(fileURLWithPath: "/tmp/x.log"), mode: .inverse)
        controller.start()
        defer { controller.stop() }
        // WHEN snapshots 1 and 2 arrive in order
        controller.receive(.success(Self.buffer(["a"])), sequence: 1)
        controller.receive(.success(Self.buffer(["a", "b"])), sequence: 2)
        // THEN the latest snapshot is shown newest first
        #expect(controller.text == "b\na")
    }
}
