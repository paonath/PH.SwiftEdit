import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Non-mutating `@MainActor` visual highlight snapshot projecting active line, nested brackets, active pair, unbalanced brackets, and backtick code spans (`UI-005`, `UI-006`, `UI-012`).
public struct EditorHighlightProjection: Equatable, Sendable {
    public let activeLineRange: SwiftEditCore.TextRange
    public let bracketPairs: [BracketPairSpan]
    public let activeBracketPair: BracketPairSpan?
    public let unbalancedBrackets: [UnbalancedBracket]
    public let backtickSpans: [BacktickHighlightSpan]

    public init(
        activeLineRange: SwiftEditCore.TextRange = SwiftEditCore.TextRange(location: 0, length: 0),
        bracketPairs: [BracketPairSpan] = [],
        activeBracketPair: BracketPairSpan? = nil,
        unbalancedBrackets: [UnbalancedBracket] = [],
        backtickSpans: [BacktickHighlightSpan] = []
    ) {
        self.activeLineRange = activeLineRange
        self.bracketPairs = bracketPairs
        self.activeBracketPair = activeBracketPair
        self.unbalancedBrackets = unbalancedBrackets
        self.backtickSpans = backtickSpans
    }

    /// Computes a deterministic highlight projection without mutating `session`, incrementing `BufferRevision`, or copying the full UTF-16 buffer (`PERF-007`).
    public static func evaluate(
        text: String,
        caretLocation: Int,
        bracketResult: BracketBalanceResult?,
        backtickResult: BacktickHighlightResult?
    ) -> EditorHighlightProjection {
        let nsString = text as NSString
        let clampedCaret = min(max(0, caretLocation), nsString.length)
        var lineRange = nsString.lineRange(for: NSRange(location: clampedCaret, length: 0))
        while lineRange.length > 0 {
            let unit = nsString.character(at: lineRange.location + lineRange.length - 1)
            if unit == 0x0A || unit == 0x0D {
                lineRange.length -= 1
            } else {
                break
            }
        }
        return EditorHighlightProjection(
            activeLineRange: SwiftEditCore.TextRange(location: lineRange.location, length: lineRange.length),
            bracketPairs: bracketResult?.matchedPairs ?? [],
            activeBracketPair: bracketResult?.activePair,
            unbalancedBrackets: bracketResult?.unbalancedBrackets ?? [],
            backtickSpans: backtickResult?.spans ?? []
        )
    }
}

/// Strictly percentage-based left sidebar sizing geometry avoiding hardcoded pixel bounds across displays (`UI-001`, `UI-005`).
public enum SidebarLayoutGeometry {
    /// Minimum sidebar width as a fraction (`12%`) of the window/container width.
    public static let minWidthRatio: Double = 0.12
    /// Maximum sidebar width as a fraction (`65%`) of the window/container width.
    public static let maxWidthRatio: Double = 0.65
    /// Default expanded sidebar width as a fraction (`22%`) of the window/container width.
    public static let defaultWidthRatio: Double = 0.22

    /// Clamps any candidate sidebar ratio into `0.12...0.65`.
    public static func clampedRatio(_ rawRatio: Double) -> Double {
        guard rawRatio.isFinite else { return defaultWidthRatio }
        return min(max(rawRatio, minWidthRatio), maxWidthRatio)
    }

    /// Computes proportional sidebar width strictly from `containerWidth * clampedRatio(ratio)`; returns `0` for non-positive container widths.
    public static func resolvedWidth(forContainerWidth containerWidth: Double, ratio: Double) -> Double {
        guard containerWidth.isFinite, containerWidth > 0 else { return 0 }
        return containerWidth * clampedRatio(ratio)
    }

    /// Computes a clamped percentage ratio after dragging the divider by `dragDeltaWidth` inside `containerWidth`.
    public static func updatedRatio(currentRatio: Double, dragDeltaWidth: Double, containerWidth: Double) -> Double {
        guard containerWidth.isFinite, containerWidth > 0, dragDeltaWidth.isFinite else {
            return clampedRatio(currentRatio)
        }
        return clampedRatio(currentRatio + (dragDeltaWidth / containerWidth))
    }
}

/// Authoritative Help menu command titles exposed by `SwiftEditCommands` (`UI-009`, `UI-010`, `AR-014`).
public enum SwiftEditHelpMenuCatalog {
    public static let itemTitles: [String] = [
        "Keyboard Shortcuts CheatSheet",
        "About PH.SwiftEdit",
    ]
}

/// Transient read-only presentation for NUL-bearing binary files excluded from persistent tabs, pinning, and `SessionRecovery` (`BUG-007`, `MEM-002`, `DATA-003`).
public struct BinaryInspectionPresentation: Equatable, Sendable {
    public let id: DocumentID
    public let title: String
    public let fileURL: URL
    public let snapshot: DocumentSnapshot

    public init(id: DocumentID, title: String, fileURL: URL, snapshot: DocumentSnapshot) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.snapshot = snapshot
    }
}

/// `@MainActor @Observable` application controller wiring `SwiftEditCore` engines and `SessionRecoveryStore` to the Zed-minimal Purple SwiftUI shell (`UI-001..012`).
@MainActor
@Observable
public final class SwiftEditWorkbenchModel {
    /// Current macOS system dark-appearance flag synced from `@Environment(\.colorScheme)` for live `.auto` resolution (`UI-003`).
    public private(set) var systemPrefersDark: Bool = true
    /// Current macOS Reduce Transparency accessibility preference (`UI-009`).
    public private(set) var reduceTransparency: Bool = false
    /// Current macOS Increased Contrast accessibility preference (`UI-003`, `UI-009`).
    public private(set) var increasedContrast: Bool = false
    /// Latest window appearance target synchronized via `MacOSAppearanceSynchronizer` (`UI-003`).
    public private(set) var lastWindowAppearanceTarget: MacOSWindowAppearanceTarget = .darkAqua
    /// Proportional width of the left navigation sidebar (`0.12...0.65` of window width, never hardcoded pixels) (`UI-001`).
    public private(set) var sidebarWidthRatio: Double = SidebarLayoutGeometry.defaultWidthRatio
    /// `true` while the left sidebar is open and pinned; unpinning collapses the sidebar cleanly (`UI-001`).
    public var isLeftSidebarPinned: Bool { !isLeftSidebarCollapsed }
    /// `true` while the pointer hovers over the top bar area, revealing middle command buttons (`UI-001`, `UI-011`).
    public var isToolbarHovered: Bool = false
    /// Latest linear `BacktickHighlightScanner` scan output for the active document.
    public private(set) var backtickResult: BacktickHighlightResult?

    /// SwiftUI `.preferredColorScheme` override (`nil` in `.auto` so macOS system appearance flows dynamically) (`UI-003`).
    public var preferredSwiftUIColorScheme: ColorScheme? {
        switch appearanceMode {
        case .light: return .light
        case .black: return .dark
        case .auto: return nil
        }
    }

    /// Non-mutating highlight projection for the active document canvas (`UI-002`, `UI-005`, `UI-006`).
    public var activeHighlightProjection: EditorHighlightProjection {
        EditorHighlightProjection.evaluate(
            text: activeDocumentSession?.text ?? "",
            caretLocation: currentSelection.location,
            bracketResult: bracketResult,
            backtickResult: backtickResult
        )
    }

    /// Synchronizes live macOS system dark/light appearance and refreshes `palette` dynamically when in `.auto` mode without reloading buffers (`UI-003`).
    public func updateSystemColorScheme(prefersDark: Bool) {
        guard appearanceMode == .auto else { return }
        systemPrefersDark = prefersDark
        palette = PurpleThemePalette.resolve(
            appearance: appearanceMode,
            systemPrefersDark: systemPrefersDark,
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast
        )
    }

    /// Re-reads the unmasked macOS interface style via `systemDarkDetector` and updates `palette` when in `.auto` mode (`UI-003`).
    public func refreshUnmaskedSystemAppearance() {
        systemPrefersDark = systemDarkDetector()
        if appearanceMode == .auto {
            palette = PurpleThemePalette.resolve(
                appearance: appearanceMode,
                systemPrefersDark: systemPrefersDark,
                reduceTransparency: reduceTransparency,
                increasedContrast: increasedContrast
            )
        }
    }

    /// Synchronizes Reduce Transparency and Increased Contrast accessibility flags into `palette` without mutating open buffers (`UI-003`, `UI-009`).
    public func updateAccessibilityPreferences(reduceTransparency: Bool, increasedContrast: Bool) {
        self.reduceTransparency = reduceTransparency
        self.increasedContrast = increasedContrast
        palette = PurpleThemePalette.resolve(
            appearance: appearanceMode,
            systemPrefersDark: systemPrefersDark,
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast
        )
    }

    /// Updates `sidebarWidthRatio` strictly clamped into `0.12...0.65` (`UI-001`).
    public func updateSidebarWidthRatio(_ rawRatio: Double) {
        sidebarWidthRatio = SidebarLayoutGeometry.clampedRatio(rawRatio)
    }

    /// Toggles the manual sidebar `pin` state: unpinning collapses the sidebar, pinning expands it (`UI-001`).
    public func toggleSidebarPinCollapse() {
        isLeftSidebarCollapsed.toggle()
    }

    /// Resolves the target directory for right-click `New File…` / `New Folder…` on either a sidebar entry or empty sidebar background (`BC-012`, `SEC-003`).
    public func resolveSidebarCreationDirectory(for entry: FolderEntryDescriptor?) -> URL? {
        guard let entry else {
            return selectedFolderURL.map { URL(fileURLWithPath: $0.standardizedFileURL.path) }
        }
        if entry.isDirectory {
            return URL(fileURLWithPath: entry.url.standardizedFileURL.path)
        }
        return URL(fileURLWithPath: entry.url.deletingLastPathComponent().standardizedFileURL.path)
    }

    /// Reorders the tab matching `id` one slot left inside its pinned or unpinned partition (`BC-006`, `BC-008`).
    public func moveTabLeft(id: DocumentID) {
        do {
            try tabSession.moveTabLeft(id: id)
            persistRecoveryState()
        } catch {
            statusBannerMessage = "Reorder tab failed: \(error)"
        }
    }

    /// Reorders the tab matching `id` one slot right inside its pinned or unpinned partition (`BC-006`, `BC-008`).
    public func moveTabRight(id: DocumentID) {
        do {
            try tabSession.moveTabRight(id: id)
            persistRecoveryState()
        } catch {
            statusBannerMessage = "Reorder tab failed: \(error)"
        }
    }

