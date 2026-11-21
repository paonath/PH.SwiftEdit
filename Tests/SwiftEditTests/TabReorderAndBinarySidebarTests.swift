import Foundation
import Testing
@testable import SwiftEditCore

@Suite("TabReorderAndBinarySidebarTests")
struct TabReorderAndBinarySidebarTests {

    @Test("P3: WorkspaceTabSession moveTabLeft, moveTabRight, and moveTab reorder within pinned and unpinned partitions preserving activeTabID")
    func p3TabReorderingWithinPartitionsPreservesActiveTab() throws {
        // GIVEN pinned tabs [P1, P2] and unpinned tabs [U1, U2, U3] with active tab U3
        let p1 = DocumentSession(text: "p1").snapshot
        let p2 = DocumentSession(text: "p2").snapshot
        let u1 = DocumentSession(text: "u1").snapshot
        let u2 = DocumentSession(text: "u2").snapshot
        let u3 = DocumentSession(text: "u3").snapshot

        var session = WorkspaceTabSession()
        try session.openOrActivate(snapshot: p1, title: "P1.md")
        try session.openOrActivate(snapshot: p2, title: "P2.md")
        try session.setPinned(true, for: p1.id)
        try session.setPinned(true, for: p2.id)
        try session.openOrActivate(snapshot: u1, title: "U1.md")
        try session.openOrActivate(snapshot: u2, title: "U2.md")
        try session.openOrActivate(snapshot: u3, title: "U3.md")

        // WHEN moving U3 left, P1 right, and U1 to the end of unpinned tabs
        try session.moveTabLeft(id: u3.id)
        try session.moveTabRight(id: p1.id)
        let afterAdjacentMoves = session.tabs.map(\.id)
        try session.moveTab(id: u1.id, toIndex: 4)

        // THEN partitions reorder accurately while activeTabID stays U3
        #expect(afterAdjacentMoves == [p2.id, p1.id, u1.id, u3.id, u2.id])
        #expect(session.tabs.map(\.id) == [p2.id, p1.id, u3.id, u2.id, u1.id])
        #expect(session.activeTabID == u3.id)
    }

    @Test("N5: Cross-partition tab moves clamp inside their own partition and unknown DocumentID throws tabNotFound")
    func n5CrossPartitionClampingAndUnknownTabThrows() throws {
        // GIVEN pinned [P1] and unpinned [U1, U2] plus an unknown DocumentID
        let p1 = DocumentSession(text: "p1").snapshot
        let u1 = DocumentSession(text: "u1").snapshot
        let u2 = DocumentSession(text: "u2").snapshot
        let unknownID = DocumentID()

        var session = WorkspaceTabSession()
        try session.openOrActivate(snapshot: p1, title: "P1.md")
        try session.setPinned(true, for: p1.id)
        try session.openOrActivate(snapshot: u1, title: "U1.md")
        try session.openOrActivate(snapshot: u2, title: "U2.md")

        // WHEN attempting to move P1 right across partition boundary, U1 left across boundary, or moving an unknown tab
        try session.moveTabRight(id: p1.id)
        try session.moveTab(id: p1.id, toIndex: 2)
        try session.moveTabLeft(id: u1.id)
        try session.moveTab(id: u2.id, toIndex: 0)

        // THEN pinned-first order is preserved and unknown ID throws DomainError.tabNotFound
        #expect(session.tabs.map(\.id) == [p1.id, u2.id, u1.id])
        #expect(throws: DomainError.tabNotFound(unknownID)) {
            try session.moveTabLeft(id: unknownID)
        }
    }

    @Test("P4: DotfileFolderNavigator flags NUL-bearing binary files as isBinary while keeping text files and directories false with balanced scope")
    func p4ShallowListingDetectsBinaryFilesWithBalancedScope() throws {
        // GIVEN a granted workspace containing a folder, a UTF-8 text file, and a NUL-bearing binary file
        let workspace = try NavigatorTestSandbox.makeWorkspace(label: "binary-p4")
        defer { try? FileManager.default.removeItem(at: workspace) }
        try FileManager.default.createDirectory(at: workspace.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try Data("# Hello".utf8).write(to: workspace.appendingPathComponent("notes.md"))
        try Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x0D, 0x0A]).write(to: workspace.appendingPathComponent("archive.bin"))

        let scopeFake = RecordingSecurityScopeFake()
        let navigator = DotfileFolderNavigator(securityScope: scopeFake)

        // WHEN enumerating shallow entries
        let entries = try navigator.listEntries(in: workspace, withinScope: workspace)

        // THEN archive.bin is marked binary, docs and notes.md are non-binary, and scope counts balance
        #expect(entries.map(\.name) == ["docs", "archive.bin", "notes.md"])
        #expect(entries.map(\.isBinary) == [false, true, false])
        #expect(scopeFake.startCount == 1)
        #expect(scopeFake.stopCount == 1)
    }

    @Test("N6 [Security]: Escaping symlink in folder listing aborts with securityScopeViolation before binary probing with balanced scope")
    func n6SecurityEscapingSymlinkRejectedBeforeBinaryProbe() throws {
        // GIVEN a granted workspace containing a symlink pointing to an external binary file
        let workspace = try NavigatorTestSandbox.makeWorkspace(label: "binary-n6-ws")
        let outside = try NavigatorTestSandbox.makeWorkspace(label: "binary-n6-out")
        defer {
            try? FileManager.default.removeItem(at: workspace)
            try? FileManager.default.removeItem(at: outside)
        }
        let externalBinary = outside.appendingPathComponent("secret.bin")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: externalBinary)
        let escapingLink = workspace.appendingPathComponent("escape.bin")
        try FileManager.default.createSymbolicLink(at: escapingLink, withDestinationURL: externalBinary)

        let scopeFake = RecordingSecurityScopeFake()
        let navigator = DotfileFolderNavigator(securityScope: scopeFake)

        // WHEN listing entries
        #expect(throws: DomainError.securityScopeViolation(path: escapingLink.standardizedFileURL.path)) {
            _ = try navigator.listEntries(in: workspace, withinScope: workspace)
        }

        // THEN security scope release is guaranteed even on throw
        #expect(scopeFake.startCount == 1)
        #expect(scopeFake.stopCount == 1)
    }
}
