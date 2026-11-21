import Foundation
import Testing
@testable import SwiftEditCore

@Suite("TabSessionFileSyncTests")
struct TabSessionFileSyncTests {

    @Test("P12: applyRename updates direct and descendant folder tabs in place while applyTrash closes clean trashed tabs")
    func p12RenameUpdatesTabsInPlaceAndTrashClosesCleanTabs() throws {
        // GIVEN open clean tabs for /w/draft.md, /w/src/a.md, and pinned /w/old.md
        var tabs = WorkspaceTabSession()
        let docDraft = DocumentSession(text: "draft").snapshot
        let docSub = DocumentSession(text: "sub").snapshot
        let docOld = DocumentSession(text: "old").snapshot
        try tabs.openOrActivate(snapshot: docDraft, title: "draft.md", fileURL: URL(fileURLWithPath: "/w/draft.md"))
        try tabs.openOrActivate(snapshot: docSub, title: "a.md", fileURL: URL(fileURLWithPath: "/w/src/a.md"))
        try tabs.openOrActivate(snapshot: docOld, title: "old.md", fileURL: URL(fileURLWithPath: "/w/old.md"))
        try tabs.setPinned(true, for: docOld.id)

        // WHEN renaming /w/draft.md -> /w/final.md, renaming /w/src -> /w/lib, and trashing /w/old.md
        tabs.applyRename(from: URL(fileURLWithPath: "/w/draft.md"), to: URL(fileURLWithPath: "/w/final.md"))
        tabs.applyRename(from: URL(fileURLWithPath: "/w/src"), to: URL(fileURLWithPath: "/w/lib"))
        tabs.applyTrash(of: URL(fileURLWithPath: "/w/old.md"))

        // THEN renamed tabs preserve DocumentIDs with updated titles/URLs and the clean trashed tab is closed
        #expect(tabs.tabs.count == 2)
        let updatedDraft = try #require(tabs.tabs.first { $0.id == docDraft.id })
        let updatedSub = try #require(tabs.tabs.first { $0.id == docSub.id })
        #expect(updatedDraft.title == "final.md")
        #expect(updatedDraft.fileURL?.standardizedFileURL.path == "/w/final.md")
        #expect(updatedSub.title == "a.md")
        #expect(updatedSub.fileURL?.standardizedFileURL.path == "/w/lib/a.md")
    }

    @Test("N15: applyTrash detaches dirty tabs without closing them and leaves prefix-sibling paths untouched")
    func n15DirtyTrashedTabDetachesAndPrefixSiblingRemainsUntouched() throws {
        // GIVEN a dirty tab for /w/draft.md and a clean tab for /w/draft.md.bak
        var tabs = WorkspaceTabSession()
        let docDirty = DocumentSession(text: "unsaved").snapshot
        let docBak = DocumentSession(text: "backup").snapshot
        try tabs.openOrActivate(snapshot: docDirty, title: "draft.md", fileURL: URL(fileURLWithPath: "/w/draft.md"), isDirty: true)
        try tabs.openOrActivate(snapshot: docBak, title: "draft.md.bak", fileURL: URL(fileURLWithPath: "/w/draft.md.bak"), isDirty: false)

        // WHEN trashing /w/draft.md
        tabs.applyTrash(of: URL(fileURLWithPath: "/w/draft.md"))

        // THEN dirty tab stays open with fileURL == nil and isDirty == true, and /w/draft.md.bak is unchanged
        #expect(tabs.tabs.count == 2)
        let detachedDirty = try #require(tabs.tabs.first { $0.id == docDirty.id })
        let siblingBak = try #require(tabs.tabs.first { $0.id == docBak.id })
        #expect(detachedDirty.fileURL == nil)
        #expect(detachedDirty.isDirty == true)
        #expect(siblingBak.fileURL?.standardizedFileURL.path == "/w/draft.md.bak")
    }
}
