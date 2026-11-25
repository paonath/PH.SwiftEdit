import Foundation
import SwiftEditCore
#if os(macOS)
import AppKit
#endif

/// Groups immutable injected collaborators for `SwiftEditWorkbenchModel` to keep the facade declaration concise (`AR-007`, `AR-009`).
struct WorkbenchDependencies {
    let fileSystem: any FileSystemProviding
    let desktopWorkspace: any DesktopWorkspaceIntegrating
    let loader: DocumentLoader
    let navigator: DotfileFolderNavigator
    let batchLoader: ShallowFolderBatchLoader
    let recentFilesStore: RecentFilesStore
    let preferencesStore: EditorPreferencesStore
    let recoveryStore: SessionRecoveryStore
    let parentPermissionChecker: (URL) -> Bool
    let installedTerminalBundleIDsProvider: @MainActor () -> Set<String>
    let systemDarkDetector: @MainActor () -> Bool
    let savePanelProvider: @MainActor (String) -> URL?
    let openPanelProvider: @MainActor (_ chooseDirectories: Bool, _ prompt: String?) -> URL?
    let clipboardWriter: @MainActor (String) -> Void
    #if os(macOS)
    let dictationTrigger: @MainActor (SwiftEditNSTextView) -> Bool
    #endif
}

#if os(macOS)
/// Dispatches native macOS Dictation (`startDictation:`) on an editable `SwiftEditNSTextView` without custom audio capture or entitlements (`REQ-031-02`, `SEC-001`, `SEC-004`, `SEC-012`).
@MainActor
enum MacOSDictationDispatcher {
    private static let startDictationSelector = NSSelectorFromString("startDictation:")

    /// Focuses `textView` in its window and invokes the standard AppKit `startDictation:` responder action, falling back to the system `Edit -> Start Dictation…` menu item.
    static func startDictation(in textView: SwiftEditNSTextView) -> Bool {
        guard textView.isEditable else { return false }
        textView.window?.makeFirstResponder(textView)
        if NSApp.sendAction(startDictationSelector, to: nil, from: textView) {
            return true
        }
        if let item = locateDictationMenuItem(in: NSApp.mainMenu),
           let action = item.action {
            return NSApp.sendAction(action, to: item.target, from: item)
        }
        return false
    }

    private static func locateDictationMenuItem(in mainMenu: NSMenu?) -> NSMenuItem? {
        guard let mainMenu else { return nil }
        for topItem in mainMenu.items {
            if let submenu = topItem.submenu {
                for item in submenu.items where item.action == startDictationSelector {
                    return item
                }
            }
        }
        return nil
    }
}
#endif

#if os(macOS)
/// Cohesive observable appearance, accessibility, typography, and zoom state owned by `SwiftEditWorkbenchModel` (`UI-001..005`).
struct WorkbenchAppearanceState {
    var systemPrefersDark: Bool = true
    var reduceTransparency: Bool = false
    var increasedContrast: Bool = false
    var lastWindowAppearanceTarget: MacOSWindowAppearanceTarget = .darkAqua
    var appearanceMode: AppearanceMode
    var syntaxColorScheme: SyntaxColorScheme = .swiftEditDefault
    var palette: PurpleThemePalette
    var interfaceFont: FontChoice = .default
    var editorFont: FontChoice = .default
    var preferredTerminalBundleID: String? = nil
    var typographyGeneration: Int = 0
    var isWordWrapEnabled: Bool = true
    var launchInFullScreen: Bool = true
    var trimTrailingWhitespaceOnSave: Bool = false
    var zoomController: EditorZoomController
}

/// Cohesive observable workspace folder navigation, recent files, batch-open, and transient binary inspection state (`UI-001`, `DATA-003`).
struct WorkbenchWorkspaceFolderState {
    var sidebarWidthRatio: Double = SidebarLayoutGeometry.defaultWidthRatio
    var isLeftSidebarCollapsed: Bool = true
    var selectedFolderURL: URL?
    var selectedSidebarEntryURL: URL?
    var grantedScopeRootURL: URL?
    var folderEntries: [FolderEntryDescriptor] = []
    var recentFiles: [RecentFileEntry] = []
    var pendingBatchOpenPlan: BatchOpenPlan?
    var pendingBatchFolderURL: URL?
    var activeBinaryInspection: BinaryInspectionPresentation?
}

