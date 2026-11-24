import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

extension SwiftEditWorkbenchModel {
    public internal(set) var sidebarWidthRatio: Double {
        get { workspaceState.sidebarWidthRatio }
        set { workspaceState.sidebarWidthRatio = newValue }
    }
    public var isLeftSidebarCollapsed: Bool {
        get { workspaceState.isLeftSidebarCollapsed }
        set { workspaceState.isLeftSidebarCollapsed = newValue }
    }
    public internal(set) var selectedFolderURL: URL? {
        get { workspaceState.selectedFolderURL }
        set { workspaceState.selectedFolderURL = newValue }
    }
    public internal(set) var selectedSidebarEntryURL: URL? {
        get { workspaceState.selectedSidebarEntryURL }
        set { workspaceState.selectedSidebarEntryURL = newValue }
    }
    public internal(set) var grantedScopeRootURL: URL? {
        get { workspaceState.grantedScopeRootURL }
        set { workspaceState.grantedScopeRootURL = newValue }
    }
    public internal(set) var folderEntries: [FolderEntryDescriptor] {
        get { workspaceState.folderEntries }
        set { workspaceState.folderEntries = newValue }
    }
    public internal(set) var recentFiles: [RecentFileEntry] {
        get { workspaceState.recentFiles }
        set { workspaceState.recentFiles = newValue }
    }
    public internal(set) var pendingBatchOpenPlan: BatchOpenPlan? {
        get { workspaceState.pendingBatchOpenPlan }
        set { workspaceState.pendingBatchOpenPlan = newValue }
    }
    public internal(set) var pendingBatchFolderURL: URL? {
        get { workspaceState.pendingBatchFolderURL }
        set { workspaceState.pendingBatchFolderURL = newValue }
    }
    public internal(set) var activeBinaryInspection: BinaryInspectionPresentation? {
        get { workspaceState.activeBinaryInspection }
        set { workspaceState.activeBinaryInspection = newValue }
    }

    public var sidebarClipboard: SidebarFileClipboard? {
        get { sidebarFileController.clipboard }
        set { sidebarFileController.clipboard = newValue }
    }

    public var pendingTrashItemURL: URL? {
        get { sidebarFileController.pendingTrashItemURL }
        set { sidebarFileController.pendingTrashItemURL = newValue }
    }

    /// Ascends one folder level (`...`) in the left sidebar when permitted by workspace scope or user directory read permissions (`UI-001`, `DATA-007`, `SEC-002`).
    public func navigateToParentFolder() {
        guard let currentFolder = selectedFolderURL else { return }
        do {
            guard let resolution = try deps.navigator.resolveParentDirectory(
                from: currentFolder,
                withinScope: grantedScopeRootURL,
                isParentReadable: deps.parentPermissionChecker
            ) else {
                statusBannerMessage = "Cannot navigate to parent folder: root reached or user permission not granted."
                return
            }
            grantedScopeRootURL = resolution.updatedScopeRootURL
            selectedFolderURL = resolution.parentURL
            refreshFolderEntries()
        } catch {
            statusBannerMessage = "Parent folder navigation blocked: \(error)"
        }
    }

    public func selectWorkspaceFolder(_ folderURL: URL) {
        let canonical = folderURL.standardizedFileURL
        selectedFolderURL = canonical
        grantedScopeRootURL = canonical
        isLeftSidebarCollapsed = false
        refreshFolderEntries()
    }

    /// Opens a dropped or externally handed-off folder in the left Folder Navigator and expands the sidebar.
    public func openDroppedFolder(_ folderURL: URL) {
        let standardized = folderURL.standardizedFileURL
        isLeftSidebarCollapsed = false
        selectWorkspaceFolder(standardized)
        statusBannerMessage = "Opened folder \(standardized.lastPathComponent)."
    }

