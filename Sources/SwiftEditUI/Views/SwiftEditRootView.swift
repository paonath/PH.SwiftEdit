import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

private extension RGBAColorToken {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

/// `@MainActor` TextKit 2 `NSTextView` wrapper enforcing `#FFFFFF`/`#000000` inverted canvas colors, `50%..300%` monospaced zoom, and read-only binary protection (`UI-002..008`, `UI-012`).
@MainActor
struct TextKit2EditorView: NSViewRepresentable {
    let text: String
    let isEditable: Bool
    let backgroundColor: NSColor
    let textColor: NSColor
    let fontSizePoints: Double
    let onTextChange: (String) -> Void
    let onSelectionChange: (SwiftEditCore.TextRange) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextChange: onTextChange, onSelectionChange: onSelectionChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let textView = NSTextView(usingTextLayoutManager: true)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        applyStyling(to: textView)
        textView.string = text
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.onTextChange = onTextChange
        context.coordinator.onSelectionChange = onSelectionChange

        applyStyling(to: textView)
        if textView.string != text {
            let previousSelection = textView.selectedRange()
            context.coordinator.isApplyingProgrammaticUpdate = true
            textView.string = text
            let clampedLocation = min(previousSelection.location, (text as NSString).length)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
            context.coordinator.isApplyingProgrammaticUpdate = false
        }
    }

    private func applyStyling(to textView: NSTextView) {
        textView.isEditable = isEditable
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSizePoints, weight: .regular)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var onTextChange: (String) -> Void
        var onSelectionChange: (SwiftEditCore.TextRange) -> Void
        var isApplyingProgrammaticUpdate = false

        init(
            onTextChange: @escaping (String) -> Void,
            onSelectionChange: @escaping (SwiftEditCore.TextRange) -> Void
        ) {
            self.onTextChange = onTextChange
            self.onSelectionChange = onSelectionChange
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingProgrammaticUpdate,
                  let textView = notification.object as? NSTextView else { return }
            onTextChange(textView.string)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingProgrammaticUpdate,
                  let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            onSelectionChange(SwiftEditCore.TextRange(location: range.location, length: range.length))
        }
    }
}

/// `@MainActor @Observable` application controller wiring `SwiftEditCore` engines and `SessionRecoveryStore` to the Zed-minimal Purple SwiftUI shell (`UI-001..012`).
@MainActor
@Observable
public final class SwiftEditWorkbenchModel {
    public var appearanceMode: AppearanceMode {
        didSet {
            palette = PurpleThemePalette.resolve(appearance: appearanceMode, systemPrefersDark: true)
            preferencesStore.save(EditorPreferences(appearanceMode: appearanceMode, zoomPercent: zoomController.zoomPercent))
        }
    }

    public private(set) var palette: PurpleThemePalette
    public var zoomController: EditorZoomController {
        didSet {
            preferencesStore.save(EditorPreferences(appearanceMode: appearanceMode, zoomPercent: zoomController.zoomPercent))
        }
    }

    public private(set) var tabSession: WorkspaceTabSession
    public private(set) var sessionsByID: [DocumentID: DocumentSession]
    public private(set) var savedBaselineByID: [DocumentID: DocumentSnapshot]
    public private(set) var selectedFolderURL: URL?
    public private(set) var grantedScopeRootURL: URL?
    public private(set) var folderEntries: [FolderEntryDescriptor] = []
    public private(set) var currentSelection = SwiftEditCore.TextRange(location: 0, length: 0)
    public private(set) var lintDiagnostics: [MarkdownLintDiagnostic] = []
    public private(set) var bracketResult: BracketBalanceResult?
    public private(set) var safetyBanner: InspectionSafetyBannerState
    public private(set) var statusBannerMessage: String?
    public var showMarkdownPreview: Bool = false
    public var showDiffPane: Bool = false
    public var isCheatSheetPresented: Bool = false
    public var isAboutSheetPresented: Bool = false
    /// Starts `true` on empty launch or single-file open (`Cmd+O`) and auto-expands (`false`) when mounting a workspace folder (`UI-001`).
    public var isLeftSidebarCollapsed: Bool = true
    public var findReplaceState = FindReplaceBarState()
    public private(set) var recentFiles: [RecentFileEntry] = []
    public private(set) var pendingDirtyCloseTabID: DocumentID?
    public private(set) var isPendingTerminationPrompt: Bool = false
    public private(set) var pendingBatchOpenPlan: BatchOpenPlan?
    public private(set) var pendingBatchFolderURL: URL?
    public private(set) var sidebarClipboard: SidebarFileClipboard?
    public private(set) var pendingTrashItemURL: URL?

    public let diffCoordinator = DiffPaneCoordinator()
    private let fileSystem: any FileSystemProviding
    private let desktopWorkspace: any DesktopWorkspaceIntegrating
    private let loader: DocumentLoader
    private let navigator = DotfileFolderNavigator()
    private let batchLoader: ShallowFolderBatchLoader
    private let recentFilesStore: RecentFilesStore
    private let preferencesStore: EditorPreferencesStore
    private let recoveryStore: SessionRecoveryStore
    private let parentPermissionChecker: (URL) -> Bool

