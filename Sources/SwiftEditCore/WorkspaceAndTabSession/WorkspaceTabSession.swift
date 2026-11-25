import Foundation

/// Serializable Notepad++ tab descriptor referencing an open text document strictly by `DocumentID` and `BufferRevision` (`AR-004`, `BC-006`, `BC-008`).
public struct TabDescriptor: Equatable, Codable, Sendable {
    public let id: DocumentID
    /// Display name; every change re-resolves the cached `language` (open, rename, save-as).
    public var title: String { didSet { language = DocumentLanguage.resolve(filename: title) } }
    public var fileURL: URL?
    public var isPinned: Bool
    public var isDirty: Bool
    public var caretLocation: Int
    public var revision: BufferRevision
    /// Language resolved once from `title` and cached so render and keystroke paths never re-parse the extension (`PERF-C1`).
    public private(set) var language: DocumentLanguage

    public init(
        id: DocumentID,
        title: String,
        fileURL: URL? = nil,
        isPinned: Bool = false,
        isDirty: Bool = false,
        caretLocation: Int = 0,
        revision: BufferRevision = BufferRevision(1)
    ) {
        self.id = id
        self.title = title
        self.language = DocumentLanguage.resolve(filename: title)
        self.fileURL = fileURL
        self.isPinned = isPinned
        self.isDirty = isDirty
        self.caretLocation = caretLocation
        self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, fileURL, isPinned, isDirty, caretLocation, revision, language
    }

    public mutating func setDisplayTitlePreservingLanguage(_ newTitle: String) {
        let preserved = language
        title = newTitle
        language = preserved
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTitle = try c.decode(String.self, forKey: .title)
        self.init(
            id: try c.decode(DocumentID.self, forKey: .id),
            title: decodedTitle,
            fileURL: try c.decodeIfPresent(URL.self, forKey: .fileURL),
            isPinned: try c.decode(Bool.self, forKey: .isPinned),
            isDirty: try c.decode(Bool.self, forKey: .isDirty),
            caretLocation: try c.decode(Int.self, forKey: .caretLocation),
            revision: try c.decode(BufferRevision.self, forKey: .revision)
        )
        if let decodedLanguage = try c.decodeIfPresent(DocumentLanguage.self, forKey: .language) {
            self.language = decodedLanguage
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(fileURL, forKey: .fileURL)
        try c.encode(isPinned, forKey: .isPinned)
        try c.encode(isDirty, forKey: .isDirty)
        try c.encode(caretLocation, forKey: .caretLocation)
        try c.encode(revision, forKey: .revision)
        try c.encode(language, forKey: .language)
    }
}

/// Value-type Notepad++ tab bar state machine enforcing pinned-first tab ordering, pinned-tab close protection, and active-tab fallback (`AR-004`, `BC-006`, `BC-008`).
public struct WorkspaceTabSession: Equatable, Sendable {
    public private(set) var tabs: [TabDescriptor]
    public private(set) var activeTabID: DocumentID?

    public init(tabs: [TabDescriptor] = [], activeTabID: DocumentID? = nil) {
        self.tabs = Self.partitionPinnedFirst(tabs)
        if let activeTabID, self.tabs.contains(where: { $0.id == activeTabID }) {
            self.activeTabID = activeTabID
        } else {
            self.activeTabID = self.tabs.first?.id
        }
    }