    /// Handles files and/or folders dragged onto the window or the macOS Dock/Finder icon.
    public func openDroppedURLs(_ urls: [URL]) {
        var directories: [URL] = []
        var files: [URL] = []
        for rawURL in urls where rawURL.isFileURL {
            let standardized = rawURL.standardizedFileURL
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDir), isDir.boolValue {
                directories.append(standardized)
            } else {
                files.append(standardized)
            }
        }
        for folder in directories {
            openDroppedFolder(folder)
        }
        for file in files {
            openFile(at: file, withinScope: file.deletingLastPathComponent())
        }
    }

    public func openFolderViaPanel() {
        guard let folderURL = deps.openPanelProvider(true, "Grant Workspace Folder") else { return }
        selectWorkspaceFolder(folderURL)
    }

    public func openFileViaPanel() {
        guard let fileURL = deps.openPanelProvider(false, nil) else { return }
        openFile(at: fileURL, withinScope: fileURL.deletingLastPathComponent())
    }

    public func openFolderEntry(_ entry: FolderEntryDescriptor) {
        if entry.isDirectory {
            selectedFolderURL = entry.url.standardizedFileURL
            selectedSidebarEntryURL = nil
            if grantedScopeRootURL == nil {
                grantedScopeRootURL = selectedFolderURL
            }
            refreshFolderEntries()
            return
        }
        guard !entry.isBinary else {
            return
        }
        openFile(at: entry.url, withinScope: grantedScopeRootURL ?? selectedFolderURL)
    }

    /// Finder-style single click in the left sidebar: selects folders without navigating into them, and opens eligible non-binary files (`UI-001`).
    public func sidebarPrimaryClick(_ entry: FolderEntryDescriptor) {
        selectedSidebarEntryURL = entry.url.standardizedFileURL
        guard !entry.isDirectory else { return }
        openFolderEntry(entry)
    }

    /// Finder-style double click in the left sidebar: enters folders and opens eligible non-binary files (`UI-001`).
    public func sidebarDoubleClick(_ entry: FolderEntryDescriptor) {
        if entry.isDirectory {
            openFolderEntry(entry)
            return
        }
        selectedSidebarEntryURL = entry.url.standardizedFileURL
        openFolderEntry(entry)
    }

    /// Copies the standardized filesystem path of any sidebar file (including binary) or folder to the system pasteboard (`UI-001`).
    public func sidebarCopyPathToClipboard(at url: URL) {
        deps.clipboardWriter(url.standardizedFileURL.path)
        statusBannerMessage = "Copied path to clipboard."
    }
}

extension SwiftEditWorkbenchModel {
    public func openFile(at url: URL, withinScope scope: URL?) {
        caches.asyncOpenGeneration &+= 1
        let standardizedURL = url.standardizedFileURL
        if activateExistingOrBinaryIfPresent(at: standardizedURL, withinScope: scope) {
            return
        }
        do {
            let loaded = try deps.loader.load(from: standardizedURL, withinScope: scope)
            try completeOpenLoadedSession(loaded, at: standardizedURL, withinScope: scope)
        } catch DomainError.fileTooLarge(let byteCount) where DocumentLanguage.resolve(filename: standardizedURL.lastPathComponent) == .log {
            openLogTailOnly(at: standardizedURL, byteCount: byteCount)
        } catch {
            statusBannerMessage = "Open failed: \(error)"
        }
    }