    public init(
        preferencesSuiteName: String = "it.ph.SwiftEdit.preferences",
        recentFilesSuiteName: String = "it.ph.SwiftEdit.recentFiles",
        recoveryDirectoryURL: URL? = nil,
        fileSystem: any FileSystemProviding = LocalFileSystemAdapter(),
        bookmarkCoder: any SecurityScopedBookmarkCoding = SystemSecurityScopedBookmarkCoder(),
        desktopWorkspace: any DesktopWorkspaceIntegrating = MacOSWorkspaceAdapter(),
        parentPermissionChecker: @escaping (URL) -> Bool = { url in
            (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil
        }
    ) {
        self.fileSystem = fileSystem
        self.desktopWorkspace = desktopWorkspace
        self.loader = DocumentLoader(fileSystem: fileSystem)
        self.batchLoader = ShallowFolderBatchLoader(navigator: navigator, fileSystem: fileSystem)
        self.recentFilesStore = RecentFilesStore(
            suiteName: recentFilesSuiteName,
            fileSystem: fileSystem,
            bookmarkCoder: bookmarkCoder
        )
        self.parentPermissionChecker = parentPermissionChecker
        self.preferencesStore = EditorPreferencesStore(suiteName: preferencesSuiteName)
        let prefs = preferencesStore.load()
        self.appearanceMode = prefs.appearanceMode
        self.palette = PurpleThemePalette.resolve(appearance: prefs.appearanceMode, systemPrefersDark: true)
        self.zoomController = EditorZoomController(zoomPercent: prefs.zoomPercent)

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let resolvedRecoveryURL = recoveryDirectoryURL ?? appSupport
            .appendingPathComponent("PH.SwiftEdit", isDirectory: true)
            .appendingPathComponent("SessionRecovery", isDirectory: true)
        self.recoveryStore = SessionRecoveryStore(recoveryDirectoryURL: resolvedRecoveryURL)

        let welcomeText = """
        # PH.SwiftEdit — Sandbox Ready

        Welcome to **PH.SwiftEdit** (Zed-minimal Purple Chrome + Inverted B/W TextKit 2 Canvas).

        - Press `Cmd+D` to duplicate the current line or selection.
        - Press `Cmd++` / `Cmd+-` / `Cmd+0` to scale Editor Zoom (`50%..300%`).
        - Open a sandboxed folder on the left to inspect hidden dotfiles (`.env`, `.gitignore`).
        - Try `#HeadingWithoutSpace` or `[XSS](javascript:alert(1))` to test live AST linting.
        """
        let initialSession = DocumentSession(text: welcomeText)
        var initialTabs = WorkspaceTabSession()
        try? initialTabs.openOrActivate(snapshot: initialSession.snapshot, title: "Welcome.md", isDirty: false)

        self.tabSession = initialTabs
        self.sessionsByID = [initialSession.id: initialSession]
        self.savedBaselineByID = [initialSession.id: initialSession.snapshot]
        self.safetyBanner = InspectionSafetyBannerState.evaluate(snapshot: initialSession.snapshot)

        restoreSessionRecoveryIfPresent()
        recentFiles = recentFilesStore.entries()
        refreshDiagnosticsForActiveDocument()
    }

    public var activeDocumentSession: DocumentSession? {
        guard let activeID = tabSession.activeTabID else { return nil }
        return sessionsByID[activeID]
    }

    public var activeLineNumberGutter: LineNumberGutterProjection {
        let text = activeDocumentSession?.text ?? ""
        return LineNumberGutterProjection.evaluate(
            text: text,
            caretLocation: currentSelection.location,
            fontSizePoints: zoomController.scaledFontSizePoints
        )
    }

    public var activeStatusBarMetrics: StatusBarMetricsProjection {
        let snapshot = activeDocumentSession?.snapshot ?? DocumentSession(text: "").snapshot
        return StatusBarMetricsProjection.evaluate(
            snapshot: snapshot,
            caretLocation: currentSelection.location
        )
    }

    /// Returns `true` when `selectedFolderURL` is not `"/"` and the parent folder (`...`) is within `grantedScopeRootURL` or readable under active user permissions (`UI-001`, `BC-007`).
    public var canNavigateToParentFolder: Bool {
        guard let currentFolder = selectedFolderURL else { return false }
        let resolved = try? navigator.resolveParentDirectory(
            from: currentFolder,
            withinScope: grantedScopeRootURL,
            isParentReadable: parentPermissionChecker
        )
        return resolved != nil
    }

    /// Ascends one folder level (`...`) in the left sidebar when permitted by workspace scope or user directory read permissions (`UI-001`, `DATA-007`, `SEC-002`).
    public func navigateToParentFolder() {
        guard let currentFolder = selectedFolderURL else { return }
        do {
            guard let resolution = try navigator.resolveParentDirectory(
                from: currentFolder,
                withinScope: grantedScopeRootURL,
                isParentReadable: parentPermissionChecker
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

    public var activeTabTitle: String {
        guard let activeID = tabSession.activeTabID,
              let tab = tabSession.tabs.first(where: { $0.id == activeID }) else {
            return "Untitled"
        }
        return tab.title
    }

    public func openFolderViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Workspace Folder"
        guard panel.runModal() == .OK, let folderURL = panel.url else { return }
        selectWorkspaceFolder(folderURL)
    }

    public func openFileViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let fileURL = panel.url else { return }
        openFile(at: fileURL, withinScope: fileURL.deletingLastPathComponent())
    }

    public func refreshFolderEntries() {
        guard let folderURL = selectedFolderURL else { return }
        let scope = grantedScopeRootURL ?? folderURL
        do {
            folderEntries = try navigator.listEntries(in: folderURL, withinScope: scope)
            statusBannerMessage = nil
        } catch {
            statusBannerMessage = "Folder access error: \(error)"
        }
    }

    public func openFolderEntry(_ entry: FolderEntryDescriptor) {
        if entry.isDirectory {
            selectedFolderURL = entry.url.standardizedFileURL
            if grantedScopeRootURL == nil {
                grantedScopeRootURL = selectedFolderURL
            }
            refreshFolderEntries()
            return
        }
        openFile(at: entry.url, withinScope: grantedScopeRootURL ?? selectedFolderURL)
    }

    public func openFile(at url: URL, withinScope scope: URL?) {
        let standardizedURL = url.standardizedFileURL
        if let existingTab = tabSession.tabs.first(where: { $0.fileURL?.standardizedFileURL == standardizedURL }) {
            activateTab(id: existingTab.id)
            recordRecentFileIfEligible(url: standardizedURL, withinScope: scope)
            return
        }
        do {
            let loaded = try loader.load(from: standardizedURL, withinScope: scope)
            sessionsByID[loaded.id] = loaded
            savedBaselineByID[loaded.id] = loaded.snapshot
            if loaded.isBinaryReadOnly {
                statusBannerMessage = "Binary file opened in transient read-only inspection mode (Save, Format, Pin & SessionRecovery disabled)."
                safetyBanner = InspectionSafetyBannerState.evaluate(snapshot: loaded.snapshot)
                return
            }
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
        } catch {
            statusBannerMessage = "Open failed: \(error)"
        }
    }

    public func openRecentFile(_ entry: RecentFileEntry) {
        do {
            let resolvedURL = try recentFilesStore.resolve(entry: entry)
            recentFiles = recentFilesStore.entries()
            openFile(at: resolvedURL, withinScope: resolvedURL.deletingLastPathComponent())
        } catch {
            recentFiles = recentFilesStore.entries()
            statusBannerMessage = "Recent file unavailable: \(error)"
        }
    }

    public func clearRecentFiles() {
        recentFilesStore.clear()
        recentFiles = []
    }

    private func recordRecentFileIfEligible(url: URL, withinScope scope: URL?) {
        if let updated = try? recentFilesStore.record(url: url, withinScope: scope) {
            recentFiles = updated
        } else {
            recentFiles = recentFilesStore.entries()
        }
    }

    public func newUntitledTab() {
        let count = tabSession.tabs.count + 1
        let session = DocumentSession(text: "")
        sessionsByID[session.id] = session
        savedBaselineByID[session.id] = session.snapshot
        try? tabSession.openOrActivate(snapshot: session.snapshot, title: "Untitled-\(count).md", isDirty: true)
        statusBannerMessage = nil
        persistRecoveryState()
        refreshDiagnosticsForActiveDocument()
    }

    public func activateTab(id: DocumentID) {
        try? tabSession.activateTab(id: id)
        currentSelection = SwiftEditCore.TextRange(location: 0, length: 0)
        persistRecoveryState()
        refreshDiagnosticsForActiveDocument()
    }

    public func togglePin(id: DocumentID) {
        guard let tab = tabSession.tabs.first(where: { $0.id == id }) else { return }
        try? tabSession.setPinned(!tab.isPinned, for: id)
        persistRecoveryState()
    }

    public func closeTab(id: DocumentID) {
        do {
            _ = try tabSession.closeTab(id: id)
            sessionsByID.removeValue(forKey: id)
            savedBaselineByID.removeValue(forKey: id)
            try? recoveryStore.removeRecoverySnapshot(for: id)
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch DomainError.pinnedTabCloseForbidden {
            statusBannerMessage = "Pinned tab cannot be closed. Unpin it first."
        } catch {
            statusBannerMessage = "Close failed: \(error)"
        }
    }

    public func handleEditorTextChanged(_ newText: String) {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly,
              session.text != newText else { return }
        let fullRange = SwiftEditCore.TextRange(location: 0, length: session.text.utf16.count)
        _ = try? session.applyEdit(replacing: fullRange, with: newText)
        sessionsByID[activeID] = session
        try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
        persistRecoveryState()
        refreshDiagnosticsForActiveDocument()
    }

    public func handleSelectionChanged(_ range: SwiftEditCore.TextRange) {
        currentSelection = range
        guard let session = activeDocumentSession else { return }
        bracketResult = SearchDiffAndBracketEngine.evaluateBrackets(in: session.snapshot, caretLocation: range.location).completedValue
        try? tabSession.updateTabState(id: session.id, caretLocation: range.location)
    }

    public func performCommandD() {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID] else { return }
        do {
            _ = try session.duplicateLineOrSelection(selection: currentSelection)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            statusBannerMessage = nil
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Cmd+D failed: \(error)"
        }
    }

    public func formatActiveDocument() {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID] else { return }
        let snap = session.snapshot
        guard let batch = MarkdownLintAndFormatEngine.formatDocument(snapshot: snap).completedValue else {
            statusBannerMessage = "Formatting skipped (degraded, binary, AST depth > 128, or > 250 ms)."
            return
        }
        do {
            _ = try session.applyTextEdits(batch.edits, expectedRevision: snap.revision)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            statusBannerMessage = batch.edits.isEmpty ? "Markdown already formatted." : "Formatted \(batch.edits.count) line(s)."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Format failed: \(error)"
        }
    }

    public func saveActiveDocument() {
        guard let activeID = tabSession.activeTabID,
              let session = sessionsByID[activeID] else { return }
        guard !session.isBinaryReadOnly else {
            statusBannerMessage = "Save blocked: binary read-only file."
            return
        }

        let targetURL: URL
        if let existingURL = session.fileURL {
            targetURL = existingURL
        } else {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = activeTabTitle
            guard panel.runModal() == .OK, let chosen = panel.url else { return }
            targetURL = chosen
        }
        saveDocument(to: targetURL)
    }

    public func saveActiveDocumentAsViaPanel() {
        guard activeDocumentSession != nil else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = activeTabTitle
        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        saveDocument(to: chosen)
    }

    public func saveDocument(to targetURL: URL) {
        guard let activeID = tabSession.activeTabID,
              let session = sessionsByID[activeID] else { return }
        guard !session.isBinaryReadOnly else {
            statusBannerMessage = "Save blocked: binary read-only file."
            return
        }
        let standardizedTarget = targetURL.standardizedFileURL
        let effectiveScope = resolveSaveScope(for: standardizedTarget)
        do {
            let saved = try loader.save(session, to: standardizedTarget, withinScope: effectiveScope)
            sessionsByID[activeID] = saved
            savedBaselineByID[activeID] = saved.snapshot
            try? tabSession.updateTabState(id: activeID, title: standardizedTarget.lastPathComponent, fileURL: .some(standardizedTarget), isDirty: false, revision: saved.revision)
            try? recoveryStore.removeRecoverySnapshot(for: activeID)
            recordRecentFileIfEligible(url: standardizedTarget, withinScope: effectiveScope)
            statusBannerMessage = "Saved \(standardizedTarget.lastPathComponent)."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
            refreshFolderEntries()
        } catch {
            statusBannerMessage = "Save failed: \(error)"
        }
    }

    private func resolveSaveScope(for targetURL: URL) -> URL {
        if let scopeRoot = grantedScopeRootURL {
            let scopePath = scopeRoot.resolvingSymlinksInPath().standardizedFileURL.path
            let targetDirPath = targetURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
            if targetDirPath == scopePath || targetDirPath.hasPrefix(scopePath + "/") {
                return scopeRoot
            }
        }
        return targetURL.deletingLastPathComponent()
    }

    public func refreshDiagnosticsForActiveDocument() {
        guard let session = activeDocumentSession else {
            lintDiagnostics = []
            bracketResult = nil
            return
        }
        let snap = session.snapshot
        safetyBanner = InspectionSafetyBannerState.evaluate(snapshot: snap)
        lintDiagnostics = MarkdownLintAndFormatEngine.lint(snapshot: snap).completedValue?.diagnostics ?? []
        bracketResult = SearchDiffAndBracketEngine.evaluateBrackets(in: snap, caretLocation: currentSelection.location).completedValue
        if showDiffPane, let baseline = savedBaselineByID[session.id] {
            diffCoordinator.compare(lhs: baseline, rhs: snap)
        }
    }

    /// Presents or hides the inline Find / Find & Replace / Go-to-Line bar (`Cmd+F`, `Cmd+H`, `Cmd+G`).
    public func presentFindBar(mode: FindBarPresentationMode) {
        findReplaceState.mode = mode
    }

    /// Evaluates literal search matches for `findReplaceState.query` in the active document and selects the first match (`BC-004`, `BC-011`).
    public func executeFind() {
        guard let session = activeDocumentSession else { return }
        let options = SearchOptions(isCaseSensitive: findReplaceState.isCaseSensitive)
        switch DocumentSearchEngine.find(query: findReplaceState.query, in: session.snapshot, options: options) {
        case .completed(let ranges):
            findReplaceState.matches = ranges
            findReplaceState.activeMatchIndex = 0
            if let first = ranges.first {
                handleSelectionChanged(first)
            }
            statusBannerMessage = nil
        case .degradedOrTimedOut(let reason):
            findReplaceState.matches = []
            statusBannerMessage = "Search skipped: \(reason)"
        }
    }

    /// Selects the next literal match in `findReplaceState.matches`.
    public func findNextMatch() {
        if let next = findReplaceState.selectNextMatch() {
            handleSelectionChanged(next)
        }
    }

    /// Selects the previous literal match in `findReplaceState.matches`.
    public func findPreviousMatch() {
        if let previous = findReplaceState.selectPreviousMatch() {
            handleSelectionChanged(previous)
        }
    }

    /// Replaces all literal matches of `findReplaceState.query` with `findReplaceState.replacement` in one atomic revision (`BC-004`).
    public func executeReplaceAll() {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID] else { return }
        let snap = session.snapshot
        let options = SearchOptions(isCaseSensitive: findReplaceState.isCaseSensitive)
        guard let edits = DocumentSearchEngine.replaceAll(
            query: findReplaceState.query,
            with: findReplaceState.replacement,
            in: snap,
            options: options
        ).completedValue else {
            statusBannerMessage = "Replace All skipped (binary, degraded, or match limit exceeded)."
            return
        }
        guard !edits.isEmpty else { return }
        do {
            _ = try session.applyTextEdits(edits, expectedRevision: snap.revision)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            findReplaceState.matches = []
            statusBannerMessage = "Replaced \(edits.count) occurrence(s)."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Replace All failed: \(error)"
        }
    }

