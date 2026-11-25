import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Cohesive bundle of `@MainActor` domain sub-controllers and collaborator registries owned by `SwiftEditWorkbenchModel` (`REQ-002`).
@MainActor
struct WorkbenchDomainControllers {
    let wordCompletion = WorkbenchWordCompletionController()
    let findAndNavigation = WorkbenchFindAndNavigationController()
    let terminalSession = WorkbenchTerminalSessionController()
    let sidebarFile: WorkbenchSidebarFileController
    let update: WorkbenchUpdateController
    let typography = AppTypography()
    let diffCoordinator = DiffPaneCoordinator()
    let undoRegistry = PerTabUndoManagerRegistry()
    let propertiesPanel = PropertiesPanelState()
    let bulkCloseHistory = WorkbenchBulkCloseAndHistoryController()
    let externalFileMonitor = ExternalFileChangeMonitor()
    let quickOpen = WorkbenchQuickOpenController()
}

/// `@MainActor @Observable` application controller wiring `SwiftEditCore` engines and `SessionRecoveryStore` to the Zed-minimal Purple SwiftUI shell (`UI-001..012`, `REQ-002`).
@MainActor
@Observable
public final class SwiftEditWorkbenchModel {
    @ObservationIgnored let domainControllers: WorkbenchDomainControllers

    // MARK: Cohesive Observable State Domains & Core Document State (`<= 22` nominal members)

    var appearanceState: WorkbenchAppearanceState
    var workspaceState = WorkbenchWorkspaceFolderState()
    var overlayState = WorkbenchChromeOverlayState()

    public internal(set) var tabSession: WorkspaceTabSession
    public internal(set) var sessionsByID: [DocumentID: DocumentSession]
    public internal(set) var savedBaselineByID: [DocumentID: DocumentSnapshot]
    public internal(set) var currentSelection = SwiftEditCore.TextRange(location: 0, length: 0)
    public internal(set) var lintDiagnostics: [MarkdownLintDiagnostic] = [] {
        didSet { caches.lintGeneration &+= 1 }
    }
    public internal(set) var bracketResult: BracketBalanceResult?
    public internal(set) var backtickResult: BacktickHighlightResult?
    public internal(set) var safetyBanner: InspectionSafetyBannerState
    public var recoveryDebounceNanoseconds: UInt64 = 500_000_000
    public internal(set) var logTails: [DocumentID: LogTailController] = [:]
    public internal(set) var logTailOnlyTabIDs: Set<DocumentID> = []