    /// Asynchronously opens `url` within `scope`, enforcing `64 MiB` fail-fast size checks before any payload read, offloading `>= 2 MiB` decoding off `@MainActor`, and discarding superseded completions if another tab opens or activates mid-flight (`PERF-004`, `CWE-400`, `REQ-004/N7`).
    public func openFileAsync(at url: URL, withinScope scope: URL?) async {
        caches.asyncOpenGeneration &+= 1
        let expectedGeneration = caches.asyncOpenGeneration
        let standardizedURL = url.standardizedFileURL
        if activateExistingOrBinaryIfPresent(at: standardizedURL, withinScope: scope) {
            return
        }
        do {
            let attrs = try deps.fileSystem.fileAttributes(at: standardizedURL, withinScope: scope)
            if attrs.byteSize > DocumentLoader.maxAllowedFileBytes {
                throw DomainError.fileTooLarge(byteCount: attrs.byteSize)
            }
            let loaded: DocumentSession
            if attrs.byteSize >= Self.asyncFileLoadThresholdBytes {
                let loaderCopy = deps.loader
                loaded = try await Task.detached(priority: .userInitiated) {
                    try loaderCopy.load(from: standardizedURL, withinScope: scope)
                }.value
                guard caches.asyncOpenGeneration == expectedGeneration, !Task.isCancelled else {
                    return
                }
            } else {
                loaded = try deps.loader.load(from: standardizedURL, withinScope: scope)
            }
            try completeOpenLoadedSession(loaded, at: standardizedURL, withinScope: scope)
        } catch DomainError.fileTooLarge(let byteCount) where DocumentLanguage.resolve(filename: standardizedURL.lastPathComponent) == .log {
            if caches.asyncOpenGeneration == expectedGeneration { openLogTailOnly(at: standardizedURL, byteCount: byteCount) }
        } catch {
            if caches.asyncOpenGeneration == expectedGeneration {
                statusBannerMessage = "Open failed: \(error)"
            }
        }
    }

    func activateExistingOrBinaryIfPresent(at standardizedURL: URL, withinScope scope: URL?) -> Bool {
        if let existingBinary = activeBinaryInspection, existingBinary.fileURL == standardizedURL {
            statusBannerMessage = "Binary file opened in transient read-only inspection mode (Save, Format, Pin & SessionRecovery disabled)."
            safetyBanner = InspectionSafetyBannerState.evaluate(snapshot: existingBinary.snapshot)
            return true
        }
        if let existingTab = tabSession.tabs.first(where: { $0.fileURL?.standardizedFileURL == standardizedURL }) {
            activateTab(id: existingTab.id)
            recordRecentFileIfEligible(url: standardizedURL, withinScope: scope)
            return true
        }
        return false
    }

    func completeOpenLoadedSession(_ loaded: DocumentSession, at standardizedURL: URL, withinScope scope: URL?) throws {
        if loaded.isBinaryReadOnly {
            activeBinaryInspection = BinaryInspectionPresentation(
                id: loaded.id,
                title: standardizedURL.lastPathComponent,
                fileURL: standardizedURL,
                snapshot: loaded.snapshot
            )
            currentSelection = SwiftEditCore.TextRange(location: 0, length: 0)
            programmaticSelectionToken += 1
            showMarkdownPreview = false
            caches.previewCache = nil
            PreviewThumbnailCache.shared.clear()
            isDiagnosticsPopoverPresented = false
            statusBannerMessage = "Binary file opened in transient read-only inspection mode (Save, Format, Pin & SessionRecovery disabled)."
            refreshDiagnosticsForActiveDocument()
            return
        }
        activeBinaryInspection = nil
        sessionsByID[loaded.id] = loaded
        savedBaselineByID[loaded.id] = loaded.snapshot
        try tabSession.openOrActivate(
            snapshot: loaded.snapshot,
            title: standardizedURL.lastPathComponent,
            fileURL: standardizedURL,
            isDirty: false
        )
        recordRecentFileIfEligible(url: standardizedURL, withinScope: scope)
        statusBannerMessage = nil
        persistRecoveryState()
        refreshDiagnosticsForActiveDocument()
    }

    public func openRecentFile(_ entry: RecentFileEntry) {
        do {
            let resolvedURL = try deps.recentFilesStore.resolve(entry: entry)
            recentFiles = deps.recentFilesStore.entries()
            openFile(at: resolvedURL, withinScope: resolvedURL.deletingLastPathComponent())
        } catch {
            recentFiles = deps.recentFilesStore.entries()
            statusBannerMessage = "Recent file unavailable: \(error)"
        }
    }

