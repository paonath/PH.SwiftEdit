import Foundation
import Testing
@testable import SwiftEditCore

private final class BatchScopeCounterFake: SecurityScopedResourceAccessing, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var startCount = 0
    private(set) var stopCount = 0

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

@Suite("ShallowFolderBatchLoaderTests")
struct ShallowFolderBatchLoaderTests {

    private static func makeScratchFolder(label: String) throws -> URL {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".tmp/test-results/\(label)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func seedFiftyTwoTextThreeBinaryTwoFolders(in root: URL) throws {
        let fm = FileManager.default
        for idx in 1...52 {
            let name = String(format: "file-%02d.txt", idx)
            try Data("line \(idx)\n".utf8).write(to: root.appendingPathComponent(name))
        }
        for idx in 1...3 {
            try Data([0x00, 0x01, UInt8(idx)]).write(to: root.appendingPathComponent("bin-\(idx).dat"))
        }
        try fm.createDirectory(at: root.appendingPathComponent("subA"), withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: root.appendingPathComponent("subA/nested.txt"))
        try fm.createDirectory(at: root.appendingPathComponent("subB"), withIntermediateDirectories: true)
    }

    @Test("P6: 52 shallow text files require confirmation while 3 binary files and 2 subfolders are skipped")
    func p6FiftyTwoTextFilesRequireConfirmationWhileSkippingBinariesAndSubfolders() throws {
        // GIVEN a granted workspace folder with 52 text files, 3 binary files, and 2 subdirectories
        let root = try Self.makeScratchFolder(label: "batch-p6")
        defer { try? FileManager.default.removeItem(at: root) }
        try Self.seedFiftyTwoTextThreeBinaryTwoFolders(in: root)
        let loader = ShallowFolderBatchLoader()

        // WHEN planning the shallow batch open
        let plan = try loader.plan(folder: root, withinScope: root)

        // THEN exactly the 52 shallow text files are selected, binaries and folders are skipped, and confirmation is required
        #expect(plan.files.count == 52)
        #expect(plan.skippedBinaryCount == 3)
        #expect(plan.skippedFolderCount == 2)
        #expect(plan.requiresConfirmation == true)
        #expect(plan.totalBytes > 0)
    }

    @Test("N6: Folder containing only binary files and subfolders produces an empty non-confirming plan without error")
    func n6FolderWithOnlyBinariesAndSubfoldersReturnsEmptyPlan() throws {
        // GIVEN a granted folder containing 2 binary files and 1 subdirectory
        let root = try Self.makeScratchFolder(label: "batch-n6")
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([0x7F, 0x45, 0x4C, 0x46, 0x00]).write(to: root.appendingPathComponent("a.bin"))
        try Data([0x00, 0xFF]).write(to: root.appendingPathComponent("b.bin"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
        let loader = ShallowFolderBatchLoader()

        // WHEN planning the shallow batch open
        let plan = try loader.plan(folder: root, withinScope: root)

        // THEN zero files are selected, counts match skipped items, and requiresConfirmation is false
        #expect(plan.files.isEmpty)
        #expect(plan.skippedBinaryCount == 2)
        #expect(plan.skippedFolderCount == 1)
        #expect(plan.requiresConfirmation == false)
    }

    @Test("P7 & N7 [Security]: Batch at exact ceiling succeeds with balanced scope, while escaping symlink or +1 byte overflow aborts")
    func p7AndN7SecurityCeilingBoundaryAndEscapingSymlinkAbort() throws {
        // GIVEN an exact 1024-byte folder, an escaping-symlink folder, and a 1025-byte folder
        let scratch = try Self.makeScratchFolder(label: "batch-sec")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let exactDir = scratch.appendingPathComponent("exact")
        let escapeDir = scratch.appendingPathComponent("escape")
        let overflowDir = scratch.appendingPathComponent("overflow")
        let outsideFile = scratch.appendingPathComponent("secret.txt")
        try FileManager.default.createDirectory(at: exactDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: escapeDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: overflowDir, withIntermediateDirectories: true)
        try Data("secret".utf8).write(to: outsideFile)
        try Data(repeating: 0x61, count: 512).write(to: exactDir.appendingPathComponent("a.txt"))
        try Data(repeating: 0x62, count: 512).write(to: exactDir.appendingPathComponent("b.txt"))
        try FileManager.default.createSymbolicLink(
            at: escapeDir.appendingPathComponent("leak.txt"),
            withDestinationURL: outsideFile
        )
        try Data(repeating: 0x61, count: 1025).write(to: overflowDir.appendingPathComponent("big.txt"))
        let scopeCounter = BatchScopeCounterFake()
        let loader = ShallowFolderBatchLoader(
            navigator: DotfileFolderNavigator(securityScope: scopeCounter),
            maxBatchBytes: 1024
        )

        // WHEN planning the exact-ceiling folder, the escaping-symlink folder, and the 1025-byte folder
        let exactPlan = try loader.plan(folder: exactDir, withinScope: exactDir)

        // THEN exact 1024-byte batch succeeds, escaping symlink throws securityScopeViolation, overflow throws batchLimitExceeded, and scope counts balance
        #expect(exactPlan.files.count == 2)
        #expect(exactPlan.totalBytes == 1024)
        #expect(throws: DomainError.securityScopeViolation(path: escapeDir.appendingPathComponent("leak.txt").path)) {
            _ = try loader.plan(folder: escapeDir, withinScope: escapeDir)
        }
        #expect(throws: DomainError.batchLimitExceeded(maxBytes: 1024)) {
            _ = try loader.plan(folder: overflowDir, withinScope: overflowDir)
        }
        #expect(scopeCounter.startCount == scopeCounter.stopCount)
    }
}