    @ObservationIgnored let deps: WorkbenchDependencies
    @ObservationIgnored var caches = WorkbenchRenderCaches()
    @ObservationIgnored var runtimeHooks = WorkbenchRuntimeHooks()

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
        },
        openPanelProvider: @escaping @MainActor (_ chooseDirectories: Bool, _ prompt: String?) -> URL? = { chooseDirectories, prompt in
            let panel = NSOpenPanel()
            panel.canChooseFiles = !chooseDirectories
            panel.canChooseDirectories = chooseDirectories
            panel.allowsMultipleSelection = false
            if let prompt { panel.prompt = prompt }
            return panel.runModal() == .OK ? panel.url : nil
        },
        clipboardWriter: @escaping @MainActor (String) -> Void = { text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        },
        updateFetcher: any HTTPDataFetching = URLSessionHTTPFetcher(),
        installedTerminalBundleIDsProvider: (@MainActor () -> Set<String>)? = nil,
        dictationTrigger: (@MainActor (NSTextView) -> Bool)? = nil
    ) {
        let nav = DotfileFolderNavigator(fileSystem: fileSystem)
        let resolvedRecentStore: any PreferencesProviding = recentFilesStore
            ?? UserDefaultsPreferencesStore(suiteName: recentFilesSuiteName)
        let resolvedPrefsStore: any PreferencesProviding
        if let preferencesStore {
            resolvedPrefsStore = preferencesStore
        } else if let preferencesSuiteName {
            resolvedPrefsStore = UserDefaultsPreferencesStore(suiteName: preferencesSuiteName)
        } else {
            resolvedPrefsStore = EditorPreferencesStore.defaultHomeJSONStore()
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let resolvedRecoveryURL = recoveryDirectoryURL ?? appSupport
            .appendingPathComponent("PH.SwiftEdit", isDirectory: true)
            .appendingPathComponent("SessionRecovery", isDirectory: true)

        let builtDeps = WorkbenchDependencies(
            fileSystem: fileSystem,
            desktopWorkspace: desktopWorkspace,
            loader: DocumentLoader(fileSystem: fileSystem),
            navigator: nav,
            batchLoader: ShallowFolderBatchLoader(navigator: nav, fileSystem: fileSystem),
            recentFilesStore: RecentFilesStore(store: resolvedRecentStore, fileSystem: fileSystem, bookmarkCoder: bookmarkCoder),
            preferencesStore: EditorPreferencesStore(store: resolvedPrefsStore),
            recoveryStore: SessionRecoveryStore(recoveryDirectoryURL: resolvedRecoveryURL),
            parentPermissionChecker: parentPermissionChecker,
            installedTerminalBundleIDsProvider: installedTerminalBundleIDsProvider
                ?? { Set(TerminalCatalog.installedTerminals().map(\.bundleIdentifier)) },
            systemDarkDetector: systemDarkDetector,
            savePanelProvider: savePanelProvider,
            openPanelProvider: openPanelProvider,
            clipboardWriter: clipboardWriter,
            dictationTrigger: { textView in
                if let dictationTrigger {
                    return dictationTrigger(textView)
                }
                return MacOSDictationDispatcher.startDictation(in: textView)
            }
        )
        self.deps = builtDeps
        self.domainControllers = WorkbenchDomainControllers(
            sidebarFile: WorkbenchSidebarFileController(fileSystem: fileSystem),
            update: WorkbenchUpdateController(updateChecker: GitHubReleaseUpdateChecker(fetcher: updateFetcher))
        )

        let prefs = builtDeps.preferencesStore.load()
        let initialSystemDark = systemDarkDetector()
        self.appearanceState = WorkbenchAppearanceState(
            systemPrefersDark: initialSystemDark,
            lastWindowAppearanceTarget: MacOSAppearanceSynchronizer.synchronizeApplicationAppearance(for: prefs.appearanceMode),
            appearanceMode: prefs.appearanceMode,
            syntaxColorScheme: prefs.syntaxColorScheme,
            palette: PurpleThemePalette.resolve(
                appearance: prefs.appearanceMode,
                systemPrefersDark: initialSystemDark,
                syntaxColorScheme: prefs.syntaxColorScheme
            ),
            interfaceFont: prefs.interfaceFont,
            editorFont: prefs.editorFont,
            preferredTerminalBundleID: prefs.preferredTerminalBundleID,
            isWordWrapEnabled: prefs.isWordWrapEnabled,
            launchInFullScreen: prefs.launchInFullScreen,
            trimTrailingWhitespaceOnSave: prefs.trimTrailingWhitespaceOnSave,
            zoomController: EditorZoomController(zoomPercent: prefs.zoomPercent)
        )
        self.domainControllers.terminalSession.panelHeight = CGFloat(prefs.terminalPanelHeight)

        self.tabSession = WorkspaceTabSession()
        self.sessionsByID = [:]
        self.savedBaselineByID = [:]
        self.safetyBanner = InspectionSafetyBannerState(
            isBinaryReadOnlyBannerVisible: false,
            canSave: false,
            canFormat: false,
            canPinTab: false,
            bidiWarnings: []
        )

        Task.detached(priority: .utility) { await SystemFontFamilyCache.shared.prewarm() }
        typography.setChoice(prefs.interfaceFont, for: .interface)
        typography.setChoice(prefs.editorFont, for: .editor)
        restoreSessionRecoveryIfPresent()
        workspaceState.recentFiles = builtDeps.recentFilesStore.entries()
        refreshDiagnosticsForActiveDocument()
        domainControllers.externalFileMonitor.onDiskEvent = { [weak self] tabID in
            self?.handleExternalDiskChange(for: tabID)
        }

        caches.distributedThemeObserver = DistributedNotificationCenter.default().addObserver(
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
        if let observer = terminalSessionController.terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        runtimeHooks.embeddedTerminalRegistry.terminateAll()
        for tail in logTails.values { tail.stop() }
        domainControllers.externalFileMonitor.unwatchAll()
        caches.diagnosticsTask?.cancel()
        updateController.cancelPendingCheck()
        caches.recoveryDebounceTask?.cancel()
        wordCompletionController.invalidate()
        undoRegistry.clearAllUndoManagers()
        caches.bracketTopologyCache = nil
        caches.backtickCache = nil
        caches.previewCache = nil
        diffCoordinator.clear()
        PreviewThumbnailCache.shared.clear()
        if let observer = caches.distributedThemeObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}

extension SwiftEditWorkbenchModel {
    /// Delay after the last edit before the word cache is rebuilt off the main actor (`UI-012`).
    public nonisolated static let wordCompletionRebuildDebounce: Duration = WorkbenchWordCompletionController.rebuildDebounce
    public static let minTerminalPanelHeight: CGFloat = WorkbenchTerminalSessionController.minPanelHeight
    public static let maxTerminalPanelHeight: CGFloat = WorkbenchTerminalSessionController.maxPanelHeight
    static let syncDiagnosticThresholdUTF8: Int = 4_096
    static let asyncFileLoadThresholdBytes: UInt64 = 2 * 1024 * 1024
    static let syncPreviewThresholdUTF8: Int = 64 * 1024

    public var wordCompletionController: WorkbenchWordCompletionController { domainControllers.wordCompletion }
    public var findAndNavigationController: WorkbenchFindAndNavigationController { domainControllers.findAndNavigation }
    public var terminalSessionController: WorkbenchTerminalSessionController { domainControllers.terminalSession }
    public var sidebarFileController: WorkbenchSidebarFileController { domainControllers.sidebarFile }
    public var updateController: WorkbenchUpdateController { domainControllers.update }
    public var typography: AppTypography { domainControllers.typography }
    public var diffCoordinator: DiffPaneCoordinator { domainControllers.diffCoordinator }
    public var undoRegistry: PerTabUndoManagerRegistry { domainControllers.undoRegistry }
    public var propertiesPanel: PropertiesPanelState { domainControllers.propertiesPanel }
    public var externalFileMonitor: ExternalFileChangeMonitor { domainControllers.externalFileMonitor }
    public var quickOpenController: WorkbenchQuickOpenController { domainControllers.quickOpen }
}

#endif