    public func clearRecentFiles() {
        deps.recentFilesStore.clear()
        recentFiles = []
    }

    public func toggleLeftSidebar() {
        isLeftSidebarCollapsed.toggle()
    }

    /// Creates a new folder inside `parentURL` (or `selectedFolderURL`) within the active workspace scope (`BC-012`, `SEC-003`).
    @discardableResult
    public func sidebarCreateFolder(named name: String, in parentURL: URL? = nil) -> URL? {
        guard let targetParent = parentURL ?? selectedFolderURL else { return nil }
        let scope = grantedScopeRootURL ?? targetParent
        do {
            let created = try deps.fileSystem.createDirectory(named: name, in: targetParent, withinScope: scope)
            refreshFolderEntries()
            return created
        } catch {
            statusBannerMessage = "Create folder failed: \(error)"
            return nil
        }
    }

    /// Creates a new empty UTF-8 file inside `parentURL` (or `selectedFolderURL`) within the active workspace scope (`BC-012`, `SEC-003`).
    @discardableResult
    public func sidebarCreateFile(named name: String, in parentURL: URL? = nil) -> URL? {
        guard let targetParent = parentURL ?? selectedFolderURL else { return nil }
        let scope = grantedScopeRootURL ?? targetParent
        do {
            let created = try deps.fileSystem.createFile(named: name, contents: Data(), in: targetParent, withinScope: scope)
            refreshFolderEntries()
            return created
        } catch {
            statusBannerMessage = "Create file failed: \(error)"
            return nil
        }
    }
}

extension SwiftEditWorkbenchModel {
    /// Renames `itemURL` to single-segment `newName` inside workspace scope and reconciles open tabs (`BC-006`, `BC-008`, `SEC-003`).
    @discardableResult
    public func sidebarRenameItem(at itemURL: URL, to newName: String) -> URL? {
        let scope = grantedScopeRootURL ?? selectedFolderURL
        do {
            let oldStandardized = itemURL.standardizedFileURL
            let renamed = try deps.fileSystem.renameItem(at: oldStandardized, toName: newName, withinScope: scope)
            tabSession.applyRename(from: oldStandardized, to: renamed)
            reconcileSessionURLsAfterRename(from: oldStandardized, to: renamed)
            persistRecoveryState()
            refreshFolderEntries()
            return renamed
        } catch {
            statusBannerMessage = "Rename failed: \(error)"
            return nil
        }
    }

    /// Stages `itemURL` on the sidebar clipboard in `.cut` mode.
    public func sidebarCutItem(at itemURL: URL) {
        sidebarClipboard = SidebarFileClipboard(sourceURL: itemURL, mode: .cut)
    }

    /// Stages `itemURL` on the sidebar clipboard in `.copy` mode.
    public func sidebarCopyItem(at itemURL: URL) {
        sidebarClipboard = SidebarFileClipboard(sourceURL: itemURL, mode: .copy)
    }

    /// Pastes the staged `sidebarClipboard` item into `destinationFolderURL` (or `selectedFolderURL`) (`BC-012`, `SEC-003`).
    @discardableResult
    public func sidebarPasteItem(into destinationFolderURL: URL? = nil) -> URL? {
        guard let clip = sidebarClipboard,
              let destDir = destinationFolderURL ?? selectedFolderURL else { return nil }
        let scope = grantedScopeRootURL ?? destDir
        do {
            let pasted = try deps.fileSystem.pasteItem(
                from: clip.sourceURL,
                toDirectory: destDir,
                mode: clip.mode,
                withinScope: scope
            )
            if clip.mode == .cut {
                tabSession.applyRename(from: clip.sourceURL, to: pasted)
                reconcileSessionURLsAfterRename(from: clip.sourceURL, to: pasted)
                sidebarClipboard = nil
                persistRecoveryState()
            }
            refreshFolderEntries()
            return pasted
        } catch {
            statusBannerMessage = "Paste failed: \(error)"
            return nil
        }
    }