    /// Reorders the tab matching `id` to `destinationIndex` inside its pinned or unpinned partition (`BC-006`, `BC-008`).
    public func moveTab(id: DocumentID, toIndex destinationIndex: Int) {
        do {
            try tabSession.moveTab(id: id, toIndex: destinationIndex)
            persistRecoveryState()
        } catch {
            statusBannerMessage = "Reorder tab failed: \(error)"
        }
    }

    /// Evaluates and applies a Markdown smart Enter continuation or empty-marker exit edit atomically on the active document (`BC-004`, `BC-006`).
    /// - Returns: The updated UTF-16 caret offset when smart newline handled the keystroke, or `nil` when standard newline insertion should proceed.
    public func applySmartNewlineIfApplicable(at caretLocation: Int) -> Int? {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly else {
            return nil
        }
        let isMarkdown = MarkdownSmartNewlineEngine.isMarkdownFilename(activeTabTitle)
        guard let smart = MarkdownSmartNewlineEngine.evaluateNewline(
            in: session.snapshot,
            caretLocation: caretLocation,
            isMarkdownDocument: isMarkdown
        ) else {
            return nil
        }
        do {
            _ = try session.applyTextEdits([smart.edit], expectedRevision: session.revision)
            sessionsByID[activeID] = session
            currentSelection = SwiftEditCore.TextRange(location: smart.newCaretLocation, length: 0)
            try? tabSession.updateTabState(
                id: activeID,
                isDirty: session.isDirty,
                caretLocation: smart.newCaretLocation,
                revision: session.revision
            )
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
            return smart.newCaretLocation
        } catch {
            return nil
        }
    }

    public var appearanceMode: AppearanceMode {
        didSet {
            if appearanceMode == .auto {
                systemPrefersDark = systemDarkDetector()
            }
            lastWindowAppearanceTarget = MacOSAppearanceSynchronizer.synchronizeApplicationAppearance(for: appearanceMode)
            palette = PurpleThemePalette.resolve(
                appearance: appearanceMode,
                systemPrefersDark: systemPrefersDark,
                reduceTransparency: reduceTransparency,
                increasedContrast: increasedContrast
            )
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
    /// Transient quarantined binary payload excluded from `sessionsByID` and released immediately on dismiss or tab switch (`BUG-007`, `MEM-002`, `DATA-003`).
    public private(set) var activeBinaryInspection: BinaryInspectionPresentation?
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
    public let undoRegistry = PerTabUndoManagerRegistry()
    private var terminationReplyHandler: (@MainActor (Bool) -> Void)?
    private let fileSystem: any FileSystemProviding
    private let desktopWorkspace: any DesktopWorkspaceIntegrating
    private let loader: DocumentLoader
    private let navigator: DotfileFolderNavigator
    private let batchLoader: ShallowFolderBatchLoader
    private let recentFilesStore: RecentFilesStore
    private let preferencesStore: EditorPreferencesStore
    private let recoveryStore: SessionRecoveryStore
    private let parentPermissionChecker: (URL) -> Bool
    /// Unmasked host OS dark-mode detector consulted on Frame 0 initialization and `.auto` restoration (`UI-003`, `TEST-004`).
    private let systemDarkDetector: @MainActor () -> Bool
    private let savePanelProvider: @MainActor (String) -> URL?
    @ObservationIgnored private var distributedThemeObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var cachedParentNavigation: (folder: URL?, scope: URL?, canNavigate: Bool)?
    @ObservationIgnored private var cachedGutterProjection: (id: DocumentID, revision: BufferRevision, caret: Int, fontSize: Double, value: LineNumberGutterProjection)?
    @ObservationIgnored private var cachedStatusBarMetrics: (id: DocumentID, revision: BufferRevision, caret: Int, value: StatusBarMetricsProjection)?
    @ObservationIgnored private var cachedPreviewSourceLine: (id: DocumentID, revision: BufferRevision, caret: Int, value: Int)?
    @ObservationIgnored private var cachedVisibleLint: (diagnostics: [MarkdownLintDiagnostic], caretLine: Int, visible: [MarkdownLintDiagnostic], severityByLine: [Int: MarkdownLintSeverity])?
    @ObservationIgnored private var lastPersistedRecoveryRevisions: [DocumentID: BufferRevision] = [:]

    public init(
        preferencesSuiteName: String? = nil,
        recentFilesSuiteName: String? = nil,
        preferencesStore: (any PreferencesProviding)? = nil,
        recentFilesStore: (any PreferencesProviding)? = nil,
        recoveryDirectoryURL: URL? = nil,
        fileSystem: any FileSystemProviding = LocalFileSystemAdapter(),
        bookmarkCoder: any SecurityScopedBookmarkCoding = SystemSecurityScopedBookmarkCoder(),
        desktopWorkspace: any DesktopWorkspaceIntegrating = MacOSWorkspaceAdapter(),
        parentPermissionChecker: @escaping (URL) -> Bool = DotfileFolderNavigator.isDirectoryReadable,
        systemDarkDetector: @escaping @MainActor () -> Bool = {
            MacOSAppearanceSynchronizer.readUnmaskedSystemPrefersDark()
        },
        savePanelProvider: @escaping @MainActor (String) -> URL? = { suggestedName in
            let panel = NSSavePanel()
            panel.nameFieldStringValue = suggestedName
            return panel.runModal() == .OK ? panel.url : nil
        }
    ) {
        self.fileSystem = fileSystem
        self.desktopWorkspace = desktopWorkspace
        self.loader = DocumentLoader(fileSystem: fileSystem)
        let nav = DotfileFolderNavigator(fileSystem: fileSystem)
        self.navigator = nav
        self.batchLoader = ShallowFolderBatchLoader(navigator: nav, fileSystem: fileSystem)
        let resolvedRecentStore: any PreferencesProviding = recentFilesStore
            ?? UserDefaultsPreferencesStore(suiteName: recentFilesSuiteName)
        self.recentFilesStore = RecentFilesStore(
            store: resolvedRecentStore,
            fileSystem: fileSystem,
            bookmarkCoder: bookmarkCoder
        )
        self.parentPermissionChecker = parentPermissionChecker
        self.systemDarkDetector = systemDarkDetector
        self.savePanelProvider = savePanelProvider
        let resolvedPrefsStore: any PreferencesProviding = preferencesStore
            ?? UserDefaultsPreferencesStore(suiteName: preferencesSuiteName)
        self.preferencesStore = EditorPreferencesStore(store: resolvedPrefsStore)
        let prefs = self.preferencesStore.load()
        let initialSystemDark = systemDarkDetector()
        self.systemPrefersDark = initialSystemDark
        self.appearanceMode = prefs.appearanceMode
        self.lastWindowAppearanceTarget = MacOSAppearanceSynchronizer.synchronizeApplicationAppearance(for: prefs.appearanceMode)
        self.palette = PurpleThemePalette.resolve(
            appearance: prefs.appearanceMode,
            systemPrefersDark: initialSystemDark
        )
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
        recentFiles = self.recentFilesStore.entries()
        refreshDiagnosticsForActiveDocument()

        distributedThemeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshUnmaskedSystemAppearance()
            }
        }
    }