    /// Opens a new text tab (appended after existing unpinned tabs) or activates and refreshes an already-open tab with the same `DocumentID`.
    ///
    /// Security invariant (`BC-008`, `DATA-003`, `SEC-011`, `SEC-012`):
    /// - Binary read-only inspection snapshots (`isBinaryReadOnly == true`) are strictly excluded from persistent tabs and pinning, throwing `DomainError.binaryFileSaveForbidden`.
    public mutating func openOrActivate(
        snapshot: DocumentSnapshot,
        title: String,
        fileURL: URL? = nil,
        isDirty: Bool = false,
        caretLocation: Int = 0
    ) throws {
        try Self.ensurePersistableTextSnapshot(snapshot)
        if let existingIndex = tabs.firstIndex(where: { $0.id == snapshot.id }) {
            tabs[existingIndex].title = title
            if let fileURL {
                tabs[existingIndex].fileURL = fileURL
            }
            tabs[existingIndex].isDirty = isDirty
            tabs[existingIndex].caretLocation = max(0, caretLocation)
            tabs[existingIndex].revision = snapshot.revision
            activeTabID = snapshot.id
            return
        }

        let newTab = TabDescriptor(
            id: snapshot.id,
            title: title,
            fileURL: fileURL,
            isPinned: false,
            isDirty: isDirty,
            caretLocation: max(0, caretLocation),
            revision: snapshot.revision
        )
        // Appending an unpinned tab preserves pinned-first invariant in O(1) without reallocating `tabs`.
        tabs.append(newTab)
        activeTabID = snapshot.id
    }

    /// Selects the tab matching `id` as the active tab.
    /// - Throws: `DomainError.tabNotFound` when `id` is not present in `tabs`.
    public mutating func activateTab(id: DocumentID) throws {
        guard tabs.contains(where: { $0.id == id }) else {
            throw DomainError.tabNotFound(id)
        }
        activeTabID = id
    }

    /// Pins or unpins the tab matching `id`, maintaining pinned-first relative ordering across `tabs`.
    /// - Throws: `DomainError.tabNotFound` when `id` is not present in `tabs`.
    public mutating func setPinned(_ isPinned: Bool, for id: DocumentID) throws {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            throw DomainError.tabNotFound(id)
        }
        guard tabs[index].isPinned != isPinned else { return }
        tabs[index].isPinned = isPinned
        tabs = Self.partitionPinnedFirst(tabs)
    }

    /// Reorders the tab matching `id` to `destinationIndex`, clamping strictly inside its pinned or unpinned partition (`BC-006`, `BC-008`).
    /// - Parameters:
    ///   - id: Identifier of the open tab to move.
    ///   - destinationIndex: Desired 0-based index in `tabs`; clamped to the tab's pinned or unpinned partition.
    /// - Throws: `DomainError.tabNotFound` when `id` is not present in `tabs`.
    public mutating func moveTab(id: DocumentID, toIndex destinationIndex: Int) throws {
        guard let sourceIndex = tabs.firstIndex(where: { $0.id == id }) else {
            throw DomainError.tabNotFound(id)
        }
        relocateTabAtIndices(fromIndex: sourceIndex, toIndex: destinationIndex)
    }

    /// Moves the tab matching `id` one slot left inside its pinned or unpinned partition (`BC-006`, `BC-008`).
    /// - Throws: `DomainError.tabNotFound` when `id` is not present in `tabs`.
    public mutating func moveTabLeft(id: DocumentID) throws {
        guard let sourceIndex = tabs.firstIndex(where: { $0.id == id }) else {
            throw DomainError.tabNotFound(id)
        }
        relocateTabAtIndices(fromIndex: sourceIndex, toIndex: sourceIndex - 1)
    }

    /// Moves the tab matching `id` one slot right inside its pinned or unpinned partition (`BC-006`, `BC-008`).
    /// - Throws: `DomainError.tabNotFound` when `id` is not present in `tabs`.
    public mutating func moveTabRight(id: DocumentID) throws {
        guard let sourceIndex = tabs.firstIndex(where: { $0.id == id }) else {
            throw DomainError.tabNotFound(id)
        }
        relocateTabAtIndices(fromIndex: sourceIndex, toIndex: sourceIndex + 1)
    }

    private mutating func relocateTabAtIndices(fromIndex sourceIndex: Int, toIndex destinationIndex: Int) {
        let range = partitionRange(forPinned: tabs[sourceIndex].isPinned)
        let clampedDestination = min(max(destinationIndex, range.lowerBound), range.upperBound)
        guard clampedDestination != sourceIndex else { return }
        let moved = tabs.remove(at: sourceIndex)
        tabs.insert(moved, at: clampedDestination)
    }

    private func partitionRange(forPinned isPinned: Bool) -> ClosedRange<Int> {
        let pinnedCount = tabs.prefix(while: \.isPinned).count
        if isPinned {
            return 0...max(0, pinnedCount - 1)
        }
        let lower = pinnedCount
        let upper = max(lower, tabs.count - 1)
        return lower...upper
    }