    /// Moves the selection to the 1-based line parsed from `findReplaceState.goToLineText` (`Cmd+G`).
    public func executeGoToLine() {
        guard let session = activeDocumentSession,
              let targetLine = Int(findReplaceState.goToLineText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let range = DocumentSearchEngine.goToLine(targetLine, in: session.snapshot) else {
            statusBannerMessage = "Line number out of range."
            return
        }
        handleSelectionChanged(range)
        statusBannerMessage = nil
    }

    /// Updates the active document's wire `LineEnding` (`LF`, `CRLF`, `CR`) and marks the tab dirty (`DATA-004`).
    public func setActiveDocumentLineEnding(_ lineEnding: LineEnding) {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID] else { return }
        do {
            try session.setLineEnding(lineEnding)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Cannot change line ending: \(error)"
        }
    }

    /// Initiates tab closure (`Cmd+W`), pausing for `Save / Don't Save / Cancel` confirmation when `tab.isDirty` is `true` (`BC-008`, `DATA-006`).
    public func requestCloseTab(id: DocumentID) {
        guard let tab = tabSession.tabs.first(where: { $0.id == id }) else { return }
        if tab.isPinned {
            statusBannerMessage = "Pinned tab cannot be closed. Unpin it first."
            return
        }
        if tab.isDirty {
            pendingDirtyCloseTabID = id
            isPendingTerminationPrompt = false
            return
        }
        closeTab(id: id)
    }