    isolated deinit {
        diagnosticsTask?.cancel()
        recoveryDebounceTask?.cancel()
        undoRegistry.removeAll()
        bracketTopologyCache = nil
        backtickCache = nil
        previewCache = nil
        diffCoordinator.clear()
        PreviewThumbnailCache.shared.clear()
        if let observer = distributedThemeObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    public var activeDocumentSession: DocumentSession? {
        if let bin = activeBinaryInspection {
            return DocumentSession(
                id: bin.id,
                fileURL: bin.fileURL,
                revision: bin.snapshot.revision,
                text: bin.snapshot.text,
                encoding: bin.snapshot.encoding,
                lineEnding: bin.snapshot.lineEnding,
                isDirty: false,
                isDegradedPlainText: bin.snapshot.isDegradedPlainText,
                isBinaryReadOnly: true
            )
        }
        guard let activeID = tabSession.activeTabID else { return nil }
        return sessionsByID[activeID]
    }

    public var activeLineNumberGutter: LineNumberGutterProjection {
        let fontSize = zoomController.scaledFontSizePoints
        let caret = currentSelection.location
        guard let session = activeDocumentSession else {
            return LineNumberGutterProjection.evaluate(text: "", caretLocation: caret, fontSizePoints: fontSize)
        }
        if let cached = cachedGutterProjection,
           cached.id == session.id,
           cached.revision == session.revision,
           cached.caret == caret,
           cached.fontSize == fontSize {
            return cached.value
        }
        let value = LineNumberGutterProjection.evaluate(
            text: session.text,
            caretLocation: caret,
            fontSizePoints: fontSize
        )
        cachedGutterProjection = (session.id, session.revision, caret, fontSize, value)
        return value
    }

    public var activeStatusBarMetrics: StatusBarMetricsProjection {
        let caret = currentSelection.location
        guard let session = activeDocumentSession else {
            return StatusBarMetricsProjection.evaluate(snapshot: DocumentSession(text: "").snapshot, caretLocation: caret)
        }
        if let cached = cachedStatusBarMetrics,
           cached.id == session.id,
           cached.revision == session.revision,
           cached.caret == caret {
            return cached.value
        }
        let value = StatusBarMetricsProjection.evaluate(
            snapshot: session.snapshot,
            caretLocation: caret
        )
        cachedStatusBarMetrics = (session.id, session.revision, caret, value)
        return value
    }

    /// Returns `true` when `selectedFolderURL` is not `"/"` and the parent folder (`...`) is within `grantedScopeRootURL` or readable under active user permissions (`UI-001`, `BC-007`).
    public var canNavigateToParentFolder: Bool {
        guard let currentFolder = selectedFolderURL else { return false }
        if let cached = cachedParentNavigation,
           cached.folder == currentFolder,
           cached.scope == grantedScopeRootURL {
            return cached.canNavigate
        }
        let resolved = try? navigator.resolveParentDirectory(
            from: currentFolder,
            withinScope: grantedScopeRootURL,
            isParentReadable: parentPermissionChecker
        )
        let result = resolved != nil
        cachedParentNavigation = (currentFolder, grantedScopeRootURL, result)
        return result
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
        if let bin = activeBinaryInspection {
            return bin.title
        }
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

    /// Refreshes shallow workspace entries using `.skipAndReport` so one external symlink never hides valid siblings while folder-root escape remains fail-closed (`BUG-017`, `SEC-003`).
    public func refreshFolderEntries() {
        cachedParentNavigation = nil
        guard let folderURL = selectedFolderURL else { return }
        let scope = grantedScopeRootURL ?? folderURL
        do {
            let listing = try navigator.listEntriesWithDiagnostics(
                in: folderURL,
                withinScope: scope,
                symlinkPolicy: .skipAndReport
            )
            folderEntries = listing.entries
            statusBannerMessage = listing.skippedExternalSymlinkCount > 0
                ? "Skipped \(listing.skippedExternalSymlinkCount) external symlink(s) outside workspace scope."
                : nil
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
        guard !entry.isBinary else {
            return
        }
        openFile(at: entry.url, withinScope: grantedScopeRootURL ?? selectedFolderURL)
    }

    public func openFile(at url: URL, withinScope scope: URL?) {
        asyncOpenGeneration &+= 1
        let standardizedURL = url.standardizedFileURL
        if activateExistingOrBinaryIfPresent(at: standardizedURL, withinScope: scope) {
            return
        }
        do {
            let loaded = try loader.load(from: standardizedURL, withinScope: scope)
            try completeOpenLoadedSession(loaded, at: standardizedURL, withinScope: scope)
        } catch {
            statusBannerMessage = "Open failed: \(error)"
        }
    }

    /// Asynchronously opens `url` within `scope`, enforcing `64 MiB` fail-fast size checks before any payload read, offloading `>= 2 MiB` decoding off `@MainActor`, and discarding superseded completions if another tab opens or activates mid-flight (`PERF-004`, `CWE-400`, `REQ-004/N7`).
    public func openFileAsync(at url: URL, withinScope scope: URL?) async {
        asyncOpenGeneration &+= 1
        let expectedGeneration = asyncOpenGeneration
        let standardizedURL = url.standardizedFileURL
        if activateExistingOrBinaryIfPresent(at: standardizedURL, withinScope: scope) {
            return
        }
        do {
            let attrs = try fileSystem.fileAttributes(at: standardizedURL, withinScope: scope)
            if attrs.byteSize > DocumentLoader.maxAllowedFileBytes {
                throw DomainError.fileTooLarge(byteCount: attrs.byteSize)
            }
            let loaded: DocumentSession
            if attrs.byteSize >= Self.asyncFileLoadThresholdBytes {
                let loaderCopy = loader
                loaded = try await Task.detached(priority: .userInitiated) {
                    try loaderCopy.load(from: standardizedURL, withinScope: scope)
                }.value
                guard asyncOpenGeneration == expectedGeneration, !Task.isCancelled else {
                    return
                }
            } else {
                loaded = try loader.load(from: standardizedURL, withinScope: scope)
            }
            try completeOpenLoadedSession(loaded, at: standardizedURL, withinScope: scope)
        } catch {
            if asyncOpenGeneration == expectedGeneration {
                statusBannerMessage = "Open failed: \(error)"
            }
        }
    }

    private func activateExistingOrBinaryIfPresent(at standardizedURL: URL, withinScope scope: URL?) -> Bool {
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

    private func completeOpenLoadedSession(_ loaded: DocumentSession, at standardizedURL: URL, withinScope scope: URL?) throws {
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
            previewCache = nil
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

    /// Dismisses transient binary read-only inspection, releasing the inspection buffer immediately and restoring the underlying active tab (`BUG-007`, `MEM-002`).
    public func dismissBinaryInspection() {
        asyncOpenGeneration &+= 1
        guard let bin = activeBinaryInspection else { return }
        activeBinaryInspection = nil
        undoRegistry.removeUndoManager(for: bin.id)
        currentSelection = SwiftEditCore.TextRange(location: 0, length: 0)
        programmaticSelectionToken += 1
        statusBannerMessage = nil
        refreshDiagnosticsForActiveDocument()
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
        asyncOpenGeneration &+= 1
        activeBinaryInspection = nil
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
        asyncOpenGeneration &+= 1
        activeBinaryInspection = nil
        try? tabSession.activateTab(id: id)
        currentSelection = SwiftEditCore.TextRange(location: 0, length: 0)
        persistRecoveryState()
        refreshDiagnosticsForActiveDocument()
    }

    public func togglePin(id: DocumentID) {
        guard id != activeBinaryInspection?.id,
              let tab = tabSession.tabs.first(where: { $0.id == id }) else { return }
        try? tabSession.setPinned(!tab.isPinned, for: id)
        persistRecoveryState()
    }

    public func closeTab(id: DocumentID) {
        asyncOpenGeneration &+= 1
        do {
            _ = try tabSession.closeTab(id: id)
            sessionsByID.removeValue(forKey: id)
            savedBaselineByID.removeValue(forKey: id)
            undoRegistry.removeUndoManager(for: id)
            if bracketTopologyCache?.id == id { bracketTopologyCache = nil }
            if backtickCache?.id == id { backtickCache = nil }
            if previewCache?.id == id { previewCache = nil }
            if tabSession.tabs.isEmpty {
                diagnosticsTask?.cancel()
                diffCoordinator.clear()
                PreviewThumbnailCache.shared.clear()
            }
            try? recoveryStore.removeRecoverySnapshot(for: id)
            lastPersistedRecoveryRevisions.removeValue(forKey: id)
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch DomainError.pinnedTabCloseForbidden {
            statusBannerMessage = "Pinned tab cannot be closed. Unpin it first."
        } catch {
            statusBannerMessage = "Close failed: \(error)"
        }
    }

    public func handleEditorTextChanged(_ newText: String) {
        guard activeBinaryInspection == nil,
              let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly,
              (try? session.replaceFullTextIfChanged(newText)) == true else { return }
        sessionsByID[activeID] = session
        try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
        scheduleRecoveryPersist()
        refreshDiagnosticsForActiveDocument()
    }

    public func handleSelectionChanged(_ range: SwiftEditCore.TextRange) {
        currentSelection = range
        guard let session = activeDocumentSession else { return }
        if let cached = bracketTopologyCache, cached.id == session.id, cached.revision == session.revision {
            bracketResult = SearchDiffAndBracketEngine.balanceResult(from: cached.topology, caretLocation: range.location)
        } else if session.text.utf8.count <= Self.syncDiagnosticThresholdUTF8 {
            if let topology = SearchDiffAndBracketEngine.scanTopology(in: session.snapshot).completedValue {
                bracketTopologyCache = (session.id, session.revision, topology)
                bracketResult = SearchDiffAndBracketEngine.balanceResult(from: topology, caretLocation: range.location)
            } else {
                bracketResult = nil
            }
        }
        try? tabSession.updateTabState(id: session.id, caretLocation: range.location)
    }

    public func performCommandD() {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID] else { return }
        guard !session.isBinaryReadOnly, safetyBanner.canSave else {
            statusBannerMessage = "Duplicate blocked: binary read-only file."
            return
        }
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
        guard !session.isBinaryReadOnly, safetyBanner.canFormat else {
            statusBannerMessage = "Format blocked: binary read-only file."
            return
        }
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
        guard !session.isBinaryReadOnly, safetyBanner.canSave else {
            statusBannerMessage = "Save blocked: binary read-only file."
            return
        }

        let targetURL: URL
        if let existingURL = session.fileURL {
            targetURL = existingURL
        } else {
            guard let chosen = savePanelProvider(activeTabTitle) else { return }
            targetURL = chosen
        }
        saveDocument(to: targetURL)
    }

    /// Prompts for a destination via the injected save-panel seam and saves the active document there; rejected fail-closed on binary read-only buffers before any panel is shown (`DATA-003`, `UI-008`).
    public func saveActiveDocumentAsViaPanel() {
        guard let session = activeDocumentSession else { return }
        guard !session.isBinaryReadOnly, safetyBanner.canSave else {
            statusBannerMessage = "Save As blocked: binary read-only file."
            return
        }
        guard let chosen = savePanelProvider(activeTabTitle) else { return }
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
            lastPersistedRecoveryRevisions.removeValue(forKey: activeID)
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

    /// Refreshes lint, bracket topology, backticks, safety banner, and diff state: synchronous below `4096` UTF-8 bytes, off-`@MainActor` with `(DocumentID, BufferRevision)` race protection above `4096` (`PERF-002`, `PERF-006`, `N11`).
    public func refreshDiagnosticsForActiveDocument() {
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        guard let session = activeDocumentSession else {
            lintDiagnostics = []
            bracketResult = nil
            backtickResult = nil
            return
        }
        let snap = session.snapshot
        let caret = currentSelection.location
        let isMarkdown = MarkdownSmartNewlineEngine.isMarkdownFilename(activeTabTitle)

        if snap.text.utf8.count <= Self.syncDiagnosticThresholdUTF8 {
            safetyBanner = InspectionSafetyBannerState.evaluate(snapshot: snap)
            if isMarkdown {
                lintDiagnostics = MarkdownLintAndFormatEngine.lint(snapshot: snap, profile: .allConstructs).completedValue?.diagnostics ?? []
            } else {
                lintDiagnostics = []
            }
            if case .off = activeLintStatus { isDiagnosticsPopoverPresented = false }
            if let topology = SearchDiffAndBracketEngine.scanTopology(in: snap).completedValue {
                bracketTopologyCache = (snap.id, snap.revision, topology)
                bracketResult = SearchDiffAndBracketEngine.balanceResult(from: topology, caretLocation: caret)
            } else {
                bracketTopologyCache = nil
                bracketResult = nil
            }
            let backticks = BacktickHighlightScanner.scan(in: snap).completedValue
            backtickCache = (snap.id, snap.revision, backticks)
            backtickResult = backticks
            if showDiffPane, let baseline = savedBaselineByID[session.id] {
                diffCoordinator.compare(lhs: baseline, rhs: snap)
            }
            return
        }

        safetyBanner = InspectionSafetyBannerState(
            isBinaryReadOnlyBannerVisible: snap.isBinaryReadOnly,
            canSave: !snap.isBinaryReadOnly,
            canFormat: !snap.isBinaryReadOnly && !snap.isDegradedPlainText,
            canPinTab: !snap.isBinaryReadOnly,
            bidiWarnings: safetyBanner.bidiWarnings
        )
        if let cached = bracketTopologyCache, cached.id == snap.id, cached.revision == snap.revision {
            bracketResult = SearchDiffAndBracketEngine.balanceResult(from: cached.topology, caretLocation: caret)
        }
        if !isMarkdown {
            lintDiagnostics = []
            isDiagnosticsPopoverPresented = false
        }

        let targetID = snap.id
        let targetRevision = snap.revision
        diagnosticsTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) { () -> (lint: [MarkdownLintDiagnostic], topology: BracketTopology?, backticks: BacktickHighlightResult?, safety: InspectionSafetyBannerState)? in
                guard !Task.isCancelled else { return nil }
                let safety = InspectionSafetyBannerState.evaluate(snapshot: snap)
                guard !Task.isCancelled else { return nil }
                let lint: [MarkdownLintDiagnostic]
                if isMarkdown {
                    switch MarkdownLintAndFormatEngine.lint(snapshot: snap, profile: .allConstructs) {
                    case .completed(let result):
                        lint = result.diagnostics
                    case .degradedOrTimedOut(.deadlineExceeded):
                        guard !Task.isCancelled else { return nil }
                        lint = MarkdownLintAndFormatEngine.lintSecurityFastPath(snapshot: snap).completedValue?.diagnostics ?? []
                    case .degradedOrTimedOut:
                        lint = []
                    }
                } else {
                    lint = []
                }
                guard !Task.isCancelled else { return nil }
                let topology = SearchDiffAndBracketEngine.scanTopology(in: snap).completedValue
                guard !Task.isCancelled else { return nil }
                let backticks = BacktickHighlightScanner.scan(in: snap).completedValue
                return (lint, topology, backticks, safety)
            }
            let computed = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard let self,
                  let computed,
                  !Task.isCancelled,
                  let current = self.activeDocumentSession,
                  current.id == targetID,
                  current.revision == targetRevision else {
                return
            }
            self.safetyBanner = computed.safety
            self.lintDiagnostics = computed.lint
            if case .off = self.activeLintStatus { self.isDiagnosticsPopoverPresented = false }
            if let topology = computed.topology {
                self.bracketTopologyCache = (targetID, targetRevision, topology)
                self.bracketResult = SearchDiffAndBracketEngine.balanceResult(from: topology, caretLocation: self.currentSelection.location)
            } else {
                self.bracketTopologyCache = nil
                self.bracketResult = nil
            }
            self.backtickCache = (targetID, targetRevision, computed.backticks)
            self.backtickResult = computed.backticks
        }
        if showDiffPane, let baseline = savedBaselineByID[session.id] {
            diffCoordinator.compare(lhs: baseline, rhs: snap)
        }
    }

    /// Awaits any in-flight background diagnostic pass for deterministic verification (`PERF-006`, `N11`).
    public func awaitPendingDiagnostics() async {
        await diagnosticsTask?.value
    }

    /// Presents or hides the inline Find / Find & Replace / Go-to-Line bar (`Cmd+F`, `Opt+Cmd+F`, `Cmd+G`), restoring editor focus when hidden (`BUG-009`).
    public func presentFindBar(mode: FindBarPresentationMode) {
        findReplaceState.mode = mode
        if mode == .hidden {
            requestEditorFocus()
        }
    }

    /// Requests first-responder restoration onto the active `SwiftEditNSTextView` after dismissing modal chrome or bars (`BUG-009`).
    public func requestEditorFocus() {
        editorFocusRequestToken += 1
    }

    private func applyProgrammaticSelection(_ range: SwiftEditCore.TextRange, focusEditor: Bool) {
        handleSelectionChanged(range)
        programmaticSelectionToken += 1
        if focusEditor {
            requestEditorFocus()
        }
    }

    /// Evaluates literal search matches for `findReplaceState.query` in the active document and selects the first match (`BC-004`, `BC-011`, `BUG-008`).
    public func executeFind() {
        guard let session = activeDocumentSession else { return }
        let options = SearchOptions(isCaseSensitive: findReplaceState.isCaseSensitive)
        switch DocumentSearchEngine.find(query: findReplaceState.query, in: session.snapshot, options: options) {
        case .completed(let ranges):
            findReplaceState.matches = ranges
            findReplaceState.activeMatchIndex = 0
            if let first = ranges.first {
                applyProgrammaticSelection(first, focusEditor: false)
            }
            statusBannerMessage = nil
        case .degradedOrTimedOut(let reason):
            findReplaceState.matches = []
            statusBannerMessage = "Search skipped: \(reason)"
        }
    }

    /// Selects the next literal match in `findReplaceState.matches` (`BUG-008`).
    public func findNextMatch() {
        if let next = findReplaceState.selectNextMatch() {
            applyProgrammaticSelection(next, focusEditor: false)
        }
    }

    /// Selects the previous literal match in `findReplaceState.matches` (`BUG-008`).
    public func findPreviousMatch() {
        if let previous = findReplaceState.selectPreviousMatch() {
            applyProgrammaticSelection(previous, focusEditor: false)
        }
    }

    /// Replaces the currently selected match in one `BufferRevision` step and re-runs `Find` to highlight the next occurrence (`BUG-009`).
    public func executeReplaceSingle() {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly,
              !findReplaceState.query.isEmpty,
              !findReplaceState.matches.isEmpty else { return }
        let idx = min(max(0, findReplaceState.activeMatchIndex), findReplaceState.matches.count - 1)
        let targetRange = findReplaceState.matches[idx]
        let edit = TextEdit(range: targetRange, replacement: findReplaceState.replacement)
        do {
            let expectedRev = session.revision
            _ = try session.applyTextEdits([edit], expectedRevision: expectedRev)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            let replacedSelection = SwiftEditCore.TextRange(
                location: targetRange.location,
                length: (findReplaceState.replacement as NSString).length
            )
            applyProgrammaticSelection(replacedSelection, focusEditor: false)
            statusBannerMessage = "Replaced 1 occurrence."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
            executeFind()
        } catch {
            statusBannerMessage = "Replace failed: \(error)"
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

    /// Moves the selection to the 1-based line parsed from `findReplaceState.goToLineText` (`Cmd+G`, `BUG-008`).
    public func executeGoToLine() {
        guard let session = activeDocumentSession,
              let targetLine = Int(findReplaceState.goToLineText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let range = DocumentSearchEngine.goToLine(targetLine, in: session.snapshot) else {
            statusBannerMessage = "Line number out of range."
            return
        }
        applyProgrammaticSelection(range, focusEditor: true)
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
            completeTerminationPrompt(allowQuit: false)
        case .dontSave:
            for id in tabSession.tabs.map(\.id) {
                _ = try? tabSession.closeTab(id: id, forcePinned: true)
                sessionsByID.removeValue(forKey: id)
                savedBaselineByID.removeValue(forKey: id)
                undoRegistry.removeUndoManager(for: id)
                try? recoveryStore.removeRecoverySnapshot(for: id)
            }
            isPendingTerminationPrompt = false
            pendingDirtyCloseTabID = nil
            persistRecoveryState()
            completeTerminationPrompt(allowQuit: true)
        case .save:
            if let targetID = pendingDirtyCloseTabID {
                activateTab(id: targetID)
                saveActiveDocument()
                if sessionsByID[targetID]?.isDirty == true {
                    isPendingTerminationPrompt = false
                    pendingDirtyCloseTabID = nil
                    completeTerminationPrompt(allowQuit: false)
                    return
                }
            }
            if let nextDirty = tabSession.tabs.first(where: \.isDirty) {
                pendingDirtyCloseTabID = nextDirty.id
                isPendingTerminationPrompt = true
                return
            }
            isPendingTerminationPrompt = false
            pendingDirtyCloseTabID = nil
            persistRecoveryState()
            completeTerminationPrompt(allowQuit: true)
        }
    }

    private func completeTerminationPrompt(allowQuit: Bool) {
        let handler = terminationReplyHandler
        terminationReplyHandler = nil
        handler?(allowQuit)
    }

    /// Returns `true` when the application may terminate immediately, or `false` while staging sequential dirty-tab prompts (`Cmd+Q`) (`BUG-003`, `BUG-010`).
    public func requestApplicationTermination(reply: (@MainActor (Bool) -> Void)? = nil) -> Bool {
        if let firstDirty = tabSession.tabs.first(where: \.isDirty) {
            terminationReplyHandler = reply
            pendingDirtyCloseTabID = firstDirty.id
            isPendingTerminationPrompt = true
            return false
        }
        terminationReplyHandler = nil
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

    /// Evaluates `Tab` (`outdent == false`) or `Shift+Tab` for the active tab without mutating it; binary read-only, quarantined, and non-Markdown tabs are `.notApplicable` (`DATA-003`, `SEC-012`).
    public func listIndentationOutcome(outdent: Bool) -> SmartListOutcome {
        guard let session = activeDocumentSession, !session.isBinaryReadOnly, safetyBanner.canSave else {
            return .notApplicable
        }
        return MarkdownSmartListEngine.evaluateIndent(
            in: session.snapshot,
            selection: currentSelection,
            outdent: outdent,
            isMarkdownDocument: MarkdownSmartNewlineEngine.isMarkdownFilename(activeTabTitle)
        )
    }

    /// Applies list indentation to the active session as exactly one `BufferRevision` and translates `currentSelection`.
    ///
    /// The editor view applies the same outcome through `NSTextView.insertText` to keep a single native undo step; this model-level path serves headless callers and tests.
    /// - Returns: `true` when the key was consumed (edit applied or safe no-op), `false` when default handling should proceed.
    @discardableResult
    public func applyListIndentation(outdent: Bool) -> Bool {
        switch listIndentationOutcome(outdent: outdent) {
        case .notApplicable:
            return false
        case .consumedNoOp:
            return true
        case .edit(let listEdit):
            guard let activeID = tabSession.activeTabID, var session = sessionsByID[activeID] else { return false }
            do {
                _ = try session.applyTextEdits(listEdit.edits, expectedRevision: session.revision)
                sessionsByID[activeID] = session
                try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
                currentSelection = listEdit.newSelection
                persistRecoveryState()
                refreshDiagnosticsForActiveDocument()
                return true
            } catch {
                statusBannerMessage = "List indentation failed: \(error)"
                return true
            }
        }
    }

    private static let syncDiagnosticThresholdUTF8: Int = 4_096
    private static let asyncFileLoadThresholdBytes: UInt64 = 2 * 1024 * 1024
    /// Debounce window for per-keystroke `SessionRecovery` writes; tab switch, close, and other lifecycle events flush immediately (`UI-012`, `DATA-005`).
    public var recoveryDebounceNanoseconds: UInt64 = 500_000_000
    @ObservationIgnored private var recoveryDebounceTask: Task<Void, Never>?
    @ObservationIgnored private var diagnosticsTask: Task<Void, Never>?
    @ObservationIgnored private var asyncOpenGeneration: UInt64 = 0
    @ObservationIgnored private var bracketTopologyCache: (id: DocumentID, revision: BufferRevision, topology: BracketTopology)?
    @ObservationIgnored private var backtickCache: (id: DocumentID, revision: BufferRevision, result: BacktickHighlightResult?)?
    @ObservationIgnored private var previewCache: (id: DocumentID, revision: BufferRevision, document: GFMPreviewDocument?)?

    /// Monotonic token bumped whenever the model requests a caret/selection the editor view must adopt (`currentSelection`).
    public var programmaticSelectionToken: Int = 0
    /// Monotonic token bumped whenever dismissing bars, sheets, Navigator, or Distraction-Free requires returning focus to `SwiftEditNSTextView` (`BUG-009`).
    public private(set) var editorFocusRequestToken: Int = 0

    // MARK: Document navigator & distraction-free (014)

    /// Open navigator palette state; `nil` while closed (nothing is parsed or retained when closed).
    public var navigatorState: DocumentNavigatorState?
    /// `true` while only the active editor is visible in full screen.
    public var isDistractionFree: Bool = false
    private var fullScreenWasActiveBeforeDistractionFree = false
    /// Window seams injected by the root view (kept closures so the model stays AppKit-free and testable).
    @ObservationIgnored public var windowFullScreenQuery: () -> Bool = { false }
    @ObservationIgnored public var windowFullScreenToggle: () -> Void = {}

    /// `Option+\`: toggles the heading navigator of the active non-binary Markdown tab only.
    public func toggleDocumentNavigator() {
        if navigatorState != nil { closeDocumentNavigator(); return }
        guard isMarkdownMenuEnabled, let session = activeDocumentSession else { return }
        navigatorState = DocumentNavigatorState(headings: MarkdownHeadingOutlineEngine.outline(for: session.text))
    }

    public func closeDocumentNavigator() {
        navigatorState = nil
        requestEditorFocus()
    }

    /// Jumps the caret to the selected heading (clamped to the current text) and closes the navigator, returning focus to the editor.
    public func confirmDocumentNavigator() {
        defer { navigatorState = nil }
        guard let state = navigatorState, let session = activeDocumentSession,
              let offset = state.confirm(documentLength: session.text.utf16.count) else {
            requestEditorFocus()
            return
        }
        applyProgrammaticSelection(SwiftEditCore.TextRange(location: offset, length: 0), focusEditor: true)
    }

    /// `Option+1`: enters or leaves distraction-free mode; full screen is toggled only when the state differs.
    public func toggleDistractionFree() {
        if isDistractionFree {
            isDistractionFree = false
            if !fullScreenWasActiveBeforeDistractionFree, windowFullScreenQuery() { windowFullScreenToggle() }
            requestEditorFocus()
        } else {
            fullScreenWasActiveBeforeDistractionFree = windowFullScreenQuery()
            isDistractionFree = true
            navigatorState = nil
            if !fullScreenWasActiveBeforeDistractionFree { windowFullScreenToggle() }
        }
    }

    /// Resyncs the flag when the user leaves full screen with the system control.
    public func windowDidExitFullScreen() {
        isDistractionFree = false
        requestEditorFocus()
    }

    /// Dismisses the header submenu overlay and restores editor focus cleanly (`BUG-006`, `BUG-009`).
    public func dismissHeaderSubmenu() {
        headerSubmenu.escapePressed()
        requestEditorFocus()
    }

    /// ESC layering: header submenu first, then navigator, then distraction-free. Returns `true` when consumed.
    @discardableResult
    public func handleEscape() -> Bool {
        if headerSubmenu.isOpen { dismissHeaderSubmenu(); return true }
        if navigatorState != nil { closeDocumentNavigator(); return true }
        if isDistractionFree { toggleDistractionFree(); return true }
        return false
    }

    /// `true` only for a writable, non-binary Markdown tab; gates the `Markdown` menu, table `Tab`, and preview (`DATA-003`, `UI-005`).
    public var isMarkdownMenuEnabled: Bool {
        guard let session = activeDocumentSession, !session.isBinaryReadOnly, safetyBanner.canSave else { return false }
        return MarkdownSmartNewlineEngine.isMarkdownFilename(activeTabTitle)
    }

    /// Preview projection for the active tab; `nil` (zero work) while `showMarkdownPreview == false` or on binary and non-Markdown tabs (`SEC-004`, `SEC-012`).
    public var markdownPreviewDocument: GFMPreviewDocument? {
        guard showMarkdownPreview, isMarkdownMenuEnabled, let session = activeDocumentSession else { return nil }
        if let cache = previewCache, cache.id == session.id, cache.revision == session.revision { return cache.document }
        let document = MarkdownPreviewProjector.project(snapshot: session.snapshot, showPreview: true)
        previewCache = (session.id, session.revision, document)
        return document
    }

    /// 1-based source line of the caret counting `\r\n`, `\n`, and `\r`, cached per `(DocumentID, BufferRevision, caretLocation)` and used as the single scroll driver of the preview (`BUG-016`, `UI-007`).
    public var previewSourceLine: Int {
        guard let session = activeDocumentSession else { return 0 }
        let caret = currentSelection.location
        if let cached = cachedPreviewSourceLine,
           cached.id == session.id,
           cached.revision == session.revision,
           cached.caret == caret {
            return cached.value
        }
        let line: Int
        if let fast = session.text.utf8.withContiguousStorageIfAvailable({ buf -> Int in
            guard let base = buf.baseAddress, !buf.isEmpty, caret > 0 else { return 1 }
            let count = buf.count
            var currentLine = 1
            var utf16Offset = 0
            var i = 0
            while i < count && utf16Offset < caret {
                let b = base[i]
                if b == 0x0A {
                    currentLine += 1
                    utf16Offset += 1
                    i += 1
                } else if b == 0x0D {
                    currentLine += 1
                    if i + 1 < count && base[i + 1] == 0x0A && utf16Offset + 1 < caret {
                        utf16Offset += 2
                        i += 2
                    } else {
                        utf16Offset += 1
                        i += 1
                    }
                } else if b < 0x80 {
                    utf16Offset += 1
                    i += 1
                } else if b < 0xE0 {
                    utf16Offset += 1
                    i += 2
                } else if b < 0xF0 {
                    utf16Offset += 1
                    i += 3
                } else {
                    utf16Offset += 2
                    i += 4
                }
            }
            return currentLine
        }) {
            line = fast
        } else {
            let units = session.text.utf16
            let limit = min(max(0, caret), units.count)
            var currentLine = 1
            var idx = units.startIndex
            var offset = 0
            while idx < units.endIndex, offset < limit {
                let u = units[idx]
                if u == 0x0A {
                    currentLine += 1
                    idx = units.index(after: idx)
                    offset += 1
                } else if u == 0x0D {
                    currentLine += 1
                    let next = units.index(after: idx)
                    if next < units.endIndex, units[next] == 0x0A, offset + 1 < limit {
                        idx = units.index(after: next)
                        offset += 2
                    } else {
                        idx = next
                        offset += 1
                    }
                } else {
                    idx = units.index(after: idx)
                    offset += 1
                }
            }
            line = currentLine
        }
        cachedPreviewSourceLine = (session.id, session.revision, caret, line)
        return line
    }

    /// Image and link gate bound to the active file's directory and the granted workspace scope; `nil` (all images blocked) for unsaved tabs or without a granted folder (`SEC-002`, `SEC-003`).
    public var previewResourceGate: PreviewResourceAndLinkGate? {
        guard let scope = grantedScopeRootURL, let fileURL = activeDocumentSession?.fileURL else { return nil }
        return PreviewResourceAndLinkGate(fileSystem: fileSystem, scopeRoot: scope, documentDirectory: fileURL.deletingLastPathComponent())
    }

    /// Whether the `⇧⌘M` diagnostics popover is shown; only presentable while lint is active for the tab (`UI-005`).
    public var isDiagnosticsPopoverPresented = false

    /// Status-bar lint state: Off for non-Markdown and binary tabs, Paused for degraded buffers, Active otherwise (`DATA-003`).
    public var activeLintStatus: ActiveLintStatus {
        guard let session = activeDocumentSession else { return .off }
        return ActiveLintStatus.classify(
            isMarkdownDocument: MarkdownSmartNewlineEngine.isMarkdownFilename(activeTabTitle),
            snapshot: session.snapshot,
            diagnosticCount: lintDiagnostics.count
        )
    }

    private func resolvedVisibleLintCache() -> (visible: [MarkdownLintDiagnostic], severityByLine: [Int: MarkdownLintSeverity]) {
        let caretLine = previewSourceLine
        let current = lintDiagnostics
        if let cached = cachedVisibleLint, cached.caretLine == caretLine, cached.diagnostics == current {
            return (cached.visible, cached.severityByLine)
        }
        let visible = ActiveLineLintSuppressionPolicy.visibleDiagnostics(current, caretLine: caretLine)
        var severityByLine: [Int: MarkdownLintSeverity] = Dictionary(minimumCapacity: visible.count)
        for d in visible where severityByLine[d.line] != .error {
            severityByLine[d.line] = d.severity
        }
        cachedVisibleLint = (current, caretLine, visible, severityByLine)
        return (visible, severityByLine)
    }

    /// Diagnostics for inline underlines and gutter badges after active-line suppression of transient warnings (security errors always remain).
    public var visibleLintDiagnostics: [MarkdownLintDiagnostic] {
        resolvedVisibleLintCache().visible
    }

    /// Worst severity per 1-based line (errors win) for gutter badges, built once per `(lintDiagnostics, caretLine)`.
    public var gutterSeverityByLine: [Int: MarkdownLintSeverity] {
        resolvedVisibleLintCache().severityByLine
    }

    /// Toggles the diagnostics popover (`⇧⌘M`); ignored while lint is Off or Paused.
    public func toggleDiagnosticsPopover() {
        guard case .active = activeLintStatus else { isDiagnosticsPopoverPresented = false; return }
        isDiagnosticsPopoverPresented.toggle()
    }

    /// Moves the selection to `diagnostic.range` (Jump-to-Range) and asks the editor to adopt it.
    public func jumpToDiagnostic(_ diagnostic: MarkdownLintDiagnostic) {
        guard let range = diagnostic.range, let session = activeDocumentSession, range.upperBound <= session.text.utf16.count else { return }
        currentSelection = SwiftEditCore.TextRange(location: range.location, length: 0)
        programmaticSelectionToken += 1
    }

    /// Applies the diagnostic's own `quickFix` as one revision; security diagnostics have none (`SEC-004`).
    @discardableResult
    public func applyQuickFix(_ diagnostic: MarkdownLintDiagnostic) -> Bool {
        guard let fix = diagnostic.quickFix else { return false }
        return applyLintEdit(MarkdownAuthoringEdit(edits: [fix], newSelection: SwiftEditCore.TextRange(location: fix.range.location + (fix.replacement as NSString).length, length: 0)))
    }

    /// Applies the idempotent revision-pinned Fix All as exactly one `BufferRevision` (one `Cmd+Z` step); rejected on stale, binary, degraded or non-Markdown tabs (`CWE-362`, `DATA-003`).
    @discardableResult
    public func applyFixAll() -> Bool {
        guard isMarkdownMenuEnabled, let session = activeDocumentSession else { return false }
        guard case .edit(let edit) = MarkdownQuickFixResolver.fixAll(snapshot: session.snapshot, expectedRevision: session.revision) else { return false }
        return applyLintEdit(edit)
    }

    private func applyLintEdit(_ edit: MarkdownAuthoringEdit) -> Bool {
        guard isMarkdownMenuEnabled, let activeID = tabSession.activeTabID, var session = sessionsByID[activeID] else { return false }
        do {
            _ = try session.applyTextEdits(edit.edits, expectedRevision: session.revision)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            currentSelection = edit.newSelection
            programmaticSelectionToken += 1
            scheduleRecoveryPersist()
            refreshDiagnosticsForActiveDocument()
            return true
        } catch {
            statusBannerMessage = "Lint fix failed: \(error)"
            return false
        }
    }

    /// Evaluates GFM table `Tab` / `Shift+Tab` for the active tab; anything else defers to the list engine (`notApplicable`).
    public func tableTabOutcome(backward: Bool) -> TableEditOutcome {
        guard isMarkdownMenuEnabled, let session = activeDocumentSession else { return .notApplicable }
        return GFMTableEditEngine.evaluateTab(in: session.snapshot, selection: currentSelection, backward: backward, isMarkdownDocument: true)
    }

    /// Applies a `Markdown` menu command as one `BufferRevision` on the active tab; returns `false` (no mutation) when disabled or not applicable (`BC-006`, `DATA-003`).
    @discardableResult
    public func applyMarkdownCommand(_ command: MarkdownAuthoringCommand) -> Bool {
        guard isMarkdownMenuEnabled, let activeID = tabSession.activeTabID, var session = sessionsByID[activeID],
              let edit = MarkdownAuthoringCommands.evaluate(command, in: session.snapshot, selection: currentSelection, isMarkdownDocument: true) else { return false }
        do {
            _ = try session.applyTextEdits(edit.edits, expectedRevision: session.revision)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            currentSelection = edit.newSelection
            programmaticSelectionToken += 1
            scheduleRecoveryPersist()
            refreshDiagnosticsForActiveDocument()
            return true
        } catch {
            statusBannerMessage = "Markdown command failed: \(error)"
            return false
        }
    }

    private func scheduleRecoveryPersist() {
        recoveryDebounceTask?.cancel()
        let delay = recoveryDebounceNanoseconds
        recoveryDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.persistRecoveryState()
        }
    }

    /// Toggles the offline native Markdown preview (`Cmd+P`, default off) and evicts preview + thumbnail caches immediately on hide (`MEM-001`, `SEC-004`).
    public func toggleMarkdownPreview() {
        showMarkdownPreview.toggle()
        if !showMarkdownPreview {
            previewCache = nil
            PreviewThumbnailCache.shared.clear()
        }
    }

    /// Formats only the Markdown lines intersecting `currentSelection` in one atomic `BufferRevision` step (`Option+Shift+Cmd+F`); rejected fail-closed on binary read-only buffers (`BC-004`, `DATA-003`, `UI-009`).
    public func formatActiveSection() {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID] else { return }
        guard !session.isBinaryReadOnly, safetyBanner.canFormat else {
            statusBannerMessage = "Format blocked: binary read-only file."
            return
        }
        let snap = session.snapshot
        do {
            guard let batch = try MarkdownLintAndFormatEngine.formatSection(snapshot: snap, range: currentSelection).completedValue else {
                statusBannerMessage = "Section formatting skipped (degraded, AST depth > 128, or > 250 ms)."
                return
            }
            guard !batch.edits.isEmpty else {
                statusBannerMessage = "Markdown section already formatted."
                return
            }
            _ = try session.applyTextEdits(batch.edits, expectedRevision: snap.revision)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            statusBannerMessage = "Formatted \(batch.edits.count) line(s) in selection."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Section format failed: \(error)"
        }
    }

    /// Lifecycle of the translucent header submenu (`HeaderSubmenuStateMachine`).
    public var headerSubmenu = HeaderSubmenuStateMachine()

    /// Descriptive submenu rows reflecting the active tab's quarantine state and the preview/diff toggles.
    public var headerCommandItems: [HeaderCommandItem] {
        HeaderCommandCatalog.items(
            canSave: safetyBanner.canSave,
            canFormat: safetyBanner.canFormat,
            showMarkdownPreview: showMarkdownPreview,
            showDiffPane: showDiffPane
        )
    }

    /// Executes a submenu command if it is currently enabled, then dismisses the submenu with the `Escape` latch.
    public func performHeaderCommand(_ id: HeaderCommandID) {
        guard headerCommandItems.first(where: { $0.id == id })?.isEnabled == true else { return }
        headerSubmenu.dismissAfterCommand()
        switch id {
        case .newDocument: newUntitledTab()
        case .openFile: openFileViaPanel()
        case .openFolder: openFolderViaPanel()
        case .saveDocument: saveActiveDocument()
        case .saveDocumentAs: saveActiveDocumentAsViaPanel()
        case .duplicateLineOrSelection: performCommandD()
        case .formatDocument: formatActiveDocument()
        case .formatSection: formatActiveSection()
        case .toggleMarkdownPreview: toggleMarkdownPreview()
        case .toggleDiffPane: toggleDiffPane()
        case .showCheatSheet: isCheatSheetPresented = true
        }
    }

    public func toggleDiffPane() {
        showDiffPane.toggle()
        if !showDiffPane {
            diffCoordinator.clear()
        }
        refreshDiagnosticsForActiveDocument()
    }

    /// Toggles the left Folder Navigator sidebar visibility (`Cmd+B`).
    public func toggleLeftSidebar() {
        isLeftSidebarCollapsed.toggle()
    }

    /// Requests closing the active binary inspection overlay or currently active document tab (`Cmd+W`).
    public func requestCloseActiveTab() {
        if activeBinaryInspection != nil {
            dismissBinaryInspection()
            return
        }
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
        recoveryDebounceTask?.cancel()
        let manifest = SessionRecoveryManifest(tabs: tabSession.tabs, activeTabID: tabSession.activeTabID)
        try? recoveryStore.saveManifest(manifest)
        for tab in tabSession.tabs {
            if let session = sessionsByID[tab.id], (session.isDirty || session.fileURL == nil), !session.isBinaryReadOnly {
                // Only rewrite `<UUID>.recovery` when the tab's BufferRevision actually changed since last persist.
                if lastPersistedRecoveryRevisions[tab.id] != session.revision {
                    if (try? recoveryStore.saveRecoverySnapshot(session.snapshot)) != nil {
                        lastPersistedRecoveryRevisions[tab.id] = session.revision
                    }
                }
            }
        }
    }
}

/// Drag-and-drop delegate reordering open tabs within their pinned/unpinned partition in `EditorTabStrip` (`BC-008`).
@MainActor
private struct TabReorderDropDelegate: DropDelegate {
    let targetTab: TabDescriptor
    let model: SwiftEditWorkbenchModel
    @Binding var draggingTabID: DocumentID?

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggingTabID,
              draggedID != targetTab.id,
              let targetIndex = model.tabSession.tabs.firstIndex(where: { $0.id == targetTab.id }) else {
            return
        }
        model.moveTab(id: draggedID, toIndex: targetIndex)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTabID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

/// Root Zed-minimal Purple (`Viola`) + inverted `#FFFFFF`/`#000000` SwiftUI workspace view for `PH.SwiftEdit` (`UI-001..012`).
public struct SwiftEditRootView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var model = SwiftEditWorkbenchModel()
    @State private var draggingTabID: DocumentID?
    @State private var dragStartSidebarRatio: Double?
    @State private var presentedDirtyAlertTabID: DocumentID?
    @State private var gutterViewportMetrics: GutterViewportMetrics?

    public init() {}

    private var layoutContent: some View {
        VStack(spacing: 0) {
            if !model.isDistractionFree { toolbarBar }
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if model.isDistractionFree {
                        EmptyView()
                    } else if !model.isLeftSidebarCollapsed {
                        let sidebarWidth = SidebarLayoutGeometry.resolvedWidth(
                            forContainerWidth: Double(geometry.size.width),
                            ratio: model.sidebarWidthRatio
                        )
                        sidebarView
                            .frame(width: CGFloat(sidebarWidth))
                        sidebarPercentageDivider(containerWidth: Double(geometry.size.width))
                    } else {
                        collapsedSidebarEdgeHandle
                    }
                    VStack(spacing: 0) {
                        if !model.isDistractionFree { tabBar; safetyAndErrorBanners }
                        if !model.isDistractionFree { FindReplaceGoToLineBar(
                            state: $model.findReplaceState,
                            palette: model.palette,
                            onFind: { model.executeFind() },
                            onFindNext: { model.findNextMatch() },
                            onFindPrevious: { model.findPreviousMatch() },
                            onReplace: { model.executeReplaceSingle() },
                            onReplaceAll: { model.executeReplaceAll() },
                            onGoToLine: { model.executeGoToLine() },
                            onClose: { model.presentFindBar(mode: .hidden) }
                        ) }
                        editorAndOptionalPanels
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            if !model.isDistractionFree { statusBar }
        }
        .overlay(alignment: .top) {
            DocumentNavigatorOverlayView(model: model)
        }
        .overlay(alignment: .topLeading) {
            headerSubmenuOverlay
        }
        .onExitCommand {
            if model.handleEscape() { return }
            model.headerSubmenu.escapePressed()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            model.headerSubmenu.windowResignedKey()
        }
        .onChange(of: draggingTabID) { _, newValue in
            model.headerSubmenu.setDragging(newValue != nil || dragStartSidebarRatio != nil)
        }
        .onChange(of: dragStartSidebarRatio) { _, newValue in
            model.headerSubmenu.setDragging(newValue != nil || draggingTabID != nil)
        }
    }

    public var body: some View {
        layoutContent
        .background(model.palette.chromeSurface.swiftUIColor)
        .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
        .preferredColorScheme(model.preferredSwiftUIColorScheme)
        .onAppear {
            SwiftEditAppLifecycleBridge.shared.attach(workbench: model)
            model.windowFullScreenQuery = { NSApp.keyWindow?.styleMask.contains(.fullScreen) ?? false }
            model.windowFullScreenToggle = { NSApp.keyWindow?.toggleFullScreen(nil) }
            model.refreshUnmaskedSystemAppearance()
            model.updateAccessibilityPreferences(
                reduceTransparency: reduceTransparency,
                increasedContrast: colorSchemeContrast == .increased
            )
        }
        .onChange(of: systemColorScheme) { _, newScheme in
            if model.appearanceMode == .auto {
                model.updateSystemColorScheme(prefersDark: newScheme == .dark)
            }
        }
        .onChange(of: reduceTransparency) { _, newValue in
            model.updateAccessibilityPreferences(
                reduceTransparency: newValue,
                increasedContrast: colorSchemeContrast == .increased
            )
        }
        .onChange(of: colorSchemeContrast) { _, newContrast in
            model.updateAccessibilityPreferences(
                reduceTransparency: reduceTransparency,
                increasedContrast: newContrast == .increased
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            if model.isDistractionFree { model.windowDidExitFullScreen() }
        }
        .frame(minWidth: 960, minHeight: 620)
        .focusedSceneValue(\.workbenchModel, model)
        .sheet(isPresented: $model.isCheatSheetPresented) {
            KeyboardShortcutsCheatSheetView(palette: model.palette) {
                model.isCheatSheetPresented = false
                model.requestEditorFocus()
            }
        }
        .sheet(isPresented: $model.isAboutSheetPresented) {
            AboutSheetView(
                descriptor: AboutSheetDescriptor.resolveFromMainBundle(),
                palette: model.palette
            ) {
                model.isAboutSheetPresented = false
                model.requestEditorFocus()
            }
        }
        .alert(
            "Unsaved Changes",
            isPresented: Binding(
                get: { presentedDirtyAlertTabID != nil },
                set: { isPresented in
                    if !isPresented {
                        presentedDirtyAlertTabID = nil
                        if let nextID = model.pendingDirtyCloseTabID {
                            Task { @MainActor in
                                if model.pendingDirtyCloseTabID == nextID {
                                    presentedDirtyAlertTabID = nextID
                                }
                            }
                        }
                    }
                }
            )
        ) {
            Button("Save") { model.resolvePendingDirtyClose(.save) }
            Button("Don't Save", role: .destructive) { model.resolvePendingDirtyClose(.dontSave) }
            Button("Cancel", role: .cancel) { model.resolvePendingDirtyClose(.cancel) }
        } message: {
            let title = model.tabSession.tabs.first(where: { $0.id == presentedDirtyAlertTabID })?.title ?? model.activeTabTitle
            Text("Do you want to save your changes to \"\(title)\" before closing?")
        }
        .onChange(of: model.pendingDirtyCloseTabID) { _, newValue in
            presentedDirtyAlertTabID = newValue
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

    /// Root-level overlay: `.zIndex(99)` outside-click shield positioned strictly below `topBarHeight` so the header logo trigger stays clickable to toggle, beneath the `.zIndex(100)` sticky submenu (`BUG-006`, `UI-012`).
    @ViewBuilder
    private var headerSubmenuOverlay: some View {
        if model.headerSubmenu.isOpen {
            let items = model.headerCommandItems
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .padding(.top, CGFloat(HeaderSubmenuStateMachine.topBarHeight))
                    .onTapGesture { model.dismissHeaderSubmenu() }
                    .zIndex(99)
                HeaderBrandSubmenuView(
                    items: items,
                    palette: model.palette,
                    selectedID: model.headerSubmenu.selectedCommandID(in: items),
                    onSelect: { model.performHeaderCommand($0) },
                    onMoveSelection: { delta in model.headerSubmenu.moveSelection(delta: delta, items: items) },
                    onSelectFirst: { model.headerSubmenu.selectFirst(items: items) },
                    onSelectLast: { model.headerSubmenu.selectLast(items: items) },
                    onDismiss: { model.dismissHeaderSubmenu() }
                )
                .padding(.leading, 12)
                .offset(y: CGFloat(HeaderSubmenuStateMachine.topBarHeight))
                .zIndex(100)
            }
        }
    }

    private var toolbarBar: some View {
        HStack(spacing: 10) {
            Button(action: { model.headerSubmenu.clickToggle() }) {
                HStack(spacing: 6) {
                    SwiftEditBrandLogoView(size: CGFloat(SwiftEditBrandLogoGeometry.topBarLogoSize))
                    Text("PH.SwiftEdit")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                    Image(systemName: model.headerSubmenu.isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(model.headerSubmenu.isOpen ? model.palette.selectionBackground.swiftUIColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("PH.SwiftEdit commands menu")
            .accessibilityLabel("PH.SwiftEdit commands menu")
            .accessibilityValue(model.headerSubmenu.isOpen ? "Expanded" : "Collapsed")
            .accessibilityHint("Toggles the PH.SwiftEdit command menu")

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button("-") { model.zoomController.zoomOut() }
                Button("\(model.zoomController.zoomPercent)%") { model.zoomController.resetZoom() }
                    .monospacedDigit()
                Button("+") { model.zoomController.zoomIn() }
            }
            .fixedSize()

            appearanceSelectorControl
        }
        .padding(.horizontal, 12)
        .frame(height: CGFloat(HeaderSubmenuStateMachine.topBarHeight))
        .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
        .tint(model.palette.chromeAccent.swiftUIColor)
        .background(model.palette.topBarSurface.swiftUIColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(model.palette.hairlineBorder.swiftUIColor)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            model.isToolbarHovered = hovering
        }
    }

    /// Always-visible 3-way `Light | Dark | Auto` pill selector replacing the clipped segmented `Picker` (`UI-001`, `UI-003`).
    private var appearanceSelectorControl: some View {
        HStack(spacing: 2) {
            appearanceOptionButton(title: "Light", mode: .light)
            appearanceOptionButton(title: "Dark", mode: .black)
            appearanceOptionButton(title: "Auto", mode: .auto)
        }
        .padding(2)
        .background(model.palette.badgeSurface.swiftUIColor)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(model.palette.hairlineBorder.swiftUIColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance Mode Selector")
    }

    private func appearanceOptionButton(title: String, mode: AppearanceMode) -> some View {
        let isSelected = model.appearanceMode == mode
        return Button(action: { model.appearanceMode = mode }) {
            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? model.palette.activeControlForeground.swiftUIColor : model.palette.secondaryForeground.swiftUIColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isSelected ? model.palette.activeControlFill.swiftUIColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var collapsedSidebarEdgeHandle: some View {
        VStack(spacing: 8) {
            Button(action: { model.toggleSidebarPinCollapse() }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: max(12, CGFloat(model.zoomController.sidebarScaledFontSizePoints))))
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
            }
            .buttonStyle(.plain)
            .help("Expand and Pin Left Navigation Panel (Cmd+B)")
            .padding(.top, 10)
            Spacer()
        }
        .frame(width: 24)
        .background(model.palette.sidebarSurface.swiftUIColor)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(model.palette.hairlineBorder.swiftUIColor)
                .frame(width: 1)
        }
    }

    private func sidebarPercentageDivider(containerWidth: Double) -> some View {
        Rectangle()
            .fill(model.palette.hairlineBorder.swiftUIColor)
            .frame(width: 5)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartSidebarRatio == nil {
                            dragStartSidebarRatio = model.sidebarWidthRatio
                        }
                        let startRatio = dragStartSidebarRatio ?? model.sidebarWidthRatio
                        let nextRatio = SidebarLayoutGeometry.updatedRatio(
                            currentRatio: startRatio,
                            dragDeltaWidth: Double(value.translation.width),
                            containerWidth: containerWidth
                        )
                        model.updateSidebarWidthRatio(nextRatio)
                    }
                    .onEnded { _ in
                        dragStartSidebarRatio = nil
                    }
            )
            .accessibilityLabel("Resize Sidebar Divider")
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
                                .foregroundStyle((tab.isPinned ? model.palette.pinnedTabBadge : model.palette.secondaryForeground).swiftUIColor)
                        }
                        .buttonStyle(.plain)
                        .help(tab.isPinned ? "Unpin Tab" : "Pin Tab")

                        Button(action: { model.activateTab(id: tab.id) }) {
                            Text("\(tab.title)\(tab.isDirty ? " •" : "")")
                                .font(.callout.weight(isActive ? .semibold : .regular))
                                .foregroundStyle((isActive ? model.palette.chromeForeground : model.palette.secondaryForeground).swiftUIColor)
                        }
                        .buttonStyle(.plain)

                        Button(action: { model.moveTabLeft(id: tab.id) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .opacity(isActive ? 0.85 : 0.65)
                        .help("Move Tab Left")

                        Button(action: { model.moveTabRight(id: tab.id) }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .opacity(isActive ? 0.85 : 0.65)
                        .help("Move Tab Right")

                        Button(action: { model.requestCloseTab(id: tab.id) }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .help("Close Tab (Cmd+W)")
                    }
                    .foregroundStyle((isActive ? model.palette.chromeForeground : model.palette.secondaryForeground).swiftUIColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isActive ? model.palette.tabActiveSurface.swiftUIColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isActive ? model.palette.chromeAccent.swiftUIColor : model.palette.hairlineBorder.swiftUIColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onDrag {
                        draggingTabID = tab.id
                        return NSItemProvider(object: tab.id.rawValue.uuidString as NSString)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: TabReorderDropDelegate(targetTab: tab, model: model, draggingTabID: $draggingTabID)
                    )
                    .contextMenu {
                        Button("Move Tab Left") { model.moveTabLeft(id: tab.id) }
                        Button("Move Tab Right") { model.moveTabRight(id: tab.id) }
                        Divider()
                        Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") { model.togglePin(id: tab.id) }
                        Button("Close Tab") { model.requestCloseTab(id: tab.id) }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(model.palette.tabBarSurface.swiftUIColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(model.palette.hairlineBorder.swiftUIColor)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var safetyAndErrorBanners: some View {
        if model.safetyBanner.isBinaryReadOnlyBannerVisible {
            HStack(spacing: 10) {
                Text("READ-ONLY BINARY INSPECTION: Save, Format, Pin Tab, and SessionRecovery are disabled.")
                Spacer()
                if model.activeBinaryInspection != nil {
                    Button("Dismiss Inspection") { model.dismissBinaryInspection() }
                        .buttonStyle(.bordered)
                }
            }
            .purpleSecurityWarningBanner(
                foreground: model.palette.binaryQuarantineForeground,
                background: model.palette.binaryQuarantineBackground,
                border: model.palette.binaryQuarantineBorder,
                verticalPadding: 6
            )
        }
        if !model.safetyBanner.bidiWarnings.isEmpty {
            Text("BiDi Warning: \(model.safetyBanner.bidiWarnings.count) Unicode bidirectional control character(s) detected.")
                .purpleSecurityWarningBanner(
                    foreground: model.palette.bidiWarningForeground,
                    background: model.palette.bidiWarningBackground,
                    border: model.palette.bidiWarningBorder,
                    verticalPadding: 5
                )
        }
        if let message = model.statusBannerMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(model.palette.badgeSurface.swiftUIColor)
        }
    }

    private var sidebarView: some View {
        let sidebarFont = CGFloat(model.zoomController.sidebarScaledFontSizePoints)
        let headerFont = max(10, sidebarFont * 0.88)
        let rowSpacing = max(4, CGFloat(6.0 * model.zoomController.zoomScaleFactor))

        return VStack(alignment: .leading, spacing: rowSpacing) {
            HStack(spacing: 8) {
                Text(model.selectedFolderURL?.lastPathComponent ?? "No Folder Open")
                    .font(.system(size: headerFont, weight: .semibold))
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    .lineLimit(1)
                Spacer()
                if model.selectedFolderURL != nil {
                    Button(action: { model.navigateToParentFolder() }) {
                        Label("...", systemImage: "arrow.turn.left.up")
                            .font(.system(size: headerFont, weight: .semibold))
                            .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canNavigateToParentFolder)
                    .help("Go to parent folder (...)")
                }
                Button(action: { model.toggleSidebarPinCollapse() }) {
                    Image(systemName: model.isLeftSidebarPinned ? "pin.fill" : "pin.slash")
                        .font(.system(size: headerFont, weight: .semibold))
                        .foregroundStyle(model.palette.chromeAccent.swiftUIColor)
                }
                .buttonStyle(.plain)
                .help("Unpin and Collapse Left Navigation Panel (Cmd+B)")
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            List {
                if model.canNavigateToParentFolder {
                    Button(action: { model.navigateToParentFolder() }) {
                        HStack(spacing: rowSpacing) {
                            Image(systemName: "folder.badge.minus")
                                .font(.system(size: sidebarFont))
                                .foregroundStyle(model.palette.chromeAccent.swiftUIColor)
                            Text("...")
                                .font(.system(size: sidebarFont, weight: .semibold))
                                .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
                ForEach(model.folderEntries, id: \.url) { entry in
                    let binaryColor = model.palette.sidebarBinaryDisabledText.swiftUIColor
                    let iconName = entry.isDirectory
                        ? "folder.fill"
                        : (entry.isBinary ? "doc.fill" : (entry.isHiddenDotfile ? "eye.slash" : "doc.text"))
                    Button(action: { model.openFolderEntry(entry) }) {
                        HStack(spacing: rowSpacing) {
                            Image(systemName: iconName)
                                .font(.system(size: sidebarFont))
                                .foregroundStyle(entry.isBinary ? binaryColor : model.palette.chromeAccent.swiftUIColor)
                            Text(entry.name)
                                .font(.system(size: sidebarFont))
                                .foregroundStyle(entry.isBinary ? binaryColor : model.palette.chromeForeground.swiftUIColor)
                                .italic(entry.isBinary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(entry.isBinary ? "Binary file (read-only disabled in sidebar)" : entry.name)
                    .contextMenu {
                        sidebarEntryContextMenu(for: entry)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .contextMenu {
                sidebarBackgroundContextMenu
            }
        }
        .background(model.palette.sidebarSurface.swiftUIColor)
        .contextMenu {
            sidebarBackgroundContextMenu
        }
    }

    @ViewBuilder
    private func sidebarEntryContextMenu(for entry: FolderEntryDescriptor) -> some View {
        let targetDir = model.resolveSidebarCreationDirectory(for: entry)
        Button("Reveal in Finder") { model.sidebarRevealInFinder(at: entry.url) }
        if entry.isDirectory {
            Button("Open Folder in Finder") { model.sidebarOpenFolderInFinder(at: entry.url) }
        } else if let currentFolder = model.selectedFolderURL {
            Button("Open Folder in Finder") { model.sidebarOpenFolderInFinder(at: currentFolder) }
        }
        Button("Open Terminal") { model.sidebarOpenInTerminal(at: entry.url) }
        Divider()
        Button("New File…") { promptCreateFile(in: targetDir) }
            .disabled(targetDir == nil)
        Button("New Folder…") { promptCreateFolder(in: targetDir) }
            .disabled(targetDir == nil)
        Divider()
        if !entry.isBinary {
            Button("Cut") { model.sidebarCutItem(at: entry.url) }
            Button("Copy") { model.sidebarCopyItem(at: entry.url) }
            Button("Paste") { _ = model.sidebarPasteItem(into: targetDir) }
                .disabled(model.sidebarClipboard == nil)
            Divider()
            Button(entry.isDirectory ? "Rename Folder…" : "Rename File…") {
                promptInlineRename(for: entry)
            }
        }
        Button("Delete (Move to Trash)", role: .destructive) {
            model.requestSidebarTrashItem(at: entry.url)
        }
    }

    @ViewBuilder
    private var sidebarBackgroundContextMenu: some View {
        let targetDir = model.resolveSidebarCreationDirectory(for: nil)
        Button("New File…") { promptCreateFile(in: targetDir) }
            .disabled(targetDir == nil)
        Button("New Folder…") { promptCreateFolder(in: targetDir) }
            .disabled(targetDir == nil)
        Divider()
        Button("Paste") { _ = model.sidebarPasteItem(into: targetDir) }
            .disabled(model.sidebarClipboard == nil || targetDir == nil)
        if let currentFolder = targetDir {
            Divider()
            Button("Open Folder in Finder") { model.sidebarOpenFolderInFinder(at: currentFolder) }
            Button("Open Terminal") { model.sidebarOpenInTerminal(at: currentFolder) }
        }
    }

    /// Prompts for a single-segment name validated via `SidebarItemNameValidator` and creates a new file inside `directory` (`CWE-22`, `BC-012`, `SEC-003`).
    private func promptCreateFile(in directory: URL?) {
        guard let directory,
              let name = promptSingleSegmentName(
                title: "New File",
                message: "Enter a single-segment filename to create in \"\(directory.lastPathComponent)\":",
                defaultValue: "Untitled.md",
                confirmTitle: "Create"
              ) else {
            return
        }
        if let created = model.sidebarCreateFile(named: name, in: directory) {
            model.openFile(at: created, withinScope: model.grantedScopeRootURL ?? directory)
        }
    }

    /// Prompts for a single-segment name validated via `SidebarItemNameValidator` and creates a new folder inside `directory` (`CWE-22`, `BC-012`, `SEC-003`).
    private func promptCreateFolder(in directory: URL?) {
        guard let directory,
              let name = promptSingleSegmentName(
                title: "New Folder",
                message: "Enter a single-segment folder name to create in \"\(directory.lastPathComponent)\":",
                defaultValue: "New Folder",
                confirmTitle: "Create"
              ) else {
            return
        }
        _ = model.sidebarCreateFolder(named: name, in: directory)
    }

    private func promptInlineRename(for entry: FolderEntryDescriptor) {
        guard let newName = promptSingleSegmentName(
            title: entry.isDirectory ? "Rename Folder" : "Rename File",
            message: "Enter a new single-segment name:",
            defaultValue: entry.name,
            confirmTitle: "Rename"
        ) else {
            return
        }
        _ = model.sidebarRenameItem(at: entry.url, to: newName)
    }

    private func promptSingleSegmentName(
        title: String,
        message: String,
        defaultValue: String,
        confirmTitle: String
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.stringValue = defaultValue
        alert.accessoryView = input
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        return input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editorAndOptionalPanels: some View {
        HSplitView {
            if let session = model.activeDocumentSession {
                HStack(spacing: 0) {
                    if !model.isDistractionFree {
                        LineNumberGutterView(
                            projection: model.activeLineNumberGutter,
                            palette: model.palette,
                            severityByLine: model.gutterSeverityByLine,
                            viewportMetrics: gutterViewportMetrics
                        )
                    }
                    TextKit2EditorView(
                        documentID: session.id,
                        bufferRevision: session.revision,
                        text: session.text,
                        isEditable: !session.isBinaryReadOnly,
                        palette: model.palette,
                        fontSizePoints: model.zoomController.scaledFontSizePoints,
                        highlightProjection: model.activeHighlightProjection,
                        onTextChange: { model.handleEditorTextChanged($0) },
                        onSelectionChange: { model.handleSelectionChanged($0) },
                        onSmartNewline: { model.applySmartNewlineIfApplicable(at: $0) },
                        onListIndent: { model.listIndentationOutcome(outdent: $0) },
                        onTableTab: { model.tableTabOutcome(backward: $0) },
                        isMarkdownDocument: model.isMarkdownMenuEnabled,
                        programmaticSelection: model.currentSelection,
                        programmaticSelectionToken: model.programmaticSelectionToken,
                        lintDiagnostics: model.visibleLintDiagnostics,
                        undoRegistry: model.undoRegistry,
                        editorFocusRequestToken: model.editorFocusRequestToken,
                        onViewportMetricsChange: { gutterViewportMetrics = $0 },
                        onEscape: { model.handleEscape() }
                    )
                }
            }
            if !model.isDistractionFree, model.showMarkdownPreview, model.isMarkdownMenuEnabled {
                MarkdownNativePreviewView(
                    document: model.markdownPreviewDocument,
                    palette: model.palette,
                    gate: model.previewResourceGate,
                    activeSourceLine: model.previewSourceLine
                )
                .frame(minWidth: 260, idealWidth: 340)
            }
            if !model.isDistractionFree, model.showDiffPane {
                diffPanel
                    .frame(minWidth: 300, idealWidth: 420)
            }
        }
    }

    private var diffPanel: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                Text("Side-by-Side Myers Diff (vs Saved Baseline)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                let rows = model.diffCoordinator.rows
                ForEach(rows.indices, id: \.self) { index in
                    let row = rows[index]
                    HStack(spacing: 8) {
                        Text(row.lhsText ?? "")
                            .font(.caption.monospaced())
                            .foregroundStyle((row.lhsKind == .removed ? model.palette.editorCanvasText : model.palette.chromeForeground).swiftUIColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .background(row.lhsKind == .removed ? model.palette.diffRemovedBackground.swiftUIColor : Color.clear)
                        Text(row.rhsText ?? "")
                            .font(.caption.monospaced())
                            .foregroundStyle((row.rhsKind == .inserted ? model.palette.editorCanvasText : model.palette.chromeForeground).swiftUIColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .background(row.rhsKind == .inserted ? model.palette.diffInsertedBackground.swiftUIColor : Color.clear)
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
            Button(model.activeLintStatus.label) { model.toggleDiagnosticsPopover() }
                .buttonStyle(.plain)
                .accessibilityLabel(model.activeLintStatus.label)
                .accessibilityHint("Opens the Markdown diagnostics popover")
                .popover(isPresented: Binding(get: { model.isDiagnosticsPopoverPresented }, set: { model.isDiagnosticsPopoverPresented = $0 })) {
                    MarkdownDiagnosticsPopoverView(model: model)
                }
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
        .foregroundStyle(model.palette.statusBarForeground.swiftUIColor)
        .tint(model.palette.statusBarForeground.swiftUIColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(model.palette.statusBarSurface.swiftUIColor)
    }
}
#endif
