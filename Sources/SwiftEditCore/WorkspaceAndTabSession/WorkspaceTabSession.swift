import Foundation

/// Serializable Notepad++ tab descriptor referencing an open text document strictly by `DocumentID` and `BufferRevision` (`AR-004`, `BC-006`, `BC-008`).
public struct TabDescriptor: Equatable, Codable, Sendable {
    public let id: DocumentID
    public var title: String
    public var fileURL: URL?
    public var isPinned: Bool
    public var isDirty: Bool
    public var caretLocation: Int
    public var revision: BufferRevision

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
        self.fileURL = fileURL
        self.isPinned = isPinned
        self.isDirty = isDirty
        self.caretLocation = caretLocation
        self.revision = revision
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
        tabs.append(newTab)
        tabs = Self.partitionPinnedFirst(tabs)
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
        tabs[index].isPinned = isPinned
        tabs = Self.partitionPinnedFirst(tabs)
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
