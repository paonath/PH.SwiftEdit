import Foundation
import Testing
@testable import SwiftEditCore

enum TempSandboxFactory {
    static func makeSandboxPair(name: String) throws -> (root: URL, scope: URL, outside: URL) {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let root = repoRoot.appendingPathComponent(".tmp/test-results/sec-\(name)-\(UUID().uuidString)")
        let scope = root.appendingPathComponent("granted-workspace")
        let outside = root.appendingPathComponent("outside-zone")
        try FileManager.default.createDirectory(at: scope, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        return (root, scope, outside)
    }
}

@Suite("DocumentSecurityQuarantineTests")
struct DocumentSecurityQuarantineTests {

    @Test("N3 [Security]: Binary file containing 0x00 within first 8 KiB opens read-only, caps preview at 1 MiB, and blocks save with binaryFileSaveForbidden")
    func n3BinaryFileWithNulByteIsQuarantinedAndSaveBlocked() throws {
        // GIVEN a 2 MiB binary payload containing a 0x00 byte in its Mach-O/PNG-like header
        let fs = InMemoryFileSystemFake()
        let loader = DocumentLoader(fileSystem: fs)
        let binaryURL = URL(fileURLWithPath: "/workspace/disguised.md")
        var payload = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x0D, 0x0A, 0x1A])
        payload.append(Data(repeating: 0x41, count: 2 * 1024 * 1024))
        fs.seed(url: binaryURL, data: payload)

        // WHEN loading the file for inspection
        let session = try loader.load(from: binaryURL)

        // THEN the session is read-only binary, excluded from pinning and recovery, capped at 1 MiB, and rejects save
        #expect(session.isBinaryReadOnly == true)
        #expect(session.isPinnable == false)
        #expect(session.isEligibleForSessionRecovery == false)
        #expect(session.text.utf8.count <= 1_048_576)
        #expect(throws: DomainError.binaryFileSaveForbidden) {
            _ = try loader.save(session, to: binaryURL)
        }
    }

    @Test("N4 [Security]: Symlink escaping granted workspace scope fails closed with DomainError.securityScopeViolation on load and save")
    func n4SymlinkEscapingWorkspaceScopeThrowsSecurityScopeViolation() throws {
        // GIVEN a granted workspace directory containing a symlink pointing to an outside secret file
        let sandbox = try TempSandboxFactory.makeSandboxPair(name: "n4-symlink")
        defer { try? FileManager.default.removeItem(at: sandbox.root) }
        let outsideSecretURL = sandbox.outside.appendingPathComponent("secret.env")
        try Data("TOKEN=REDACTED".utf8).write(to: outsideSecretURL)
        let symlinkInsideScope = sandbox.scope.appendingPathComponent("escape.md")
        try FileManager.default.createSymbolicLink(at: symlinkInsideScope, withDestinationURL: outsideSecretURL)
        let loader = DocumentLoader(fileSystem: LocalFileSystemAdapter())
        let cleanSession = DocumentSession(fileURL: symlinkInsideScope, text: "overwrite attempt")

        // WHEN / THEN both load and save reject the symlink escape with DomainError.securityScopeViolation
        #expect(throws: DomainError.securityScopeViolation(path: symlinkInsideScope.path)) {
            _ = try loader.load(from: symlinkInsideScope, withinScope: sandbox.scope)
        }
        #expect(throws: DomainError.securityScopeViolation(path: symlinkInsideScope.path)) {
            _ = try loader.save(cleanSession, to: symlinkInsideScope, withinScope: sandbox.scope)
        }
    }
}