    /// Applies the user's `Save / Don't Save / Cancel` decision for a pending dirty tab close or application quit prompt (`DATA-006`).
    public func resolvePendingDirtyClose(_ decision: DirtyCloseDecision) {
        if isPendingTerminationPrompt {
            resolvePendingTermination(decision)
            return
        }
        guard let tabID = pendingDirtyCloseTabID else { return }
        switch decision {
        case .cancel:
            pendingDirtyCloseTabID = nil
        case .dontSave:
            pendingDirtyCloseTabID = nil
            closeTab(id: tabID)
        case .save:
            pendingDirtyCloseTabID = nil
            activateTab(id: tabID)
            saveActiveDocument()
            if sessionsByID[tabID]?.isDirty == false {
                closeTab(id: tabID)
            }
        }
    }

    private func resolvePendingTermination(_ decision: DirtyCloseDecision) {
        switch decision {
        case .cancel:
            isPendingTerminationPrompt = false
            pendingDirtyCloseTabID = nil
        case .dontSave:
            for id in tabSession.tabs.map(\.id) {
                _ = try? tabSession.closeTab(id: id, forcePinned: true)
                sessionsByID.removeValue(forKey: id)
                savedBaselineByID.removeValue(forKey: id)
                try? recoveryStore.removeRecoverySnapshot(for: id)
            }
            isPendingTerminationPrompt = false
            pendingDirtyCloseTabID = nil
            persistRecoveryState()
        case .save:
            if let targetID = pendingDirtyCloseTabID {
                activateTab(id: targetID)
                saveActiveDocument()
            }
            isPendingTerminationPrompt = false
            pendingDirtyCloseTabID = nil
        }
    }