    /// Stages `itemURL` for user-confirmed movement to the system Trash (`CWE-73`, `SEC-012`).
    public func requestSidebarTrashItem(at itemURL: URL) {
        pendingTrashItemURL = itemURL.standardizedFileURL
    }

    /// Moves `pendingTrashItemURL` to the system Trash via `FileSystemProviding.trashItem` and reconciles open tabs (`BC-008`, `DATA-006`).
    public func confirmPendingTrashItem() {
        guard let itemURL = pendingTrashItemURL else { return }
        pendingTrashItemURL = nil
        let scope = grantedScopeRootURL ?? selectedFolderURL
        do {
            try deps.fileSystem.trashItem(at: itemURL, withinScope: scope)
            let beforeTabIDs = Set(tabSession.tabs.map(\.id))
            tabSession.applyTrash(of: itemURL)
            let remainingTabIDs = Set(tabSession.tabs.map(\.id))
            for closedID in beforeTabIDs.subtracting(remainingTabIDs) {
                sessionsByID.removeValue(forKey: closedID)
                savedBaselineByID.removeValue(forKey: closedID)
                try? deps.recoveryStore.removeRecoverySnapshot(for: closedID)
            }
            for tab in tabSession.tabs where tab.fileURL == nil {
                if let existing = sessionsByID[tab.id] {
                    sessionsByID[tab.id] = DocumentSession(
                        id: existing.id,
                        fileURL: nil,
                        revision: existing.revision,
                        text: existing.text,
                        encoding: existing.encoding,
                        lineEnding: existing.lineEnding,
                        isDirty: existing.isDirty,
                        isDegradedPlainText: existing.isDegradedPlainText,
                        isBinaryReadOnly: existing.isBinaryReadOnly
                    )
                }
            }
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
            refreshFolderEntries()
        } catch {
            statusBannerMessage = "Move to Trash failed: \(error)"
        }
    }

    /// Cancels a pending sidebar Trash confirmation without mutating disk.
    public func cancelPendingTrashItem() {
        pendingTrashItemURL = nil
    }

    /// Opens a log above the size gate as a read-only live tail without creating a horizontal hop to `+TerminalLogAndUpdates` (`REQ-009`).
    func openLogTailOnly(at url: URL, byteCount: UInt64) {
        let session = DocumentSession(fileURL: url, text: "")
        do {
            try tabSession.openOrActivate(snapshot: session.snapshot, title: url.lastPathComponent, fileURL: url, isDirty: false)
        } catch {
            statusBannerMessage = "Open failed: \(error)"
            return
        }
        activeBinaryInspection = nil
        showMarkdownPreview = false
        caches.previewCache = nil
        overlayState.isDiagnosticsPopoverPresented = false
        sessionsByID[session.id] = session
        savedBaselineByID[session.id] = session.snapshot
        logTailOnlyTabIDs.insert(session.id)
        refreshDiagnosticsForActiveDocument()
        let mb = Double(byteCount) / 1_048_576
        statusBannerMessage = String(format: "Log too large to edit (%.0f MB): showing a live tail of the last lines.", mb)
        let controller = LogTailController(tabID: session.id, url: url, mode: .direct, reader: logFileReader)
        logTails[session.id] = controller
        controller.start()
    }

    /// Reveals `itemURL` in macOS Finder within the active workspace scope (`SEC-004`).
    public func sidebarRevealInFinder(at itemURL: URL) {
        do {
            try deps.desktopWorkspace.revealInFinder(itemURL: itemURL, withinScope: grantedScopeRootURL ?? selectedFolderURL)
        } catch {
            statusBannerMessage = "Reveal in Finder blocked: \(error)"
        }
    }