    /// Updates mutable metadata (`title`, `fileURL`, `isDirty`, `caretLocation`, `revision`) on an open tab.
    /// - Throws: `DomainError.tabNotFound` when `id` is not present in `tabs`.
    public mutating func updateTabState(
        id: DocumentID,
        title: String? = nil,
        fileURL: URL?? = nil,
        isDirty: Bool? = nil,
        caretLocation: Int? = nil,
        revision: BufferRevision? = nil
    ) throws {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            throw DomainError.tabNotFound(id)
        }
        if let title {
            tabs[index].title = title
        }
        if let fileURL {
            tabs[index].fileURL = fileURL
        }
        if let isDirty {
            tabs[index].isDirty = isDirty
        }
        if let caretLocation {
            tabs[index].caretLocation = max(0, caretLocation)
        }
        if let revision {
            tabs[index].revision = revision
        }
    }

    /// Updates only the display title of an unsaved (`fileURL == nil`) tab without altering its resolved `DocumentLanguage` (`BC-008`).
    public mutating func updateUntitledDisplayTitle(id: DocumentID, title: String) throws {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            throw DomainError.tabNotFound(id)
        }
        guard tabs[index].fileURL == nil else { return }
        tabs[index].setDisplayTitlePreservingLanguage(title)
    }

    /// Closes and returns the tab matching `id`, selecting the left neighbor (or first remaining tab) when the active tab closes.
    /// - Throws: `DomainError.tabNotFound` when `id` is absent, or `DomainError.pinnedTabCloseForbidden` when `isPinned == true` and `forcePinned == false`.
    @discardableResult
    public mutating func closeTab(id: DocumentID, forcePinned: Bool = false) throws -> TabDescriptor {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            throw DomainError.tabNotFound(id)
        }
        if tabs[index].isPinned && !forcePinned {
            throw DomainError.pinnedTabCloseForbidden(id)
        }
        let removed = tabs.remove(at: index)
        if activeTabID == id {
            activeTabID = resolveFallbackActiveTab(removedAt: index)
        }
        return removed
    }

    /// Reconciles open tabs in place after a sidebar file or folder rename, preserving `DocumentID`s (`BC-006`, `BC-008`).
    public mutating func applyRename(from oldURL: URL, to newURL: URL) {
        let oldPath = oldURL.standardizedFileURL.path
        let oldPrefix = oldPath.hasSuffix("/") ? oldPath : oldPath + "/"
        let newBaseURL = newURL.standardizedFileURL
        for index in tabs.indices {
            guard let currentURL = tabs[index].fileURL else { continue }
            let currentPath = currentURL.standardizedFileURL.path
            guard let match = Self.matchPathOrDescendant(candidatePath: currentPath, targetRootPath: oldPath, targetPrefix: oldPrefix) else {
                continue
            }
            if match.isExact {
                tabs[index].fileURL = newBaseURL
                tabs[index].title = newBaseURL.lastPathComponent
            } else {
                let rebased = newBaseURL.appendingPathComponent(match.relativeSubpath).standardizedFileURL
                tabs[index].fileURL = rebased
            }
        }
    }

    /// Reconciles open tabs after a sidebar item moves to Trash: closes clean matching tabs (including pinned) and detaches dirty tabs (`fileURL = nil`) so unsaved edits are never silently lost (`BC-008`, `DATA-006`).
    public mutating func applyTrash(of trashedURL: URL) {
        let trashedPath = trashedURL.standardizedFileURL.path
        let trashedPrefix = trashedPath.hasSuffix("/") ? trashedPath : trashedPath + "/"
        var kept: [TabDescriptor] = []
        kept.reserveCapacity(tabs.count)
        var removedActiveFallbackIndex: Int?

        for tab in tabs {
            guard let currentURL = tab.fileURL,
                  Self.matchPathOrDescendant(candidatePath: currentURL.standardizedFileURL.path, targetRootPath: trashedPath, targetPrefix: trashedPrefix) != nil else {
                kept.append(tab)
                continue
            }
            if tab.isDirty {
                var detached = tab
                detached.fileURL = nil
                kept.append(detached)
            } else if tab.id == activeTabID {
                removedActiveFallbackIndex = kept.count
            }
        }

        tabs = kept
        if let fallbackPos = removedActiveFallbackIndex {
            activeTabID = resolveFallbackActiveTab(removedAt: fallbackPos)
        }
    }

    private static func matchPathOrDescendant(
        candidatePath: String,
        targetRootPath: String,
        targetPrefix: String
    ) -> (isExact: Bool, relativeSubpath: String)? {
        if candidatePath == targetRootPath {
            return (true, "")
        }
        if candidatePath.hasPrefix(targetPrefix) {
            let relative = String(candidatePath.dropFirst(targetPrefix.count))
            return (false, relative)
        }
        return nil
    }

    private func resolveFallbackActiveTab(removedAt index: Int) -> DocumentID? {
        guard !tabs.isEmpty else { return nil }
        let fallbackIndex = index > 0 ? index - 1 : 0
        return tabs[min(fallbackIndex, tabs.count - 1)].id
    }

    private static func ensurePersistableTextSnapshot(_ snapshot: DocumentSnapshot) throws {
        if snapshot.isBinaryReadOnly {
            throw DomainError.binaryFileSaveForbidden
        }
    }

    private static func partitionPinnedFirst(_ source: [TabDescriptor]) -> [TabDescriptor] {
        let pinned = source.filter(\.isPinned)
        let unpinned = source.filter { !$0.isPinned }
        return pinned + unpinned
    }
}

