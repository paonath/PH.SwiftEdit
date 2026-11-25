import Foundation
import Observation
import SwiftEditCore

/// Leaf `@MainActor @Observable` state controller for Quick Open (`Cmd+T`) and Find in Folder (`Ctrl+Shift+F`) (`REQ-007`).
@MainActor
@Observable
public final class WorkbenchQuickOpenController {
    public var isQuickOpenPresented: Bool = false
    public var quickOpenQuery: String = ""
    public var quickOpenSelectedIndex: Int = 0
    public var indexedFiles: [WorkspaceIndexedFile] = []
    public var candidates: [QuickOpenCandidate] = []

    public var isFolderSearchPresented: Bool = false
    public var folderSearchQuery: String = ""
    public var folderSearchCaseSensitive: Bool = false
    public var folderSearchWholeWord: Bool = false
    public var folderSearchResult = FolderSearchResult(matches: [], isTruncatedAtMatchCap: false, skippedExternalSymlinkCount: 0)

    public init() {}
}