/// Cohesive observable chrome sheet, panel, overlay, compare, and selection-token state (`UI-005`).
struct WorkbenchChromeOverlayState {
    var isToolbarHovered: Bool = false
    var showMarkdownPreview: Bool = false
    var showDiffPane: Bool = false
    var isCheatSheetPresented: Bool = false
    var isAboutSheetPresented: Bool = false
    var isHelpSheetPresented: Bool = false
    var isDistractionFree: Bool = false
    var isShortcutsPanelVisible: Bool = false
    var isDiagnosticsPopoverPresented: Bool = false
    var navigatorState: DocumentNavigatorState?
    var elementContextualMenu: ElementContextualMenuState?
    var headerSubmenu = HeaderSubmenuStateMachine()
    var statusBannerMessage: String?
    var pendingDirtyCloseTabID: DocumentID?
    var isPendingTerminationPrompt: Bool = false
    var compareSourceTabID: DocumentID?
    var compareDestinationTabID: DocumentID?
    var programmaticSelectionToken: Int = 0
    var editorFocusRequestToken: Int = 0
    var previewGeneration: Int = 0
}

/// Non-observed window, PTY terminal registry, log file reader, and update installer hooks (`UI-005`, `SEC-004`).
@MainActor
struct WorkbenchRuntimeHooks {
    weak var hostWindow: NSWindow?
    var windowFullScreenQuery: () -> Bool = { false }
    var windowFullScreenToggle: () -> Void = {}
    let embeddedTerminalRegistry = EmbeddedTerminalRegistry()
    var userHomeDirectoryProvider: () -> URL = {
        FileManager.default.homeDirectoryForCurrentUser
    }
    var logFileReader: any LogFileReading = LocalLogFileReader()
    var updateInstaller = AppUpdateInstaller()
}
#endif

/// Groups non-observed per-revision caches and background task handles owned by `SwiftEditWorkbenchModel` (`UI-005`, `UI-012`).
@MainActor
struct WorkbenchRenderCaches {
    var wordOccurrenceCache: (
        id: DocumentID,
        revision: BufferRevision,
        selection: SwiftEditCore.TextRange,
        ranges: [SwiftEditCore.TextRange]
    )?
    var didApplyInitialFullScreen: Bool = false
    var lintGeneration: UInt64 = 0
    var terminationReplyHandler: (@MainActor (Bool) -> Void)?
    var distributedThemeObserver: (any NSObjectProtocol)?
    var cachedParentNavigation: (folder: URL?, scope: URL?, canNavigate: Bool)?
    let textIndexCache = DocumentTextIndexCache()
    var cachedGutterProjection: (id: DocumentID, revision: BufferRevision, caret: Int, fontSize: Double, value: LineNumberGutterProjection)?
    var cachedStatusBarMetrics: (id: DocumentID, revision: BufferRevision, caret: Int, value: StatusBarMetricsProjection)?
    var cachedPreviewSourceLine: (id: DocumentID, revision: BufferRevision, caret: Int, value: Int)?
    var cachedVisibleLint: (generation: UInt64, caretLine: Int, visible: [MarkdownLintDiagnostic], severityByLine: [Int: MarkdownLintSeverity])?
    var cachedLintDetails: (generation: UInt64, caretLine: Int, details: [Int: String])?
    var lastPersistedRecoveryRevisions: [DocumentID: BufferRevision] = [:]
    var recoveryDebounceTask: Task<Void, Never>?
    var diagnosticsTask: Task<Void, Never>?
    var asyncOpenGeneration: UInt64 = 0
    var bracketTopologyCache: (id: DocumentID, revision: BufferRevision, topology: BracketTopology)?
    var backtickCache: (id: DocumentID, revision: BufferRevision, result: BacktickHighlightResult?)?
    var previewCache: (
        id: DocumentID,
        revision: BufferRevision,
        document: GFMPreviewDocument?,
        enriched: GFMPreviewEnrichedDocument?
    )?
    var fullScreenWasActiveBeforeDistractionFree: Bool = false
    var lineIndexCache: (id: DocumentID, revision: BufferRevision, index: MarkdownLineIndex)?
    var propertiesCache: (id: DocumentID, revision: BufferRevision, model: FrontmatterPropertyModel?)?
    var previewTask: Task<Void, Never>?
    var previewTaskTarget: (id: DocumentID, revision: BufferRevision)?
}