    /// Returns `true` when the application may terminate immediately, or `false` while staging a dirty-tab confirmation prompt (`Cmd+Q`).
    public func requestApplicationTermination() -> Bool {
        if let firstDirty = tabSession.tabs.first(where: \.isDirty) {
            pendingDirtyCloseTabID = firstDirty.id
            isPendingTerminationPrompt = true
            return false
        }
        return true
    }

    /// Presents `NSOpenPanel` for `Open All Files in Folder` (`Cmd+Shift+Option+O`).
    public func openAllFilesInFolderViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open All Files in Folder"
        guard panel.runModal() == .OK, let folderURL = panel.url else { return }
        openAllFilesInFolder(folderURL)
    }

    /// Evaluates `ShallowFolderBatchLoader.plan` for `folderURL`, expanding the sidebar and gating batches above `50` files behind explicit confirmation (`BC-011`).
    public func openAllFilesInFolder(_ folderURL: URL) {
        let canonical = folderURL.standardizedFileURL
        do {
            let plan = try batchLoader.plan(folder: canonical, withinScope: canonical)
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

    private func openBatchPlan(_ plan: BatchOpenPlan, withinScope scopeURL: URL) {
        for fileURL in plan.files {
            openFile(at: fileURL, withinScope: scopeURL)
        }
    }

    public func toggleDiffPane() {
        showDiffPane.toggle()
        refreshDiagnosticsForActiveDocument()
    }

    /// Toggles the left Folder Navigator sidebar visibility (`Cmd+B`).
    public func toggleLeftSidebar() {
        isLeftSidebarCollapsed.toggle()
    }

    /// Requests closing the currently active document tab (`Cmd+W`).
    public func requestCloseActiveTab() {
        guard let activeID = tabSession.activeTabID else { return }
        requestCloseTab(id: activeID)
    }

    /// Creates a new folder inside `parentURL` (or `selectedFolderURL`) within the active workspace scope (`BC-012`, `SEC-003`).
    @discardableResult
    public func sidebarCreateFolder(named name: String, in parentURL: URL? = nil) -> URL? {
        guard let targetParent = parentURL ?? selectedFolderURL else { return nil }
        let scope = grantedScopeRootURL ?? targetParent
        do {
            let created = try fileSystem.createDirectory(named: name, in: targetParent, withinScope: scope)
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
            let created = try fileSystem.createFile(named: name, contents: Data(), in: targetParent, withinScope: scope)
            refreshFolderEntries()
            return created
        } catch {
            statusBannerMessage = "Create file failed: \(error)"
            return nil
        }
    }

    /// Renames `itemURL` to single-segment `newName` inside workspace scope and reconciles open tabs (`BC-006`, `BC-008`, `SEC-003`).
    @discardableResult
    public func sidebarRenameItem(at itemURL: URL, to newName: String) -> URL? {
        let scope = grantedScopeRootURL ?? selectedFolderURL
        do {
            let oldStandardized = itemURL.standardizedFileURL
            let renamed = try fileSystem.renameItem(at: oldStandardized, toName: newName, withinScope: scope)
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
            let pasted = try fileSystem.pasteItem(
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
            try fileSystem.trashItem(at: itemURL, withinScope: scope)
            let beforeTabIDs = Set(tabSession.tabs.map(\.id))
            tabSession.applyTrash(of: itemURL)
            let remainingTabIDs = Set(tabSession.tabs.map(\.id))
            for closedID in beforeTabIDs.subtracting(remainingTabIDs) {
                sessionsByID.removeValue(forKey: closedID)
                savedBaselineByID.removeValue(forKey: closedID)
                try? recoveryStore.removeRecoverySnapshot(for: closedID)
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

    /// Reveals `itemURL` in macOS Finder within the active workspace scope (`SEC-004`).
    public func sidebarRevealInFinder(at itemURL: URL) {
        do {
            try desktopWorkspace.revealInFinder(itemURL: itemURL, withinScope: grantedScopeRootURL ?? selectedFolderURL)
        } catch {
            statusBannerMessage = "Reveal in Finder blocked: \(error)"
        }
    }

    /// Opens `folderURL` in macOS Finder within the active workspace scope (`SEC-004`).
    public func sidebarOpenFolderInFinder(at folderURL: URL) {
        do {
            try desktopWorkspace.openFolderInFinder(folderURL: folderURL, withinScope: grantedScopeRootURL ?? selectedFolderURL)
        } catch {
            statusBannerMessage = "Open Folder in Finder blocked: \(error)"
        }
    }

    /// Opens `iTerm2` (if installed & preferred) or `Terminal.app` at `targetURL` (or its parent directory when `targetURL` is a file) (`SEC-004`).
    public func sidebarOpenInTerminal(at targetURL: URL) {
        do {
            _ = try desktopWorkspace.openInTerminal(
                targetURL: targetURL,
                withinScope: grantedScopeRootURL ?? selectedFolderURL,
                explicitBundleIdentifier: nil
            )
        } catch {
            statusBannerMessage = "Open Terminal blocked: \(error)"
        }
    }

    private func reconcileSessionURLsAfterRename(from oldURL: URL, to newURL: URL) {
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

    private func restoreSessionRecoveryIfPresent() {
        guard let manifest = try? recoveryStore.loadManifest(), !manifest.tabs.isEmpty else {
            _ = try? recoveryStore.purgeOrphanedSnapshots(keeping: Set(sessionsByID.keys))
            return
        }
        var restoredTabs: [TabDescriptor] = []
        var restoredSessions: [DocumentID: DocumentSession] = [:]
        var restoredBaselines: [DocumentID: DocumentSnapshot] = [:]

        for tab in manifest.tabs {
            if let recovered = try? recoveryStore.loadRecoverySnapshot(for: tab.id) {
                let session = DocumentSession(
                    id: recovered.id,
                    fileURL: tab.fileURL,
                    revision: recovered.revision,
                    text: recovered.text,
                    encoding: recovered.encoding,
                    lineEnding: recovered.lineEnding,
                    isDirty: tab.isDirty
                )
                restoredTabs.append(tab)
                restoredSessions[tab.id] = session
                restoredBaselines[tab.id] = session.snapshot
            } else if let fileURL = tab.fileURL,
                      let diskSession = try? loader.load(from: fileURL) {
                restoredTabs.append(tab)
                restoredSessions[tab.id] = diskSession
                restoredBaselines[tab.id] = diskSession.snapshot
            }
        }

        if !restoredTabs.isEmpty {
            tabSession = WorkspaceTabSession(tabs: restoredTabs, activeTabID: manifest.activeTabID)
            sessionsByID = restoredSessions
            savedBaselineByID = restoredBaselines
        }
        _ = try? recoveryStore.purgeOrphanedSnapshots(keeping: Set(restoredTabs.map(\.id)))
    }

    private func persistRecoveryState() {
        let manifest = SessionRecoveryManifest(tabs: tabSession.tabs, activeTabID: tabSession.activeTabID)
        try? recoveryStore.saveManifest(manifest)
        for tab in tabSession.tabs {
            if let session = sessionsByID[tab.id], (session.isDirty || session.fileURL == nil), !session.isBinaryReadOnly {
                try? recoveryStore.saveRecoverySnapshot(session.snapshot)
            }
        }
    }
}

/// Root Zed-minimal Purple (`Viola`) + inverted `#FFFFFF`/`#000000` SwiftUI workspace view for `PH.SwiftEdit` (`UI-001..012`).
public struct SwiftEditRootView: View {
    @State private var model = SwiftEditWorkbenchModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            toolbarBar
            HSplitView {
                if !model.isLeftSidebarCollapsed {
                    sidebarView
                        .frame(minWidth: 190, idealWidth: 230, maxWidth: 320)
                }
                VStack(spacing: 0) {
                    tabBar
                    safetyAndErrorBanners
                    FindReplaceGoToLineBar(
                        state: $model.findReplaceState,
                        palette: model.palette,
                        onFind: { model.executeFind() },
                        onFindNext: { model.findNextMatch() },
                        onFindPrevious: { model.findPreviousMatch() },
                        onReplaceAll: { model.executeReplaceAll() },
                        onGoToLine: { model.executeGoToLine() },
                        onClose: { model.presentFindBar(mode: .hidden) }
                    )
                    editorAndOptionalPanels
                }
            }
            statusBar
        }
        .background(model.palette.chromeSurface.swiftUIColor)
        .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
        .frame(minWidth: 960, minHeight: 620)
        .focusedSceneValue(\.workbenchModel, model)
        .sheet(isPresented: $model.isCheatSheetPresented) {
            KeyboardShortcutsCheatSheetView(palette: model.palette) {
                model.isCheatSheetPresented = false
            }
        }
        .sheet(isPresented: $model.isAboutSheetPresented) {
            AboutSheetView(
                descriptor: AboutSheetDescriptor.resolveFromMainBundle(),
                palette: model.palette
            ) {
                model.isAboutSheetPresented = false
            }
        }
        .alert(
            "Unsaved Changes",
            isPresented: Binding(
                get: { model.pendingDirtyCloseTabID != nil },
                set: { if !$0 { model.resolvePendingDirtyClose(.cancel) } }
            )
        ) {
            Button("Save") { model.resolvePendingDirtyClose(.save) }
            Button("Don't Save", role: .destructive) { model.resolvePendingDirtyClose(.dontSave) }
            Button("Cancel", role: .cancel) { model.resolvePendingDirtyClose(.cancel) }
        } message: {
            Text("Do you want to save your changes before closing?")
        }
        .alert(
            "Open All Files in Folder?",
            isPresented: Binding(
                get: { model.pendingBatchOpenPlan != nil },
                set: { if !$0 { model.cancelPendingBatchOpen() } }
            )
        ) {
            Button("Open \(model.pendingBatchOpenPlan?.files.count ?? 0) Files") { model.confirmPendingBatchOpen() }
            Button("Cancel", role: .cancel) { model.cancelPendingBatchOpen() }
        } message: {
            Text("This folder contains more than 50 text files (\(model.pendingBatchOpenPlan?.files.count ?? 0) eligible files). Open all?")
        }
        .alert(
            "Move Item to Trash?",
            isPresented: Binding(
                get: { model.pendingTrashItemURL != nil },
                set: { if !$0 { model.cancelPendingTrashItem() } }
            )
        ) {
            Button("Move to Trash", role: .destructive) { model.confirmPendingTrashItem() }
            Button("Cancel", role: .cancel) { model.cancelPendingTrashItem() }
        } message: {
            Text(model.pendingTrashItemURL?.lastPathComponent ?? "")
        }
    }

    private var toolbarBar: some View {
        HStack(spacing: 10) {
            Text("PH.SwiftEdit")
                .font(.headline.weight(.semibold))
                .foregroundStyle(model.palette.featherHighlight.swiftUIColor)
            Button("Folder…") { model.openFolderViaPanel() }
            Button("File…") { model.openFileViaPanel() }
            Button("New") { model.newUntitledTab() }
            Button("Save") { model.saveActiveDocument() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!model.safetyBanner.canSave)
            Button("Cmd+D") { model.performCommandD() }
                .keyboardShortcut("d", modifiers: .command)
            Button("Format") { model.formatActiveDocument() }
                .disabled(!model.safetyBanner.canFormat)
            Toggle("Preview", isOn: $model.showMarkdownPreview)
                .toggleStyle(.button)
            Button(model.showDiffPane ? "Hide Diff" : "Compare Diff") { model.toggleDiffPane() }
            Button("Shortcuts") { model.isCheatSheetPresented = true }
                .help("Open Keyboard Shortcuts CheatSheet (Cmd+/)")
            Spacer()
            HStack(spacing: 4) {
                Button("-") { model.zoomController.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("\(model.zoomController.zoomPercent)%") { model.zoomController.resetZoom() }
                    .keyboardShortcut("0", modifiers: .command)
                Button("+") { model.zoomController.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
            }
            Picker("Theme", selection: $model.appearanceMode) {
                Text("Light").tag(AppearanceMode.light)
                Text("Black").tag(AppearanceMode.black)
                Text("Auto").tag(AppearanceMode.auto)
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(model.palette.brandGround.swiftUIColor)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(model.tabSession.tabs, id: \.id) { tab in
                    let isActive = tab.id == model.tabSession.activeTabID
                    HStack(spacing: 6) {
                        Button(action: { model.togglePin(id: tab.id) }) {
                            Image(systemName: tab.isPinned ? "pin.fill" : "pin")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        Button(action: { model.activateTab(id: tab.id) }) {
                            Text("\(tab.title)\(tab.isDirty ? " •" : "")")
                                .font(.callout.weight(isActive ? .semibold : .regular))
                        }
                        .buttonStyle(.plain)
                        Button(action: { model.requestCloseTab(id: tab.id) }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isActive ? model.palette.primaryAccent.swiftUIColor.opacity(0.35) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isActive ? model.palette.strokeLavender.swiftUIColor : Color.clear, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(model.palette.chromeSurface.swiftUIColor)
    }

    @ViewBuilder
    private var safetyAndErrorBanners: some View {
        if model.safetyBanner.isBinaryReadOnlyBannerVisible {
            Text("READ-ONLY BINARY INSPECTION: Save, Format, Pin Tab, and SessionRecovery are disabled.")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.25))
        }
        if !model.safetyBanner.bidiWarnings.isEmpty {
            Text("BiDi Warning: \(model.safetyBanner.bidiWarnings.count) Unicode bidirectional control character(s) detected.")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.yellow.opacity(0.25))
        }
        if let message = model.statusBannerMessage {
            Text(message)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(model.palette.primaryAccent.swiftUIColor.opacity(0.2))
        }
    }

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(model.selectedFolderURL?.lastPathComponent ?? "No Folder Open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.palette.strokeLavender.swiftUIColor)
                    .lineLimit(1)
                Spacer()
                if model.selectedFolderURL != nil {
                    Button(action: { model.navigateToParentFolder() }) {
                        Label("...", systemImage: "arrow.turn.left.up")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canNavigateToParentFolder)
                    .help("Go to parent folder (...)")
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            List {
                if model.canNavigateToParentFolder {
                    Button(action: { model.navigateToParentFolder() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.minus")
                                .foregroundStyle(model.palette.featherHighlight.swiftUIColor)
                            Text("...")
                                .font(.callout.weight(.semibold))
                        }
                    }
                    .buttonStyle(.plain)
                }
                ForEach(model.folderEntries, id: \.url) { entry in
                    Button(action: { model.openFolderEntry(entry) }) {
                        HStack(spacing: 6) {
                            Image(systemName: entry.isDirectory ? "folder.fill" : (entry.isHiddenDotfile ? "eye.slash" : "doc.text"))
                                .foregroundStyle(model.palette.strokeLavender.swiftUIColor)
                            Text(entry.name)
                                .font(.callout)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Reveal in Finder") { model.sidebarRevealInFinder(at: entry.url) }
                        if entry.isDirectory {
                            Button("Open Folder in Finder") { model.sidebarOpenFolderInFinder(at: entry.url) }
                        } else if let currentFolder = model.selectedFolderURL {
                            Button("Open Folder in Finder") { model.sidebarOpenFolderInFinder(at: currentFolder) }
                        }
                        Button("Open Terminal") { model.sidebarOpenInTerminal(at: entry.url) }
                        Divider()
                        Button("New Folder") { _ = model.sidebarCreateFolder(named: "New Folder", in: entry.isDirectory ? entry.url : model.selectedFolderURL) }
                        Button("New File") { _ = model.sidebarCreateFile(named: "Untitled.md", in: entry.isDirectory ? entry.url : model.selectedFolderURL) }
                        Divider()
                        Button("Cut") { model.sidebarCutItem(at: entry.url) }
                        Button("Copy") { model.sidebarCopyItem(at: entry.url) }
                        Button("Paste") { _ = model.sidebarPasteItem(into: entry.isDirectory ? entry.url : model.selectedFolderURL) }
                            .disabled(model.sidebarClipboard == nil)
                        Divider()
                        Button(entry.isDirectory ? "Rename Folder…" : "Rename File…") {
                            promptInlineRename(for: entry)
                        }
                        Button("Delete (Move to Trash)", role: .destructive) {
                            model.requestSidebarTrashItem(at: entry.url)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(model.palette.brandGround.swiftUIColor.opacity(0.92))
    }

    private func promptInlineRename(for entry: FolderEntryDescriptor) {
        let alert = NSAlert()
        alert.messageText = entry.isDirectory ? "Rename Folder" : "Rename File"
        alert.informativeText = "Enter a new single-segment name:"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = entry.name
        alert.accessoryView = input
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            _ = model.sidebarRenameItem(at: entry.url, to: input.stringValue)
        }
    }

    private var editorAndOptionalPanels: some View {
        HSplitView {
            if let session = model.activeDocumentSession {
                HStack(spacing: 0) {
                    LineNumberGutterView(
                        projection: model.activeLineNumberGutter,
                        palette: model.palette
                    )
                    TextKit2EditorView(
                        text: session.text,
                        isEditable: !session.isBinaryReadOnly,
                        backgroundColor: model.palette.editorCanvasBackground.nsColor,
                        textColor: model.palette.editorCanvasText.nsColor,
                        fontSizePoints: model.zoomController.scaledFontSizePoints,
                        onTextChange: { model.handleEditorTextChanged($0) },
                        onSelectionChange: { model.handleSelectionChanged($0) }
                    )
                }
            }
            if model.showMarkdownPreview, let session = model.activeDocumentSession {
                markdownPreviewPanel(for: session.snapshot)
                    .frame(minWidth: 260, idealWidth: 340)
            }
            if model.showDiffPane {
                diffPanel
                    .frame(minWidth: 300, idealWidth: 420)
            }
        }
    }

    private func markdownPreviewPanel(for snapshot: DocumentSnapshot) -> some View {
        let blocks = WorkspaceEditorCoordinator(session: DocumentSession(text: snapshot.text)).projectMarkdownPreview(from: snapshot)
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Native Preview (Zero-WebKit)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.palette.strokeLavender.swiftUIColor)
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    Text(block.text)
                        .font(block.kind == .heading ? .title3.bold() : (block.kind == .codeBlock || block.isInertPlainTextHTML ? .body.monospaced() : .body))
                        .padding(block.isInertPlainTextHTML ? 6 : 0)
                        .background(block.isInertPlainTextHTML ? Color.red.opacity(0.15) : Color.clear)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
        }
        .background(model.palette.chromeSurface.swiftUIColor)
    }

    private var diffPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("Side-by-Side Myers Diff (vs Saved Baseline)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.palette.strokeLavender.swiftUIColor)
                ForEach(Array(model.diffCoordinator.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 8) {
                        Text(row.lhsText ?? "")
                            .font(.caption.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(row.kind == .removed ? Color.red.opacity(0.2) : Color.clear)
                        Text(row.rhsText ?? "")
                            .font(.caption.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(row.kind == .inserted ? Color.green.opacity(0.2) : Color.clear)
                    }
                }
            }
            .padding(12)
        }
        .background(model.palette.chromeSurface.swiftUIColor)
    }

    private var statusBar: some View {
        let metrics = model.activeStatusBarMetrics
        return HStack(spacing: 14) {
            Text("Lint: \(model.lintDiagnostics.count)")
            Text("Brackets: \(model.bracketResult?.unbalancedBrackets.isEmpty == true ? "Balanced" : "Unbalanced (\(model.bracketResult?.unbalancedBrackets.count ?? 0))")")
            Text("Mode: \(model.palette.mode.rawValue.capitalized)")
            Spacer()
            Text("Zoom: \(model.zoomController.zoomPercent)%")
            Text("Ln \(metrics.line), Col \(metrics.column)")
            Text("\(metrics.characterCount) chars")
            Text(metrics.encodingLabel)
            Menu(StatusBarMetricsProjection.displayLabel(for: metrics.lineEnding)) {
                Button("LF (Unix / macOS)") { model.setActiveDocumentLineEnding(.lf) }
                Button("CRLF (Windows)") { model.setActiveDocumentLineEnding(.crlf) }
                Button("CR (Classic Mac)") { model.setActiveDocumentLineEnding(.cr) }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(model.palette.brandGround.swiftUIColor)
    }
}

private struct FocusedWorkbenchModelKey: FocusedValueKey {
    typealias Value = SwiftEditWorkbenchModel
}

public extension FocusedValues {
    var workbenchModel: SwiftEditWorkbenchModel? {
        get { self[FocusedWorkbenchModelKey.self] }
        set { self[FocusedWorkbenchModelKey.self] = newValue }
    }
}

/// Classic macOS menu bar `Commands` routed to the focused `SwiftEditWorkbenchModel` (`File`, `Edit`, `View`, `Help`, `About`) (`UI-009`, `UI-010`, `SEC-004`).
public struct SwiftEditCommands: Commands {
    @FocusedValue(\.workbenchModel) private var model

    public init() {}

    public var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About PH.SwiftEdit") {
                model?.isAboutSheetPresented = true
            }
            .disabled(model == nil)
        }

        CommandGroup(replacing: .newItem) {
            Button("New Document") { model?.newUntitledTab() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(model == nil)
            Button("Open File…") { model?.openFileViaPanel() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(model == nil)
            Button("Open Folder…") { model?.openFolderViaPanel() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(model == nil)
            Button("Open All Files in Folder…") { model?.openAllFilesInFolderViaPanel() }
                .keyboardShortcut("o", modifiers: [.command, .shift, .option])
                .disabled(model == nil)
            Menu("Open Recent") {
                if let entries = model?.recentFiles, !entries.isEmpty {
                    ForEach(entries, id: \.standardizedPath) { entry in
                        Button(entry.displayName) {
                            model?.openRecentFile(entry)
                        }
                    }
                    Divider()
                    Button("Clear Recent") {
                        model?.clearRecentFiles()
                    }
                } else {
                    Text("No Recent Files")
                }
            }
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") { model?.saveActiveDocument() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(model?.safetyBanner.canSave != true)
            Button("Save As…") { model?.saveActiveDocumentAsViaPanel() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(model?.safetyBanner.canSave != true)
            Divider()
            Button("Close Document") { model?.requestCloseActiveTab() }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(model == nil)
        }

        CommandGroup(after: .undoRedo) {
            Button("Redo") {
                NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
            }
            .keyboardShortcut("y", modifiers: .command)
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Duplicate Line or Selection") { model?.performCommandD() }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(model == nil)
            Button("Format Markdown") { model?.formatActiveDocument() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(model?.safetyBanner.canFormat != true)
            Divider()
            Button("Find…") { model?.presentFindBar(mode: .find) }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(model == nil)
            Button("Find and Replace…") { model?.presentFindBar(mode: .findAndReplace) }
                .keyboardShortcut("h", modifiers: .command)
                .disabled(model == nil)
            Button("Go to Line…") { model?.presentFindBar(mode: .goToLine) }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(model == nil)
        }

        CommandGroup(after: .sidebar) {
            Button("Toggle Folder Navigator") { model?.toggleLeftSidebar() }
                .keyboardShortcut("b", modifiers: .command)
                .disabled(model == nil)
            Divider()
            Button("Zoom In") { model?.zoomController.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(model == nil)
            Button("Zoom Out") { model?.zoomController.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(model == nil)
            Button("Actual Size (100%)") { model?.zoomController.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(model == nil)
        }

        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts CheatSheet") {
                model?.isCheatSheetPresented = true
            }
            .keyboardShortcut("/", modifiers: .command)
            .disabled(model == nil)
        }
    }
}
#endif