public extension WorkspaceTabSession {
    /// Returns unpinned `DocumentID`s positioned strictly to the right of `id` in tab-bar order (`REQ-002`, `BC-006`, `BC-008`).
    func unpinnedTabIDsToTheRight(of id: DocumentID) -> [DocumentID] {
        guard let anchorIndex = tabs.firstIndex(where: { $0.id == id }),
              anchorIndex + 1 < tabs.count else {
            return []
        }
        return tabs[(anchorIndex + 1)...].filter { !$0.isPinned }.map(\.id)
    }

    /// Returns all unpinned `DocumentID`s except `id` when `id` is present in `tabs` (`REQ-002`, `BC-006`, `BC-008`).
    func unpinnedOtherTabIDs(keeping id: DocumentID) -> [DocumentID] {
        guard tabs.contains(where: { $0.id == id }) else { return [] }
        return tabs.filter { $0.id != id && !$0.isPinned }.map(\.id)
    }

    /// Returns all currently open unpinned `DocumentID`s in tab-bar order (`REQ-002`).
    func unpinnedTabIDs() -> [DocumentID] {
        tabs.filter { !$0.isPinned }.map(\.id)
    }

    /// Returns all currently open `DocumentID`s (pinned and unpinned) in tab-bar order (`REQ-002`).
    func allTabIDs() -> [DocumentID] {
        tabs.map(\.id)
    }

    /// Cycles `activeTabID` forward (`+1`) or backward (`-1`) modulo `tabs.count` (`REQ-002`).
    mutating func activateAdjacentTab(offset: Int) {
        guard !tabs.isEmpty else { return }
        let currentIndex = activeTabID.flatMap { active in tabs.firstIndex(where: { $0.id == active }) } ?? 0
        let count = tabs.count
        let nextIndex = ((currentIndex + offset) % count + count) % count
        activeTabID = tabs[nextIndex].id
    }

    /// Selects the 1-based tab index (`1..8` selects position `1..8` when in bounds; `9` selects the last tab, matching macOS tab bar conventions) (`REQ-002`).
    mutating func activateTabAtShortcutIndex(_ oneBasedIndex: Int) {
        guard (1...9).contains(oneBasedIndex), !tabs.isEmpty else { return }
        if oneBasedIndex == 9 {
            activeTabID = tabs.last?.id
            return
        }
        let targetIndex = oneBasedIndex - 1
        guard targetIndex < tabs.count else { return }
        activeTabID = tabs[targetIndex].id
    }
}
