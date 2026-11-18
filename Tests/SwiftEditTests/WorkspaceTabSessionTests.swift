import Foundation
import Testing
@testable import SwiftEditCore

@Suite("WorkspaceTabSessionTests")
struct WorkspaceTabSessionTests {

    @Test("P1: openOrActivate, setPinned, updateTabState, and closeTab maintain Notepad++ pinned-first ordering and active tab tracking")
    func p1OpeningPinningUpdatingAndClosingTextTabs() throws {
        // GIVEN an empty WorkspaceTabSession and three text snapshots
        var workspace = WorkspaceTabSession()
        let docA = DocumentSession(text: "alpha").snapshot
        let docB = DocumentSession(text: "beta").snapshot
        let docC = DocumentSession(text: "gamma").snapshot

        // WHEN opening docA..docC, pinning docC, updating docC caret/revision, and closing unpinned docA
        try workspace.openOrActivate(snapshot: docA, title: "Alpha.md", fileURL: URL(fileURLWithPath: "/ws/Alpha.md"))
        try workspace.openOrActivate(snapshot: docB, title: "Beta.md")
        try workspace.openOrActivate(snapshot: docC, title: "Gamma.md")
        try workspace.setPinned(true, for: docC.id)
        try workspace.updateTabState(id: docC.id, isDirty: true, caretLocation: 12, revision: BufferRevision(4))
        try workspace.activateTab(id: docA.id)
        let closedTab = try workspace.closeTab(id: docA.id)

        // THEN docC stays ordered first as pinned with updated caret/revision, docA is removed, and activeTabID falls back deterministically
        #expect(closedTab.id == docA.id)
        #expect(workspace.tabs.map(\.id) == [docC.id, docB.id])
        #expect(workspace.tabs.first?.isPinned == true)
        #expect(workspace.tabs.first?.isDirty == true)
        #expect(workspace.tabs.first?.caretLocation == 12)
        #expect(workspace.tabs.first?.revision == BufferRevision(4))
        #expect(workspace.activeTabID == docC.id)
    }

    @Test("N1: Closing a pinned tab without unpinning throws pinnedTabCloseForbidden and unknown DocumentIDs throw tabNotFound without mutating state")
    func n1ClosingPinnedTabOrTargetingUnknownTabFailsClosed() throws {
        // GIVEN a WorkspaceTabSession with pinned docA and unpinned docB
        var workspace = WorkspaceTabSession()
        let docA = DocumentSession(text: "pinned").snapshot
        let docB = DocumentSession(text: "unpinned").snapshot
        let unknownID = DocumentID()
        try workspace.openOrActivate(snapshot: docA, title: "Pinned.md")
        try workspace.setPinned(true, for: docA.id)
        try workspace.openOrActivate(snapshot: docB, title: "Notes.md")
        let snapshotBeforeErrors = workspace

        // WHEN / THEN closing pinned docA without force or targeting unknownID throws typed DomainErrors without mutating state
        #expect(throws: DomainError.pinnedTabCloseForbidden(docA.id)) {
            _ = try workspace.closeTab(id: docA.id)
        }
        #expect(throws: DomainError.tabNotFound(unknownID)) {
            try workspace.activateTab(id: unknownID)
        }
        #expect(throws: DomainError.tabNotFound(unknownID)) {
            try workspace.setPinned(true, for: unknownID)
        }
        #expect(workspace == snapshotBeforeErrors)
    }

    @Test("N2 [Security]: openOrActivate rejects binary read-only snapshots from persistent tabs and pinning")
    func n2SecurityBinarySnapshotRejectedFromTabsAndPinning() {
        // GIVEN an empty WorkspaceTabSession and a binary read-only DocumentSnapshot
        var workspace = WorkspaceTabSession()
        let binarySnapshot = DocumentSession(text: "PNG", isBinaryReadOnly: true).snapshot

        // WHEN / THEN attempting to register the binary snapshot in persistent tabs throws binaryFileSaveForbidden
        #expect(throws: DomainError.binaryFileSaveForbidden) {
            try workspace.openOrActivate(snapshot: binarySnapshot, title: "logo.png")
        }
        #expect(workspace.tabs.isEmpty)
        #expect(workspace.activeTabID == nil)
    }
}