    /// Opens `folderURL` in macOS Finder within the active workspace scope (`SEC-004`).
    public func sidebarOpenFolderInFinder(at folderURL: URL) {
        do {
            try deps.desktopWorkspace.openFolderInFinder(folderURL: folderURL, withinScope: grantedScopeRootURL ?? selectedFolderURL)
        } catch {
            statusBannerMessage = "Open Folder in Finder blocked: \(error)"
        }
    }

    /// Opens the configured allowlisted terminal (`iTerm2` / Settings choice / `Terminal.app`) at `targetURL` (or its parent directory when `targetURL` is a file) (`SEC-004`).
    public func sidebarOpenInTerminal(at targetURL: URL) {
        let explicitID: String?
        if let selectedID = preferredTerminalBundleID,
           deps.installedTerminalBundleIDsProvider().contains(selectedID) {
            explicitID = selectedID
        } else {
            explicitID = nil
        }
        do {
            _ = try deps.desktopWorkspace.openInTerminal(
                targetURL: targetURL,
                withinScope: grantedScopeRootURL ?? selectedFolderURL,
                explicitBundleIdentifier: explicitID
            )
        } catch {
            statusBannerMessage = "Open Terminal blocked: \(error)"
        }
    }

    func reconcileSessionURLsAfterRename(from oldURL: URL, to newURL: URL) {
        for tab in tabSession.tabs {
            if let existing = sessionsByID[tab.id], existing.fileURL != tab.fileURL {
                sessionsByID[tab.id] = DocumentSession(
                    id: existing.id,
                    fileURL: tab.fileURL,
                    revision: existing.revision,
                    text: existing.text,
                    encoding: existing.encoding,
                    lineEnding: existing.lineEnding,
                    isDirty: existing.isDirty,
                    isDegradedPlainText: existing.isDegradedPlainText,
                    isBinaryReadOnly: existing.isBinaryReadOnly
                )
            }
        }
        _ = (oldURL, newURL)
    }
}

extension SwiftEditWorkbenchModel {
    /// Presents `NSOpenPanel` for `Open All Files in Folder` (`Cmd+Shift+Option+O`).
    public func openAllFilesInFolderViaPanel() {
        guard let folderURL = deps.openPanelProvider(true, "Open All Files in Folder") else { return }
        openAllFilesInFolder(folderURL)
    }

    /// Evaluates `ShallowFolderBatchLoader.plan` for `folderURL`, expanding the sidebar and gating batches above `50` files behind explicit confirmation (`BC-011`).
    public func openAllFilesInFolder(_ folderURL: URL) {
        let canonical = folderURL.standardizedFileURL
        do {
            let plan = try deps.batchLoader.plan(folder: canonical, withinScope: canonical)
            selectWorkspaceFolder(canonical)
            if plan.requiresConfirmation {
                pendingBatchOpenPlan = plan
                pendingBatchFolderURL = canonical
                return
            }
            openBatchPlan(plan, withinScope: canonical)
        } catch {
            statusBannerMessage = "Batch open aborted: \(error)"
        }
    }

    /// Opens all eligible text files from a user-confirmed `> 50`-file `BatchOpenPlan`.
    public func confirmPendingBatchOpen() {
        guard let plan = pendingBatchOpenPlan,
              let folderURL = pendingBatchFolderURL else { return }
        pendingBatchOpenPlan = nil
        pendingBatchFolderURL = nil
        openBatchPlan(plan, withinScope: folderURL)
    }

    /// Discards a pending `> 50`-file `BatchOpenPlan` without opening tabs.
    public func cancelPendingBatchOpen() {
        pendingBatchOpenPlan = nil
        pendingBatchFolderURL = nil
    }

    func openBatchPlan(_ plan: BatchOpenPlan, withinScope scopeURL: URL) {
        for fileURL in plan.files {
            openFile(at: fileURL, withinScope: scopeURL)
        }
    }
}

#endif
