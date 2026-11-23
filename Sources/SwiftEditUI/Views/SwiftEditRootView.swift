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
    public let wordOccurrenceRanges: [SwiftEditCore.TextRange]

    public init(
        activeLineRange: SwiftEditCore.TextRange = SwiftEditCore.TextRange(location: 0, length: 0),
        bracketPairs: [BracketPairSpan] = [],
        activeBracketPair: BracketPairSpan? = nil,
        unbalancedBrackets: [UnbalancedBracket] = [],
        backtickSpans: [BacktickHighlightSpan] = [],
        wordOccurrenceRanges: [SwiftEditCore.TextRange] = []
    ) {
        self.activeLineRange = activeLineRange
        self.bracketPairs = bracketPairs
        self.activeBracketPair = activeBracketPair
        self.unbalancedBrackets = unbalancedBrackets
        self.backtickSpans = backtickSpans
        self.wordOccurrenceRanges = wordOccurrenceRanges
    }

    /// `O(log L)` variant reusing a per-revision `DocumentTextIndex` (zero `NSString` bridging per caret move).
    public static func evaluate(
        index: DocumentTextIndex,
        caretLocation: Int,
        bracketResult: BracketBalanceResult?,
        backtickResult: BacktickHighlightResult?,
        wordOccurrenceRanges: [SwiftEditCore.TextRange] = []
    ) -> EditorHighlightProjection {
        EditorHighlightProjection(
            activeLineRange: index.lineContentRange(atUTF16Offset: caretLocation),
            bracketPairs: bracketResult?.matchedPairs ?? [],
            activeBracketPair: bracketResult?.activePair,
            unbalancedBrackets: bracketResult?.unbalancedBrackets ?? [],
            backtickSpans: backtickResult?.spans ?? [],
            wordOccurrenceRanges: wordOccurrenceRanges
        )
    }

    /// Computes a deterministic highlight projection without mutating `session`, incrementing `BufferRevision`, or copying the full UTF-16 buffer (`PERF-007`).
    public static func evaluate(
        text: String,
        caretLocation: Int,
        bracketResult: BracketBalanceResult?,
        backtickResult: BacktickHighlightResult?,
        wordOccurrenceRanges: [SwiftEditCore.TextRange] = []
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
            backtickSpans: backtickResult?.spans ?? [],
            wordOccurrenceRanges: wordOccurrenceRanges
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
        "About SwiftEdit",
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
        let occurrences = cachedWordOccurrencesForActiveSelection()
        if let session = activeDocumentSession {
            let idx = textIndexCache.index(for: session.snapshot)
            return EditorHighlightProjection.evaluate(
                index: idx,
                caretLocation: currentSelection.location,
                bracketResult: bracketResult,
                backtickResult: backtickResult,
                wordOccurrenceRanges: occurrences
            )
        }
        return EditorHighlightProjection.evaluate(
            text: "",
            caretLocation: currentSelection.location,
            bracketResult: bracketResult,
            backtickResult: backtickResult,
            wordOccurrenceRanges: occurrences
        )
    }

    @ObservationIgnored private var wordOccurrenceCache: (
        id: DocumentID,
        revision: BufferRevision,
        selection: SwiftEditCore.TextRange,
        ranges: [SwiftEditCore.TextRange]
    )?

    private func cachedWordOccurrencesForActiveSelection() -> [SwiftEditCore.TextRange] {
        guard currentSelection.length >= WordOccurrenceScanner.minWordUTF16Length,
              let session = activeDocumentSession else {
            return []
        }
        if let cache = wordOccurrenceCache,
           cache.id == session.id,
           cache.revision == session.revision,
           cache.selection == currentSelection {
            return cache.ranges
        }
        let ranges = WordOccurrenceScanner.scan(selection: currentSelection, in: session.snapshot)
        wordOccurrenceCache = (session.id, session.revision, currentSelection, ranges)
        return ranges
    }

    // MARK: Word completion (`REQ-020-01`)

    /// Delay after the last edit before the word cache is rebuilt off the main actor (`UI-012`).
    public nonisolated static let wordCompletionRebuildDebounce: Duration = .milliseconds(350)

    /// Last built per-document word cache; in memory only, dropped with the document (`SEC-012`).
    @ObservationIgnored private var wordCompletionCache: (id: DocumentID, revision: BufferRevision, index: WordCompletionIndex)?
    @ObservationIgnored private var wordCompletionRebuildTask: Task<Void, Never>?

    /// Suffix completing the word prefix typed just before the caret, or `nil` (binary/degraded tabs, log tail, no match).
    ///
    /// O(log n) lookup on the last built cache; a cache from another document triggers an immediate rebuild instead.
    public func wordCompletionSuffix(forPrefix prefix: String) -> String? {
        guard activeLogTail == nil, let session = activeDocumentSession,
              !session.isBinaryReadOnly, !session.snapshot.isDegradedPlainText else { return nil }
        guard let cache = wordCompletionCache, cache.id == session.id else {
            scheduleWordCompletionRebuild(debounce: .zero)
            return nil
        }
        return cache.index.completionSuffix(forPrefix: prefix)
    }

    /// Rebuilds the active document's word cache on a background task, excluding the word under the caret.
    public func scheduleWordCompletionRebuild(debounce: Duration = SwiftEditWorkbenchModel.wordCompletionRebuildDebounce) {
        guard activeLogTail == nil,
              let session = activeDocumentSession,
              !session.isBinaryReadOnly,
              !session.isDegradedPlainText else { return }
        if let cache = wordCompletionCache, cache.id == session.id, cache.revision == session.revision { return }
        let targetID = session.id
        wordCompletionRebuildTask?.cancel()
        wordCompletionRebuildTask = Task { @MainActor [weak self] in
            if debounce > .zero {
                try? await Task.sleep(for: debounce)
            }
            guard !Task.isCancelled,
                  let self,
                  self.activeLogTail == nil,
                  let current = self.activeDocumentSession,
                  current.id == targetID,
                  !current.isBinaryReadOnly,
                  !current.isDegradedPlainText else { return }
            if let cache = self.wordCompletionCache, cache.id == current.id, cache.revision == current.revision { return }
            let revision = current.revision
            let text = current.text
            let caret = self.currentSelection.location
            let worker = Task.detached(priority: .utility) {
                WordCompletionIndex.build(from: text, excluding: SwiftEditCore.TextRange(location: caret, length: 0))
            }
            let index = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled,
                  let latest = self.activeDocumentSession,
                  latest.id == targetID else { return }
            self.wordCompletionCache = (targetID, revision, index)
        }
    }

    /// Synchronously rebuilds the active word cache (tests and first-open paths).
    public func rebuildWordCompletionIndexNow() {
        guard activeLogTail == nil,
              let session = activeDocumentSession,
              !session.isBinaryReadOnly,
              !session.isDegradedPlainText else { return }
        wordCompletionRebuildTask?.cancel()
        wordCompletionCache = (
            session.id,
            session.revision,
            WordCompletionIndex.build(from: session.text, excluding: SwiftEditCore.TextRange(location: currentSelection.location, length: 0))
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
        let language = activeDocumentLanguage
        // YAML context (`.yaml` tab or Markdown frontmatter) takes precedence over Markdown list continuation.
        guard let smart = YAMLSmartIndentEngine.evaluateNewline(in: session.snapshot, caretLocation: caretLocation, language: language)
            ?? MarkdownSmartNewlineEngine.evaluateNewline(
                in: session.snapshot,
                caretLocation: caretLocation,
                isMarkdownDocument: language == .markdown
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
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
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
            savePreferences()
        }
    }

    public private(set) var palette: PurpleThemePalette
    /// Zoom-driven tab, navigator and gutter sizes (`REQ-009`).
    public var chromeMetrics: ZoomedChromeMetrics { ZoomedChromeMetrics(zoomPercent: zoomController.zoomPercent) }

    /// Gutter width for the active document: digit advance of the editor font at 100% times the zoom factor (`REQ-009`).
    public var gutterWidth: CGFloat {
        let digitAdvance = ("0" as NSString).size(withAttributes: [.font: typography.nsFont(.editor, size: CGFloat(zoomController.baseFontSizePoints))]).width
        return chromeMetrics.gutterWidth(lineCount: activeLineNumberGutter.lineCount, digitAdvanceAt100: digitAdvance)
    }
    /// Per-role font choices (`REQ-003`, `REQ-007`); views read fonts through `typography`, observing `typographyGeneration`.
    public private(set) var interfaceFont: FontChoice = .default
    public private(set) var editorFont: FontChoice = .default
    /// Selected terminal bundle identifier (`nil` = Auto, preferring iTerm2 when installed).
    public private(set) var preferredTerminalBundleID: String? = nil
    /// Bumped on every font change so SwiftUI re-renders views that resolve fonts through `typography`.
    public private(set) var typographyGeneration = 0
    @ObservationIgnored public let typography = AppTypography()

    /// Applies a font choice live to every view and the editor, then persists it; never mutates any buffer.
    public func setFontChoice(_ choice: FontChoice, for role: TypographyRole) {
        switch role {
        case .interface:
            guard interfaceFont != choice else { return }
            interfaceFont = choice
        case .editor:
            guard editorFont != choice else { return }
            editorFont = choice
        }
        typography.setChoice(choice, for: role)
        typographyGeneration &+= 1
        savePreferences()
    }

    /// Sets and persists the preferred terminal bundle ID (`nil` selects Auto).
    public func setPreferredTerminalBundleID(_ bundleID: String?) {
        let normalized: String?
        if let trimmed = bundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmed.isEmpty,
           TerminalCatalog.allowedBundleIdentifiers.contains(trimmed) {
            normalized = trimmed
        } else {
            normalized = nil
        }
        guard preferredTerminalBundleID != normalized else { return }
        preferredTerminalBundleID = normalized
        savePreferences()
    }

    /// Whether soft line wrapping is active in the editor (`Cmd+W`). Persisted in `~/.SwiftEdit/settings.json`.
    public var isWordWrapEnabled: Bool = true
    /// Whether SwiftEdit opens in macOS Full Screen on launch by default. Persisted in `~/.SwiftEdit/settings.json`.
    public var launchInFullScreen: Bool = true
    @ObservationIgnored private var didApplyInitialFullScreen = false

    /// `Cmd+W`: toggles soft line wrap / horizontal unwrap in the editor and persists the choice.
    public func toggleWordWrap() {
        isWordWrapEnabled.toggle()
        statusBannerMessage = isWordWrapEnabled ? "Word Wrap: ON" : "Word Wrap: OFF"
        savePreferences()
    }

    /// Updates whether SwiftEdit launches in full screen by default and persists the choice.
    public func setLaunchInFullScreen(_ enabled: Bool) {
        guard launchInFullScreen != enabled else { return }
        launchInFullScreen = enabled
        savePreferences()
    }

    /// Triggers initial macOS Full Screen once when the primary window attaches (skipped in headless tests).
    func applyInitialFullScreenIfNeeded(for window: NSWindow) {
        guard !didApplyInitialFullScreen else { return }
        didApplyInitialFullScreen = true
        guard launchInFullScreen,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !window.styleMask.contains(.fullScreen) else { return }
        DispatchQueue.main.async { [weak window] in
            guard let window, !window.styleMask.contains(.fullScreen) else { return }
            window.toggleFullScreen(nil)
        }
    }

    /// Opens a dropped or externally handed-off folder in the left Folder Navigator and expands the sidebar.
    public func openDroppedFolder(_ folderURL: URL) {
        let standardized = folderURL.standardizedFileURL
        isLeftSidebarCollapsed = false
        selectWorkspaceFolder(standardized)
        statusBannerMessage = "Opened folder \(standardized.lastPathComponent)."
    }

    /// Handles files and/or folders dragged onto the window or the macOS Dock/Finder icon:
    /// directories open first in the left Folder Navigator (establishing workspace scope), then files open in editor tabs.
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

    /// Persists appearance, zoom, font choices, word wrap, full-screen default, terminal height, and preferred terminal together so no setting overwrites another.
    private func savePreferences() {
        preferencesStore.save(EditorPreferences(
            appearanceMode: appearanceMode,
            zoomPercent: zoomController.zoomPercent,
            interfaceFont: interfaceFont,
            editorFont: editorFont,
            preferredTerminalBundleID: preferredTerminalBundleID,
            isWordWrapEnabled: isWordWrapEnabled,
            launchInFullScreen: launchInFullScreen,
            terminalPanelHeight: Int(terminalPanelHeight.rounded())
        ))
    }
    public var zoomController: EditorZoomController {
        didSet {
            savePreferences()
        }
    }

    public private(set) var tabSession: WorkspaceTabSession
    public private(set) var sessionsByID: [DocumentID: DocumentSession]
    public private(set) var savedBaselineByID: [DocumentID: DocumentSnapshot]
    /// Transient quarantined binary payload excluded from `sessionsByID` and released immediately on dismiss or tab switch (`BUG-007`, `MEM-002`, `DATA-003`).
    public private(set) var activeBinaryInspection: BinaryInspectionPresentation?
    public private(set) var selectedFolderURL: URL?
    public private(set) var selectedSidebarEntryURL: URL?
    public private(set) var grantedScopeRootURL: URL?
    public private(set) var folderEntries: [FolderEntryDescriptor] = []
    public private(set) var currentSelection = SwiftEditCore.TextRange(location: 0, length: 0)
    public private(set) var lintDiagnostics: [MarkdownLintDiagnostic] = [] {
        didSet { lintGeneration &+= 1 }
    }
    /// Bumped on every diagnostics assignment: O(1) cache key instead of comparing up to 1000 diagnostics per render.
    @ObservationIgnored private var lintGeneration: UInt64 = 0
    public private(set) var bracketResult: BracketBalanceResult?
    public private(set) var safetyBanner: InspectionSafetyBannerState
    public private(set) var statusBannerMessage: String?
    public var showMarkdownPreview: Bool = false
    public var showDiffPane: Bool = false
    public var isCheatSheetPresented: Bool = false
    public var isAboutSheetPresented: Bool = false
    /// Help → SwiftEdit Help: bundled README rendered offline with the native Markdown preview.
    public var isHelpSheetPresented: Bool = false
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
    public var isCheckingForUpdates: Bool = false
    public var updateCheckOutcome: UpdateCheckOutcome?
    public var isUpdateDialogPresented: Bool = false

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
    private let updateChecker: GitHubReleaseUpdateChecker
    private let installedTerminalBundleIDsProvider: @MainActor () -> Set<String>
    /// Unmasked host OS dark-mode detector consulted on Frame 0 initialization and `.auto` restoration (`UI-003`, `TEST-004`).
    private let systemDarkDetector: @MainActor () -> Bool
    private let savePanelProvider: @MainActor (String) -> URL?
    private let openPanelProvider: @MainActor (_ chooseDirectories: Bool, _ prompt: String?) -> URL?
    private let clipboardWriter: @MainActor (String) -> Void
    @ObservationIgnored weak var hostWindow: NSWindow?
    @ObservationIgnored private var distributedThemeObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var cachedParentNavigation: (folder: URL?, scope: URL?, canNavigate: Bool)?
    /// Per-revision line-break table shared by the gutter and the status bar so caret moves never rescan the buffer (`PERF-B2`).
    @ObservationIgnored private let textIndexCache = DocumentTextIndexCache()
    @ObservationIgnored private var cachedGutterProjection: (id: DocumentID, revision: BufferRevision, caret: Int, fontSize: Double, value: LineNumberGutterProjection)?
    @ObservationIgnored private var cachedStatusBarMetrics: (id: DocumentID, revision: BufferRevision, caret: Int, value: StatusBarMetricsProjection)?
    @ObservationIgnored private var cachedPreviewSourceLine: (id: DocumentID, revision: BufferRevision, caret: Int, value: Int)?
    @ObservationIgnored private var cachedVisibleLint: (generation: UInt64, caretLine: Int, visible: [MarkdownLintDiagnostic], severityByLine: [Int: MarkdownLintSeverity])?
    @ObservationIgnored private var cachedLintDetails: (generation: UInt64, caretLine: Int, details: [Int: String])?
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
        installedTerminalBundleIDsProvider: (@MainActor () -> Set<String>)? = nil
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
        self.updateChecker = GitHubReleaseUpdateChecker(fetcher: updateFetcher)
        self.installedTerminalBundleIDsProvider = installedTerminalBundleIDsProvider
            ?? { Set(TerminalCatalog.installedTerminals().map(\.bundleIdentifier)) }
        self.systemDarkDetector = systemDarkDetector
        self.savePanelProvider = savePanelProvider
        self.openPanelProvider = openPanelProvider
        self.clipboardWriter = clipboardWriter
        let resolvedPrefsStore: any PreferencesProviding
        if let preferencesStore {
            resolvedPrefsStore = preferencesStore
        } else if let preferencesSuiteName {
            resolvedPrefsStore = UserDefaultsPreferencesStore(suiteName: preferencesSuiteName)
        } else {
            resolvedPrefsStore = EditorPreferencesStore.defaultHomeJSONStore()
        }
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
        self.interfaceFont = prefs.interfaceFont
        self.editorFont = prefs.editorFont
        self.preferredTerminalBundleID = prefs.preferredTerminalBundleID
        self.isWordWrapEnabled = prefs.isWordWrapEnabled
        self.launchInFullScreen = prefs.launchInFullScreen
        self.terminalPanelHeight = CGFloat(prefs.terminalPanelHeight)

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let resolvedRecoveryURL = recoveryDirectoryURL ?? appSupport
            .appendingPathComponent("PH.SwiftEdit", isDirectory: true)
            .appendingPathComponent("SessionRecovery", isDirectory: true)
        self.recoveryStore = SessionRecoveryStore(recoveryDirectoryURL: resolvedRecoveryURL)

        let welcomeText = """
        # SwiftEdit — Sandbox Ready

        Welcome to **SwiftEdit** (Zed-minimal Purple Chrome + Inverted B/W TextKit 2 Canvas).

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

        // Enumerate installed font families off the main actor so Settings opens without a stall (`PERF-017-B2`).
        Task.detached(priority: .utility) { await SystemFontFamilyCache.shared.prewarm() }
        typography.setChoice(interfaceFont, for: .interface)
        typography.setChoice(editorFont, for: .editor)
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
        if let observer = terminalTerminationObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        embeddedTerminalRegistry.terminateAll()
        for tail in logTails.values { tail.stop() }
        diagnosticsTask?.cancel()
        updateCheckTask?.cancel()
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
            index: textIndexCache.index(for: session.snapshot),
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
        let snapshot = session.snapshot
        let value = StatusBarMetricsProjection.evaluate(
            snapshot: snapshot,
            index: textIndexCache.index(for: snapshot),
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

    /// Cached language of the active tab (`PERF-C1`): binary inspections and the empty workspace are `.plainText`; degraded
    /// buffers keep their tab language so lint reports `Paused` rather than `Off`.
    public var activeDocumentLanguage: DocumentLanguage {
        if activeBinaryInspection != nil { return .plainText }
        guard let activeID = tabSession.activeTabID,
              let tab = tabSession.tabs.first(where: { $0.id == activeID }) else {
            return .plainText
        }
        return tab.language
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
        guard let folderURL = openPanelProvider(true, "Grant Workspace Folder") else { return }
        selectWorkspaceFolder(folderURL)
    }

    public func openFileViaPanel() {
        guard let fileURL = openPanelProvider(false, nil) else { return }
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
        clipboardWriter(url.standardizedFileURL.path)
        statusBannerMessage = "Copied path to clipboard."
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
        } catch DomainError.fileTooLarge(let byteCount) where DocumentLanguage.resolve(filename: standardizedURL.lastPathComponent) == .log {
            openLogTailOnly(at: standardizedURL, byteCount: byteCount)
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
        } catch DomainError.fileTooLarge(let byteCount) where DocumentLanguage.resolve(filename: standardizedURL.lastPathComponent) == .log {
            if asyncOpenGeneration == expectedGeneration { openLogTailOnly(at: standardizedURL, byteCount: byteCount) }
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

    private func syncUntitledTabTitleIfNeeded(for id: DocumentID, session: DocumentSession) {
        guard let tab = tabSession.tabs.first(where: { $0.id == id }),
              tab.fileURL == nil else {
            return
        }
        let derived = TabTitleDeriver.untitledTitle(from: session.text)
        if tab.title != derived {
            try? tabSession.updateUntitledDisplayTitle(id: id, title: derived)
        }
    }

    public func newUntitledTab() {
        asyncOpenGeneration &+= 1
        activeBinaryInspection = nil
        let session = DocumentSession(text: "")
        sessionsByID[session.id] = session
        savedBaselineByID[session.id] = session.snapshot
        try? tabSession.openOrActivate(
            snapshot: session.snapshot,
            title: TabTitleDeriver.untitledTitle(from: ""),
            isDirty: true
        )
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
        logTails.removeValue(forKey: id)?.stop()
        logTailOnlyTabIDs.remove(id)
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

    public func handleEditorTextChanged(_ editorText: String) {
        // TextKit hands over an NSString-bridged buffer; normalize once so comparison and every downstream scan stay native (`PERF-B1`).
        let newText = NativeTextNormalizer.native(editorText)
        guard activeBinaryInspection == nil,
              let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly,
              (try? session.replaceFullTextIfChanged(newText)) == true else { return }
        sessionsByID[activeID] = session
        try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
        syncUntitledTabTitleIfNeeded(for: activeID, session: session)
        scheduleRecoveryPersist()
        refreshDiagnosticsForActiveDocument()
        scheduleWordCompletionRebuild()
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
        guard activeLogTail == nil else {
            statusBannerMessage = "Duplicate blocked while live log tail is active."
            return
        }
        guard let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID] else { return }
        guard !session.isBinaryReadOnly, safetyBanner.canSave else {
            statusBannerMessage = "Duplicate blocked: binary read-only file."
            return
        }
        do {
            _ = try session.duplicateLineOrSelection(selection: currentSelection)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            statusBannerMessage = nil
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Cmd+D failed: \(error)"
        }
    }

    public func formatActiveDocument() {
        guard activeLogTail == nil else {
            statusBannerMessage = "Format blocked while live log tail is active."
            return
        }
        guard let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
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
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
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
        guard !logTailOnlyTabIDs.contains(activeID) else {
            statusBannerMessage = "Save blocked: this log is too large to edit and is shown as a live tail only."
            return
        }
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

    /// Prompts for a destination via the injected save-panel seam and saves the active document there; rejected fail-closed on binary read-only and tail-only buffers before any panel is shown (`DATA-003`, `UI-008`).
    public func saveActiveDocumentAsViaPanel() {
        guard let activeID = tabSession.activeTabID,
              let session = activeDocumentSession else { return }
        guard !logTailOnlyTabIDs.contains(activeID) else {
            statusBannerMessage = "Save As blocked: this log is too large to edit and is shown as a live tail only."
            return
        }
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
        guard !logTailOnlyTabIDs.contains(activeID) else {
            statusBannerMessage = "Save blocked: this log is too large to edit and is shown as a live tail only."
            return
        }
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

    /// Language-dispatched lint shared by the synchronous and background refresh paths (`REQ-003`, `REQ-004`).
    ///
    /// Markdown runs the 26-rule `.allConstructs` linter (security fast path on deadline) plus frontmatter `YML00x` rules;
    /// YAML runs `YAMLStructureLinter`; plain text is never linted.
    nonisolated static func lintDiagnostics(for snap: DocumentSnapshot, language: DocumentLanguage) -> [MarkdownLintDiagnostic] {
        switch language {
        case .plainText, .log:
            return []
        case .yaml:
            return YAMLStructureLinter.lint(snapshot: snap)
        case .markdown:
            var lint: [MarkdownLintDiagnostic]
            switch MarkdownLintAndFormatEngine.lint(snapshot: snap, profile: .allConstructs) {
            case .completed(let result):
                lint = result.diagnostics
            case .degradedOrTimedOut(.deadlineExceeded):
                lint = MarkdownLintAndFormatEngine.lintSecurityFastPath(snapshot: snap).completedValue?.diagnostics ?? []
            case .degradedOrTimedOut:
                lint = []
            }
            lint += YAMLStructureLinter.lint(snapshot: snap, frontmatterOnly: true)
            return lint
        }
    }

    /// Refreshes lint, bracket topology, backticks, safety banner, and diff state: synchronous below `4096` UTF-8 bytes, off-`@MainActor` with `(DocumentID, BufferRevision)` race protection above `4096` (`PERF-002`, `PERF-006`, `N11`).
    public func refreshDiagnosticsForActiveDocument() {
        schedulePreviewProjectionIfNeeded()
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
        let language = activeDocumentLanguage

        if snap.text.utf8.count <= Self.syncDiagnosticThresholdUTF8 {
            safetyBanner = InspectionSafetyBannerState.evaluate(snapshot: snap)
            lintDiagnostics = Self.lintDiagnostics(for: snap, language: language)
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
            refreshCompare()
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
        if language == .plainText {
            lintDiagnostics = []
            isDiagnosticsPopoverPresented = false
        }

        let targetID = snap.id
        let targetRevision = snap.revision
        let reusableTopology = (bracketTopologyCache?.id == targetID && bracketTopologyCache?.revision == targetRevision) ? bracketTopologyCache?.topology : nil
        let hasReusableBackticks = (backtickCache?.id == targetID && backtickCache?.revision == targetRevision)
        let reusableBackticks = hasReusableBackticks ? backtickCache?.result : nil
        diagnosticsTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) { () -> (lint: [MarkdownLintDiagnostic], topology: BracketTopology?, backticks: BacktickHighlightResult?, safety: InspectionSafetyBannerState)? in
                guard !Task.isCancelled else { return nil }
                let safety = InspectionSafetyBannerState.evaluate(snapshot: snap)
                guard !Task.isCancelled else { return nil }
                let lint = Self.lintDiagnostics(for: snap, language: language)
                guard !Task.isCancelled else { return nil }
                let topology = reusableTopology ?? SearchDiffAndBracketEngine.scanTopology(in: snap).completedValue
                guard !Task.isCancelled else { return nil }
                let backticks = hasReusableBackticks ? reusableBackticks : BacktickHighlightScanner.scan(in: snap).completedValue
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
        refreshCompare()
    }

    /// Awaits any in-flight background diagnostic pass for deterministic verification (`PERF-006`, `N11`).
    /// Waits for the in-flight background preview projection, if any (tests and headless callers).
    public func awaitPendingPreview() async {
        await previewTask?.value
    }

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
        guard activeLogTail == nil,
              let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
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
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
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
        guard activeLogTail == nil,
              let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
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
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
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
        guard activeLogTail == nil,
              let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
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
        guard let folderURL = openPanelProvider(true, "Open All Files in Folder") else { return }
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
        let yaml = YAMLSmartIndentEngine.evaluateTab(in: session.snapshot, selection: currentSelection, outdent: outdent, language: activeDocumentLanguage)
        if yaml != .notApplicable { return yaml }
        return MarkdownSmartListEngine.evaluateIndent(
            in: session.snapshot,
            selection: currentSelection,
            outdent: outdent,
            isMarkdownDocument: (activeDocumentLanguage == .markdown)
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
                syncUntitledTabTitleIfNeeded(for: activeID, session: session)
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
    @ObservationIgnored private var updateCheckTask: Task<Void, Never>?
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

    /// `Option+\`: toggles the navigator (Markdown headings or YAML top-level keys) of the active writable, non-binary tab.
    public func toggleDocumentNavigator() {
        if navigatorState != nil { closeDocumentNavigator(); return }
        guard editorSyntaxLanguage != .plainText, let session = activeDocumentSession else { return }
        switch editorSyntaxLanguage {
        case .markdown: navigatorState = DocumentNavigatorState(headings: MarkdownHeadingOutlineEngine.outline(index: activeLineIndex() ?? MarkdownLineIndex(text: session.text)))
        case .yaml: navigatorState = DocumentNavigatorState(headings: YAMLOutlineEngine.outline(index: activeLineIndex() ?? MarkdownLineIndex(text: session.text)))
        case .plainText, .log: return
        }
    }

    @ObservationIgnored private var lineIndexCache: (id: DocumentID, revision: BufferRevision, index: MarkdownLineIndex)?

    /// One `MarkdownLineIndex` per `(DocumentID, BufferRevision)` shared by the editor validator, the navigator and the
    /// YAML outline (`PERF-017-B3`); a same-length edit is a new revision, so the cache can never be stale.
    public func activeLineIndex() -> MarkdownLineIndex? {
        guard let session = activeDocumentSession else { return nil }
        return lineIndex(for: session.id, revision: session.revision)
    }

    /// Shared index for `(id, revision)` when it matches the live session, else `nil`.
    public func lineIndex(for id: DocumentID, revision: BufferRevision) -> MarkdownLineIndex? {
        if let cache = lineIndexCache, cache.id == id, cache.revision == revision { return cache.index }
        guard let session = sessionsByID[id] ?? activeDocumentSession.flatMap({ $0.id == id ? $0 : nil }),
              session.revision == revision else { return nil }
        let index = MarkdownLineIndex(text: session.text)
        lineIndexCache = (id, revision, index)
        return index
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

    // MARK: Keyboard shortcuts side panel and clickable commands (`REQ-021-04`)

    /// Right-docked shortcuts panel (`⌥⌘/`, header keyboard icon); independent of the floating `⌘/` sheet.
    public var isShortcutsPanelVisible: Bool = false

    public func toggleShortcutsPanel() {
        isShortcutsPanelVisible.toggle()
        if !isShortcutsPanelVisible { requestEditorFocus() }
    }

    /// Floating sheet click: close the sheet first, then run the command on the editor once the sheet is gone.
    public func performCheatSheetCommandFromSheet(_ command: CheatSheetCommand) {
        isCheatSheetPresented = false
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.performCheatSheetCommand(command)
        }
    }

    /// Runs a CheatSheet row at the editor caret/selection (text actions) or on the workbench (everything else).
    public func performCheatSheetCommand(_ command: CheatSheetCommand) {
        if command.isTextViewAction {
            performEditorTextAction(command)
            return
        }
        switch command {
        case .newDocument: newUntitledTab()
        case .openFile: openFileViaPanel()
        case .openFolder: openFolderViaPanel()
        case .openAllFiles: openAllFilesInFolderViaPanel()
        case .save: if safetyBanner.canSave { saveActiveDocument() }
        case .saveAs: if safetyBanner.canSave { saveActiveDocumentAsViaPanel() }
        case .closeDocument: requestCloseActiveTab()
        case .quit: NSApp.terminate(nil)
        case .duplicate: if safetyBanner.canSave { performCommandD() }
        case .contextualActions: presentElementContextualMenu()
        case .formatDocument: if safetyBanner.canFormat { formatActiveDocument() }
        case .formatSection: if safetyBanner.canFormat { formatActiveSection() }
        case .bold: applyMarkdownCommand(.bold)
        case .italic: applyMarkdownCommand(.italic)
        case .inlineCode: applyMarkdownCommand(.inlineCode)
        case .insertLink: applyMarkdownCommand(.link)
        case .toggleTask: applyMarkdownCommand(.taskToggle)
        case .find: presentFindBar(mode: .find)
        case .findAndReplace: presentFindBar(mode: .findAndReplace)
        case .goToLine: presentFindBar(mode: .goToLine)
        case .toggleSidebar: toggleLeftSidebar()
        case .zoomIn: zoomController.zoomIn()
        case .zoomOut: zoomController.zoomOut()
        case .resetZoom: zoomController.resetZoom()
        case .toggleWordWrap: toggleWordWrap()
        case .togglePreview: toggleMarkdownPreview()
        case .toggleCompare: toggleDiffPane()
        case .toggleDiagnostics: toggleDiagnosticsPopover()
        case .documentNavigator: toggleDocumentNavigator()
        case .distractionFree: toggleDistractionFree()
        case .logTailDirect: startLogTail(mode: .direct)
        case .logTailInverse: startLogTail(mode: .inverse)
        case .toggleTerminal: toggleTerminalPanel()
        case .showCheatSheet: isCheatSheetPresented = true
        case .toggleShortcutsPanel: toggleShortcutsPanel()
        case .undo, .redo, .cut, .copy, .paste, .selectAll, .lineStart, .lineEnd: break
        }
        if command != .showCheatSheet, command != .toggleShortcutsPanel, command != .find, command != .findAndReplace,
           command != .goToLine, command != .documentNavigator, command != .contextualActions {
            requestEditorFocus()
        }
    }

    /// Focuses the writable editor text view and sends the standard AppKit action, so undo, clipboard, selection and
    /// caret moves behave exactly like their keyboard shortcuts on the current caret.
    private func performEditorTextAction(_ command: CheatSheetCommand) {
        guard let textView = Self.editableEditorTextView(in: hostWindow?.contentView) else { return }
        textView.window?.makeFirstResponder(textView)
        switch command {
        case .undo: textView.undoManager?.undo()
        case .redo: textView.undoManager?.redo()
        case .cut: textView.cut(nil)
        case .copy: textView.copy(nil)
        case .paste: textView.paste(nil)
        case .selectAll: textView.selectAll(nil)
        case .lineStart: textView.moveToBeginningOfLine(nil)
        case .lineEnd: textView.moveToEndOfLine(nil)
        default: break
        }
    }

    static func editableEditorTextView(in view: NSView?) -> SwiftEditNSTextView? {
        guard let view else { return nil }
        if let textView = view as? SwiftEditNSTextView, textView.isEditable { return textView }
        for child in view.subviews {
            if let found = editableEditorTextView(in: child) { return found }
        }
        return nil
    }

    // MARK: Header breadcrumb and appearance cycling (redesign-020)

    /// `[folder, file]` for the active tab: the open workspace folder (or the file's parent) and the tab title.
    public var headerBreadcrumb: [String] {
        guard let activeID = tabSession.activeTabID,
              let tab = tabSession.tabs.first(where: { $0.id == activeID }) else { return [] }
        let folder = selectedFolderURL?.lastPathComponent ?? tab.fileURL?.deletingLastPathComponent().lastPathComponent
        return [folder, tab.title].compactMap { $0 }.filter { !$0.isEmpty && $0 != "/" }
    }

    /// Status-bar theme toggle: Light -> Dark -> Auto -> Light.
    public func cycleAppearanceMode() {
        switch appearanceMode {
        case .light: appearanceMode = .black
        case .black: appearanceMode = .auto
        case .auto: appearanceMode = .light
        }
    }

    // MARK: ElementContextualMenu (`Cmd+Return`, `REQ-020-04`)

    /// Open contextual action palette for the captured selection, or `nil`.
    public var elementContextualMenu: ElementContextualMenuState?

    /// `true` for a writable, non-tailing tab; selection-only groups are filtered when nothing is selected (`REQ-021-05`).
    public var canPresentElementContextualMenu: Bool {
        guard activeLogTail == nil, safetyBanner.canSave,
              let session = activeDocumentSession, !session.isBinaryReadOnly else { return false }
        return currentSelection.upperBound <= session.text.utf16.count
    }

    /// Opens the palette for the current selection or caret; returns `false` (key not consumed) on binary/log tabs.
    @discardableResult
    public func presentElementContextualMenu(anchor: CGPoint? = nil) -> Bool {
        guard canPresentElementContextualMenu else { return false }
        headerSubmenu.escapePressed()
        navigatorState = nil
        elementContextualMenu = ElementContextualMenuState(selection: currentSelection, anchor: anchor)
        return true
    }

    /// Closes the palette and gives focus back to the editor with the original selection.
    public func closeElementContextualMenu() {
        guard let menu = elementContextualMenu else { return }
        elementContextualMenu = nil
        currentSelection = menu.selection
        programmaticSelectionToken += 1
        requestEditorFocus()
    }

    /// Return / click: toggles a group header or performs an action row (highlighted row when `rowID` is `nil`).
    public func activateElementContextualMenuRow(rowID: String? = nil) {
        if let rowID { elementContextualMenu?.highlight(rowID: rowID) }
        guard let row = elementContextualMenu?.highlightedRow else { return }
        switch row {
        case .group(let group, _):
            elementContextualMenu?.toggleGroup(group.id)
        case .action(let action, _):
            performElementContextualAction(action)
        }
    }

    /// Applies `action` to the captured selection as one `BufferRevision` (or runs a document action) and closes the palette.
    @discardableResult
    public func performElementContextualAction(_ action: ElementContextualAction) -> Bool {
        guard let menu = elementContextualMenu else { return false }
        elementContextualMenu = nil
        defer { requestEditorFocus() }
        if case .duplicateDocument = action.kind {
            return duplicateActiveDocument()
        }
        guard activeLogTail == nil, safetyBanner.canSave,
              let activeID = tabSession.activeTabID, !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID],
              let edit = ElementContextualActionCatalog.evaluate(action.kind, in: session.snapshot, selection: menu.selection) else {
            return false
        }
        do {
            _ = try session.applyTextEdits(edit.edits, expectedRevision: session.revision)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            currentSelection = edit.newSelection
            programmaticSelectionToken += 1
            scheduleRecoveryPersist()
            refreshDiagnosticsForActiveDocument()
            return true
        } catch {
            statusBannerMessage = "Contextual action failed: \(error)"
            return false
        }
    }

    /// Duplicates the active document next to its tab (`REQ-021-05`).
    ///
    /// - File-backed: writes the current buffer (unsaved edits included) to `name copy.ext` in the same folder through the
    ///   confined atomic `DocumentLoader.save`, never overwriting an existing file, then opens it.
    /// - In-memory (untitled): opens a new untitled tab with the same text; nothing touches the disk.
    @discardableResult
    public func duplicateActiveDocument() -> Bool {
        // A transient binary inspection hides the active tab: never duplicate the document behind it (`DATA-003`).
        guard activeLogTail == nil, activeBinaryInspection == nil, safetyBanner.canSave,
              let activeID = tabSession.activeTabID, !logTailOnlyTabIDs.contains(activeID),
              let session = sessionsByID[activeID], !session.isBinaryReadOnly else {
            statusBannerMessage = "Duplicate Document is not available for binary or live-tail tabs."
            return false
        }
        let sourceIndex = tabSession.tabs.firstIndex { $0.id == activeID } ?? max(0, tabSession.tabs.count - 1)
        if let sourceURL = session.fileURL {
            guard let target = DuplicateDocumentNaming.copyURL(for: sourceURL, exists: { FileManager.default.fileExists(atPath: $0.path) }) else {
                statusBannerMessage = "Duplicate failed: no free “copy” name next to \(sourceURL.lastPathComponent)."
                return false
            }
            let scope = resolveSaveScope(for: target)
            let copy = DocumentSession(text: session.text, encoding: session.encoding, lineEnding: session.lineEnding)
            do {
                guard !FileManager.default.fileExists(atPath: target.path) else { throw CocoaError(.fileWriteFileExists) }
                _ = try loader.save(copy, to: target, withinScope: scope)
            } catch {
                statusBannerMessage = "Duplicate failed: \(error)"
                return false
            }
            openFile(at: target, withinScope: scope)
            refreshFolderEntries()
        } else {
            newUntitledTab()
            handleEditorTextChanged(session.text)
        }
        guard let newID = tabSession.activeTabID, newID != activeID else { return false }
        moveTab(id: newID, toIndex: min(sourceIndex + 1, tabSession.tabs.count - 1))
        statusBannerMessage = "Duplicated as \(tabSession.tabs.first { $0.id == newID }?.title ?? "new tab")."
        return true
    }

    /// ESC layering: contextual menu, header submenu, navigator, then distraction-free. Returns `true` when consumed.
    @discardableResult
    public func handleEscape() -> Bool {
        if elementContextualMenu != nil { closeElementContextualMenu(); return true }
        if headerSubmenu.isOpen { dismissHeaderSubmenu(); return true }
        if navigatorState != nil { closeDocumentNavigator(); return true }
        if isDistractionFree { toggleDistractionFree(); return true }
        return false
    }

    // MARK: Terminal panel (Cmd+J — Embedded SwiftTerm PTY Emulator)

    /// Embedded terminal sessions of the bottom panel; each owns an in-app `SwiftTerm.LocalProcessTerminalView` PTY
    /// that terminates cleanly when its tab, the panel, or SwiftEdit closes (never leaving orphan terminals open).
    public private(set) var terminalSessions: [TerminalPanelSession] = []
    public private(set) var isTerminalPanelVisible = false
    public var selectedTerminalSessionID: UUID?
    /// User-resizable height of the bottom embedded terminal panel (clamped `120...720 pt`).
    public var terminalPanelHeight: CGFloat = 240
    public static let minTerminalPanelHeight: CGFloat = 120
    public static let maxTerminalPanelHeight: CGFloat = 720

    public func setTerminalPanelHeight(_ height: CGFloat, maxAvailableHeight: CGFloat? = nil, persist: Bool = true) {
        let upperBound: CGFloat
        if let maxAvailableHeight, maxAvailableHeight.isFinite, maxAvailableHeight > Self.minTerminalPanelHeight {
            upperBound = min(Self.maxTerminalPanelHeight, max(Self.minTerminalPanelHeight, maxAvailableHeight))
        } else {
            upperBound = Self.maxTerminalPanelHeight
        }
        let clamped = min(max(Self.minTerminalPanelHeight, height), upperBound)
        if abs(clamped - terminalPanelHeight) > 0.25 {
            terminalPanelHeight = clamped
            if persist { savePreferences() }
        } else if persist {
            savePreferences()
        }
    }
    @ObservationIgnored public let embeddedTerminalRegistry = EmbeddedTerminalRegistry()
    @ObservationIgnored private var terminalSessionCounter = 0
    /// Real user home directory.
    @ObservationIgnored public var userHomeDirectoryProvider: () -> URL = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir { return URL(fileURLWithPath: String(cString: dir), isDirectory: true) }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// `Cmd+J`: opening shows the embedded terminal panel and starts a shell session; closing hides it and terminates every child shell cleanly.
    public func toggleTerminalPanel() {
        if isTerminalPanelVisible {
            isTerminalPanelVisible = false
            embeddedTerminalRegistry.terminateAll()
            terminalSessions.removeAll()
            selectedTerminalSessionID = nil
            requestEditorFocus()
        } else {
            isTerminalPanelVisible = true
            if terminalSessions.isEmpty { openTerminalSession() }
        }
    }

    /// Adds an embedded terminal session running the user's interactive shell in the current folder (or home when no folder is open).
    @discardableResult
    public func openTerminalSession() -> TerminalPanelSession {
        terminalSessionCounter += 1
        let directory = (selectedFolderURL ?? userHomeDirectoryProvider()).standardizedFileURL
        let shellPath = EmbeddedTerminalRegistry.defaultShellPath()
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent
        var session = TerminalPanelSession(title: "Terminal \(terminalSessionCounter)", directory: directory)
        session.state = .running(appName: shellName, since: Date())
        terminalSessions.append(session)
        selectedTerminalSessionID = session.id
        isTerminalPanelVisible = true
        return session
    }

    /// Restarts the embedded PTY shell for `id` in its working directory.
    public func relaunchTerminalSession(id: UUID) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        let shellName = URL(fileURLWithPath: EmbeddedTerminalRegistry.defaultShellPath()).lastPathComponent
        terminalSessions[index].state = .running(appName: shellName, since: Date())
        embeddedTerminalRegistry.restart(sessionID: id, directory: terminalSessions[index].directory)
    }

    /// Updates a session's state when its embedded PTY child shell exits (`exit`, `Ctrl+D`, or signal).
    public func embeddedTerminalDidTerminate(id: UUID, exitCode: Int32?) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        if exitCode == 0 {
            // Normal shell exit (`exit` / `Ctrl+D`): close the tab cleanly so no dead terminal remains.
            closeTerminalSession(id: id)
        } else {
            let detail = exitCode.map { "exited with code \($0)" } ?? "terminated"
            terminalSessions[index].state = .failed(message: "Shell \(detail). Click Restart to open a new shell.")
        }
    }

    /// Records a launch failure from `LocalProcessTerminalViewDelegate` without crashing the editor.
    public func embeddedTerminalDidFail(id: UUID, message: String) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        terminalSessions[index].state = .failed(message: "Terminal could not start: \(message)")
    }

    /// Updates the working directory tracked for an embedded terminal session when the shell emits OSC 7.
    public func embeddedTerminalDidUpdateDirectory(id: UUID, directory: String?) {
        guard let directory, !directory.isEmpty,
              let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        let url: URL?
        if directory.hasPrefix("file://") {
            url = URL(string: directory)
        } else {
            url = URL(fileURLWithPath: directory, isDirectory: true)
        }
        if let url {
            terminalSessions[index].directory = url.standardizedFileURL
        }
    }

    @ObservationIgnored private var terminalTerminationObserver: (any NSObjectProtocol)?

    /// Records that an external terminal with `bundleIdentifier` terminated (kept for sidebar external handoff compatibility).
    func terminalApplicationDidTerminate(bundleIdentifier: String?) {
        guard let bundleIdentifier else { return }
        for index in terminalSessions.indices where terminalSessions[index].bundleIdentifier == bundleIdentifier {
            if case .running(let name, _) = terminalSessions[index].state {
                terminalSessions[index].state = .failed(message: "\(name) quit or crashed. Use Restart to reopen it.")
            }
        }
    }

    public func closeTerminalSession(id: UUID) {
        embeddedTerminalRegistry.terminate(sessionID: id)
        terminalSessions.removeAll { $0.id == id }
        if selectedTerminalSessionID == id { selectedTerminalSessionID = terminalSessions.last?.id }
        if terminalSessions.isEmpty { isTerminalPanelVisible = false; requestEditorFocus() }
    }

    // MARK: Log function (live tail)

    /// Live tails keyed by tab; a tab keeps its controller (and last snapshot) until the panel is closed.
    public private(set) var logTails: [DocumentID: LogTailController] = [:]
    /// Tabs opened as tail-only because the log exceeds the open size gate: never editable or savable.
    public private(set) var logTailOnlyTabIDs: Set<DocumentID> = []
    @ObservationIgnored public var logFileReader: any LogFileReading = LocalLogFileReader()

    /// Log panel controller of the active tab, if the Log function was started on it.
    public var activeLogTail: LogTailController? {
        guard activeBinaryInspection == nil, let id = tabSession.activeTabID else { return nil }
        return logTails[id]
    }

    /// `⌘L` (direct) / `⌘⇧L` (inverse): starts — or switches the mode of — the live tail of the active file-backed tab.
    /// The tail runs in the background; other tabs stay fully usable and the file stays writable by other processes.
    public func startLogTail(mode: LogTailMode) {
        guard activeBinaryInspection == nil, let id = tabSession.activeTabID,
              let url = tabSession.tabs.first(where: { $0.id == id })?.fileURL else {
            statusBannerMessage = "Log: save the document to a file first."
            return
        }
        if let existing = logTails[id] {
            existing.setMode(mode)
            existing.start()
            return
        }
        let controller = LogTailController(tabID: id, url: url, mode: mode, reader: logFileReader)
        logTails[id] = controller
        controller.start()
    }

    /// Pauses the live tail of the active tab (the last snapshot stays visible).
    public func stopLogTail() { activeLogTail?.stop() }

    /// Closes the Log panel and returns to the normal editor (tail-only tabs keep their stopped tail visible).
    public func closeLogTail() {
        guard let id = tabSession.activeTabID, let controller = logTails[id] else { return }
        controller.stop()
        guard !logTailOnlyTabIDs.contains(id) else { return }
        logTails.removeValue(forKey: id)
        requestEditorFocus()
    }

    /// Opens a log above the size gate as a read-only live tail (bounded window from the end of the file).
    private func openLogTailOnly(at url: URL, byteCount: UInt64) {
        let session = DocumentSession(fileURL: url, text: "")
        do {
            try tabSession.openOrActivate(snapshot: session.snapshot, title: url.lastPathComponent, fileURL: url, isDirty: false)
        } catch {
            statusBannerMessage = "Open failed: \(error)"
            return
        }
        activeBinaryInspection = nil
        showMarkdownPreview = false
        previewCache = nil
        isDiagnosticsPopoverPresented = false
        sessionsByID[session.id] = session
        savedBaselineByID[session.id] = session.snapshot
        logTailOnlyTabIDs.insert(session.id)
        refreshDiagnosticsForActiveDocument()
        let mb = Double(byteCount) / 1_048_576
        statusBannerMessage = String(format: "Log too large to edit (%.0f MB): showing a live tail of the last lines.", mb)
        startLogTail(mode: .direct)
    }

    // MARK: Frontmatter Properties panel (016)

    /// UI-only panel state (collapse) observed separately from the workbench to keep editor invalidation narrow.
    public let propertiesPanel = PropertiesPanelState()
    @ObservationIgnored private var propertiesCache: (id: DocumentID, revision: BufferRevision, model: FrontmatterPropertyModel?)?

    /// Parsed frontmatter of the active writable Markdown tab, cached per `(DocumentID, BufferRevision)`; `nil` otherwise.
    public var propertiesModel: FrontmatterPropertyModel? {
        guard editorSyntaxLanguage == .markdown, let session = activeDocumentSession else { return nil }
        if let cache = propertiesCache, cache.id == session.id, cache.revision == session.revision { return cache.model }
        let parsed = FrontmatterPropertyParser.parse(snapshot: session.snapshot)
        propertiesCache = (session.id, session.revision, parsed)
        return parsed
    }

    /// `true` only for a writable, non-binary Markdown tab whose buffer starts with a frontmatter block (`REQ-009`).
    public var isPropertiesPanelVisible: Bool { !isDistractionFree && propertiesModel != nil }

    /// Applies one Properties panel operation as a single `TextEdit` and `BufferRevision` on the active tab.
    ///
    /// The editor adopts the new text through its undo-registered programmatic update, so each panel commit is exactly
    /// one `Cmd+Z` step. Writer rejections leave the buffer untouched and surface a status banner.
    @discardableResult
    public func applyPropertyOperation(_ operation: FrontmatterPropertyOperation) -> FrontmatterWriteResult {
        guard let model = propertiesModel,
              let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID] else { return .rejected(.readOnly) }
        let result = FrontmatterPropertyWriter.apply(operation, model: model, snapshot: session.snapshot)
        guard case .edit(let edit) = result else {
            statusBannerMessage = "Property not changed: \(result)"
            return result
        }
        do {
            _ = try session.applyTextEdits([edit], expectedRevision: model.revision)
        } catch {
            return .staleRevision
        }
        sessionsByID[activeID] = session
        try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
        syncUntitledTabTitleIfNeeded(for: activeID, session: session)
        persistRecoveryState()
        refreshDiagnosticsForActiveDocument()
        return result
    }

    /// Language handed to the TextKit 2 validator: `.plainText` for binary, degraded or quarantined buffers (`DATA-003`).
    public var editorSyntaxLanguage: DocumentLanguage {
        guard let session = activeDocumentSession, !session.isBinaryReadOnly, !session.isDegradedPlainText, safetyBanner.canSave else { return .plainText }
        return activeDocumentLanguage
    }

    /// `true` when the Document Navigator (`Option+\`) can open for the active Markdown or YAML tab.
    public var isNavigatorEnabled: Bool {
        editorSyntaxLanguage != .plainText
    }

    /// `true` only for a writable, non-binary Markdown tab; gates the `Markdown` menu, table `Tab`, and preview (`DATA-003`, `UI-005`).
    public var isMarkdownMenuEnabled: Bool {
        guard let session = activeDocumentSession, !session.isBinaryReadOnly, safetyBanner.canSave else { return false }
        return (activeDocumentLanguage == .markdown)
    }

    /// Preview projection for the active tab; `nil` (zero work) while `showMarkdownPreview == false` or on binary and non-Markdown tabs (`SEC-004`, `SEC-012`).
    public var markdownPreviewDocument: GFMPreviewDocument? {
        _ = previewGeneration
        guard showMarkdownPreview, isMarkdownMenuEnabled, let session = activeDocumentSession else { return nil }
        if let cache = previewCache, cache.id == session.id, cache.revision == session.revision { return cache.document }
        guard session.text.utf8.count <= Self.syncPreviewThresholdUTF8 else {
            // Large buffers are projected off the main actor (`PERF-017-B1`); keep showing the previous projection of the
            // same document until the current revision settles (scheduled from `refreshDiagnosticsForActiveDocument`).
            return previewCache?.id == session.id ? previewCache?.document : nil
        }
        let document = MarkdownPreviewProjector.project(
            snapshot: session.snapshot,
            showPreview: true,
            lineIndex: activeLineIndex()
        )
        previewCache = (session.id, session.revision, document)
        return document
    }

    /// Buffers above this size are projected in the background (`PERF-017-B1`).
    static let syncPreviewThresholdUTF8 = 64 * 1024
    /// Bumped when a background projection lands so SwiftUI re-reads `markdownPreviewDocument`.
    public private(set) var previewGeneration = 0
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var previewTaskTarget: (id: DocumentID, revision: BufferRevision)?

    /// Starts (or keeps) one background projection for the active revision; superseded revisions are discarded.
    func schedulePreviewProjectionIfNeeded() {
        guard showMarkdownPreview, isMarkdownMenuEnabled, let session = activeDocumentSession,
              session.text.utf8.count > Self.syncPreviewThresholdUTF8 else { return }
        if let cache = previewCache, cache.id == session.id, cache.revision == session.revision { return }
        if let target = previewTaskTarget, target.id == session.id, target.revision == session.revision { return }
        previewTask?.cancel()
        let snapshot = session.snapshot
        let cachedIndex = (lineIndexCache?.id == snapshot.id && lineIndexCache?.revision == snapshot.revision) ? lineIndexCache?.index : nil
        previewTaskTarget = (snapshot.id, snapshot.revision)
        previewTask = Task { @MainActor [weak self] in
            let document = await Task.detached(priority: .userInitiated) {
                MarkdownPreviewProjector.project(snapshot: snapshot, showPreview: true, lineIndex: cachedIndex)
            }.value
            guard let self else { return }
            if self.previewTaskTarget?.id == snapshot.id && self.previewTaskTarget?.revision == snapshot.revision {
                self.previewTaskTarget = nil
            }
            guard !Task.isCancelled,
                  let current = self.activeDocumentSession, current.id == snapshot.id, current.revision == snapshot.revision else { return }
            self.previewCache = (snapshot.id, snapshot.revision, document)
            self.previewGeneration &+= 1
        }
    }

    /// 1-based source line of the caret counting `\r\n`, `\n`, and `\r`, cached per `(DocumentID, BufferRevision, caretLocation)` and answered in `O(log L)` via `textIndexCache` (`BUG-016`, `UI-007`).
    public var previewSourceLine: Int {
        guard let session = activeDocumentSession else { return 0 }
        let caret = currentSelection.location
        if let cached = cachedPreviewSourceLine,
           cached.id == session.id,
           cached.revision == session.revision,
           cached.caret == caret {
            return cached.value
        }
        guard caret > 0 else {
            cachedPreviewSourceLine = (session.id, session.revision, caret, 1)
            return 1
        }
        let idx = textIndexCache.index(for: session.snapshot)
        let clampedCaret = min(caret, idx.utf16Count)
        let line = idx.cursorLineAndColumn(caret: clampedCaret)?.line ?? 1
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

    /// Status-bar lint state: Off for plain-text and binary tabs, Paused for degraded buffers, Active otherwise (`DATA-003`).
    public var activeLintStatus: ActiveLintStatus {
        guard let session = activeDocumentSession else { return .off }
        return ActiveLintStatus.classify(
            language: activeDocumentLanguage,
            snapshot: session.snapshot,
            diagnosticCount: lintDiagnostics.count
        )
    }

    private func resolvedVisibleLintCache() -> (visible: [MarkdownLintDiagnostic], severityByLine: [Int: MarkdownLintSeverity]) {
        let caretLine = previewSourceLine
        if let cached = cachedVisibleLint, cached.caretLine == caretLine, cached.generation == lintGeneration {
            return (cached.visible, cached.severityByLine)
        }
        let visible = ActiveLineLintSuppressionPolicy.visibleDiagnostics(lintDiagnostics, caretLine: caretLine)
        var severityByLine: [Int: MarkdownLintSeverity] = Dictionary(minimumCapacity: visible.count)
        for d in visible where severityByLine[d.line] != .error {
            severityByLine[d.line] = d.severity
        }
        cachedVisibleLint = (lintGeneration, caretLine, visible, severityByLine)
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

    /// Hover text per line for the gutter lint badge: one entry per diagnostic, `CODE: message` plus the rule explanation.
    public var gutterLintDetailsByLine: [Int: String] {
        let caretLine = previewSourceLine
        if let cached = cachedLintDetails, cached.generation == lintGeneration, cached.caretLine == caretLine { return cached.details }
        let details = Self.lintDetails(resolvedVisibleLintCache().visible)
        cachedLintDetails = (lintGeneration, caretLine, details)
        return details
    }

    nonisolated static func lintDetails(_ diagnostics: [MarkdownLintDiagnostic]) -> [Int: String] {
        var grouped: [Int: [String]] = [:]
        for d in diagnostics {
            let message = d.message.hasPrefix(d.rule.code) ? d.message : "\(d.rule.code): \(d.message)"
            grouped[d.line, default: []].append("\(message)\n\(d.rule.explanation)")
        }
        return grouped.mapValues { $0.joined(separator: "\n\n") }
    }

    /// Toggles the diagnostics popover (`⇧⌘M`); ignored while lint is Off or Paused.
    public func toggleDiagnosticsPopover() {
        guard case .active = activeLintStatus else { isDiagnosticsPopoverPresented = false; return }
        isDiagnosticsPopoverPresented.toggle()
    }

    /// Programmatically selects `range` in the active tab and asks the editor to adopt it; out-of-bounds ranges are ignored (`CWE-20`).
    public func selectRange(_ range: SwiftEditCore.TextRange) {
        guard let session = activeDocumentSession, range.location >= 0, range.length >= 0,
              range.upperBound <= session.text.utf16.count else { return }
        handleSelectionChanged(range)
        programmaticSelectionToken += 1
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
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
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
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
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
            previewTask?.cancel()
            previewTaskTarget = nil
            previewCache = nil
            PreviewThumbnailCache.shared.clear()
        } else {
            schedulePreviewProjectionIfNeeded()
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
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
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
            appearanceMode: appearanceMode
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
        case .showCheatSheet: isCheatSheetPresented = true
        case .appearanceLight: appearanceMode = .light
        case .appearanceDark: appearanceMode = .black
        case .appearanceAuto: appearanceMode = .auto
        }
    }

    public func toggleDiffPane() {
        showDiffPane.toggle()
        if showDiffPane {
            // The tab the Compare is opened from is the source; no destination = saved vs current (`REQ-022-01`).
            compareSourceTabID = tabSession.activeTabID
            compareDestinationTabID = nil
        } else {
            compareSourceTabID = nil
            compareDestinationTabID = nil
            diffCoordinator.clear()
        }
        refreshDiagnosticsForActiveDocument()
        refreshCompare()
    }

    // MARK: Compare source / destination (`REQ-022-01`)

    /// Tab the Compare was opened from (left column).
    public private(set) var compareSourceTabID: DocumentID?
    /// Optional second open tab compared against the source (right column); `nil` = saved vs current.
    public private(set) var compareDestinationTabID: DocumentID?

    /// Open text tabs selectable as destination (never the source, binary or tail-only tabs).
    public var compareDestinationCandidates: [TabDescriptor] {
        tabSession.tabs.filter { tab in
            tab.id != compareSourceTabID && !logTailOnlyTabIDs.contains(tab.id)
                && sessionsByID[tab.id].map { !$0.isBinaryReadOnly } == true
        }
    }

    public func title(ofTab id: DocumentID?) -> String? {
        guard let id else { return nil }
        return tabSession.tabs.first { $0.id == id }?.title
    }

    /// Picks the destination tab (`nil` returns to saved vs current); the destination tab itself stays open.
    public func setCompareDestination(_ id: DocumentID?) {
        if let id, !compareDestinationCandidates.contains(where: { $0.id == id }) { return }
        compareDestinationTabID = id
        diffCoordinator.clear()
        refreshCompare()
    }

    /// Recomputes the side-by-side rows for source vs destination, or source saved vs current when no destination.
    public func refreshCompare() {
        guard showDiffPane else { return }
        let openIDs = Set(tabSession.tabs.map(\.id))
        if let source = compareSourceTabID, !openIDs.contains(source) {
            compareSourceTabID = tabSession.activeTabID
            compareDestinationTabID = nil
        }
        if compareSourceTabID == nil { compareSourceTabID = tabSession.activeTabID }
        if let destination = compareDestinationTabID, !openIDs.contains(destination) || destination == compareSourceTabID {
            compareDestinationTabID = nil
        }
        guard let sourceID = compareSourceTabID, let source = sessionsByID[sourceID] else {
            diffCoordinator.clear()
            return
        }
        if let destinationID = compareDestinationTabID, let destination = sessionsByID[destinationID] {
            diffCoordinator.compare(lhs: source.snapshot, rhs: destination.snapshot)
        } else if let baseline = savedBaselineByID[sourceID] {
            diffCoordinator.compare(lhs: baseline, rhs: source.snapshot)
        }
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

    /// Opens the configured allowlisted terminal (`iTerm2` / Settings choice / `Terminal.app`) at `targetURL` (or its parent directory when `targetURL` is a file) (`SEC-004`).
    public func sidebarOpenInTerminal(at targetURL: URL) {
        let explicitID: String?
        if let selectedID = preferredTerminalBundleID,
           installedTerminalBundleIDsProvider().contains(selectedID) {
            explicitID = selectedID
        } else {
            explicitID = nil
        }
        do {
            _ = try desktopWorkspace.openInTerminal(
                targetURL: targetURL,
                withinScope: grantedScopeRootURL ?? selectedFolderURL,
                explicitBundleIdentifier: explicitID
            )
        } catch {
            statusBannerMessage = "Open Terminal blocked: \(error)"
        }
    }

    public var currentAppVersionString: String {
        AboutSheetDescriptor.resolveFromMainBundle().fullVersion
    }

    /// Queries GitHub Releases (`paonath/PH.SwiftEdit`) on user request and presents the update status dialog (`SEC-001`, `SEC-004`).
    public func checkForUpdates() {
        updateCheckTask?.cancel()
        isCheckingForUpdates = true
        updateCheckOutcome = nil
        isUpdateDialogPresented = true
        updateCheckTask = Task { @MainActor [weak self] in
            await self?.performUpdateCheck()
        }
    }

    /// Async core for `checkForUpdates()` enabling deterministic awaiting in headless tests (`TEST-004`).
    public func performUpdateCheck(currentVersionOverride: String? = nil, presentDialog: Bool = true) async {
        isCheckingForUpdates = true
        let version = currentVersionOverride ?? currentAppVersionString
        let outcome = await updateChecker.checkForUpdates(currentVersion: version)
        guard !Task.isCancelled else { return }
        isCheckingForUpdates = false
        updateCheckOutcome = outcome
        if presentDialog {
            isUpdateDialogPresented = true
        }
    }

    public func dismissUpdateDialog() {
        updateCheckTask?.cancel()
        isCheckingForUpdates = false
        isUpdateDialogPresented = false
    }

    public func openVerifiedUpdateURL(_ url: URL) {
        guard let verified = GitHubReleaseUpdateChecker.verifiedGitHubHTTPSURL(url.absoluteString) else { return }
        NSWorkspace.shared.open(verified)
    }

    public private(set) var isInstallingUpdate = false
    @ObservationIgnored public var updateInstaller = AppUpdateInstaller()

    /// Downloads, verifies SHA-256, schedules atomic replacement (preserving quarantine-free status), and quits SwiftEdit to relaunch automatically.
    public func installUpdateAndRelaunch(downloadURL: URL) {
        guard !isInstallingUpdate else { return }
        isInstallingUpdate = true
        updateCheckTask?.cancel()
        updateCheckTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.updateInstaller.stageAndScheduleInstall(downloadURL: downloadURL)
                self.isInstallingUpdate = false
                NSApp.terminate(nil)
            } catch {
                self.isInstallingUpdate = false
                self.updateCheckOutcome = .error(message: "Automatic update failed: \(error)")
            }
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
    @State private var hoveredTabID: DocumentID?
    @State private var isExternalDropTargeted = false
    @State private var dragStartSidebarRatio: Double?
    @State private var presentedDirtyAlertTabID: DocumentID?
    @State private var gutterViewportMetrics: GutterViewportMetrics?
    @State private var keyDownMonitor: Any?

    public init() {}

    init(initialModel: SwiftEditWorkbenchModel) {
        self._model = State(initialValue: initialModel)
    }

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
                        if let tail = model.activeLogTail, !model.isDistractionFree {
                            LogTailPanelView(model: model, tail: tail)
                        }
                        if model.isPropertiesPanelVisible {
                            PropertiesPanelView(model: model, state: model.propertiesPanel)
                        }
                        editorAndOptionalPanels
                        if model.isTerminalPanelVisible, !model.isDistractionFree {
                            TerminalPanelView(model: model)
                        }
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
            ElementContextualMenuView(model: model)
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
        applyAlerts(to: applySheets(to: applyLifecycleAndObservers(to: baseRootView)))
            .environment(\.appTypography, AppTypographyContext(typography: model.typography, generation: model.typographyGeneration))
    }

    private var baseRootView: some View {
        layoutContent
            .background(HostingWindowFinder { window in
                model.hostWindow = window
                if let window {
                    model.applyInitialFullScreenIfNeeded(for: window)
                }
            })
            .background(model.palette.chromeSurface.swiftUIColor)
            .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
            .preferredColorScheme(model.preferredSwiftUIColorScheme)
            .frame(minWidth: 960, minHeight: 620)
            .onDrop(of: [UTType.fileURL], isTargeted: $isExternalDropTargeted) { providers in
                handleExternalFileDrop(providers: providers)
            }
            .overlay {
                if isExternalDropTargeted {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(model.palette.chromeAccent.swiftUIColor, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .focusedSceneValue(\.workbenchModel, model)
    }

    private func handleExternalFileDrop(providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }
        let activeModel = model
        for provider in matching {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let resolvedURL: URL?
                if let data = item as? Data {
                    resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolvedURL = url
                } else if let str = item as? String {
                    resolvedURL = URL(string: str)
                } else {
                    resolvedURL = nil
                }
                guard let resolvedURL, resolvedURL.isFileURL else { return }
                Task { @MainActor in
                    activeModel.openDroppedURLs([resolvedURL])
                }
            }
        }
        return true
    }

    @ViewBuilder
    private func applyLifecycleAndObservers<Content: View>(to content: Content) -> some View {
        content
            .onAppear {
                SwiftEditAppLifecycleBridge.shared.attach(workbench: model)
                model.windowFullScreenQuery = { NSApp.keyWindow?.styleMask.contains(.fullScreen) ?? false }
                model.windowFullScreenToggle = { NSApp.keyWindow?.toggleFullScreen(nil) }
                model.refreshUnmaskedSystemAppearance()
                model.updateAccessibilityPreferences(
                    reduceTransparency: reduceTransparency,
                    increasedContrast: colorSchemeContrast == .increased
                )
                attachKeyDownMonitor()
            }
            .onDisappear {
                detachKeyDownMonitor()
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
    }

    @ViewBuilder
    private func applySheets<Content: View>(to content: Content) -> some View {
        content
            .sheet(isPresented: $model.isCheatSheetPresented) {
                KeyboardShortcutsCheatSheetView(
                    palette: model.palette,
                    onClose: {
                        model.isCheatSheetPresented = false
                        model.requestEditorFocus()
                    },
                    onPerform: { model.performCheatSheetCommandFromSheet($0) },
                    onDock: {
                        model.isCheatSheetPresented = false
                        model.isShortcutsPanelVisible = true
                    }
                )
            }
            .sheet(isPresented: $model.isHelpSheetPresented) {
                HelpDocumentationView(palette: model.palette) {
                    model.isHelpSheetPresented = false
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
            .sheet(isPresented: $model.isUpdateDialogPresented) {
                UpdateCheckSheetView(model: model, palette: model.palette) {
                    model.dismissUpdateDialog()
                    model.requestEditorFocus()
                }
            }
    }

    @ViewBuilder
    private func applyAlerts<Content: View>(to content: Content) -> some View {
        content
            .alert("Unsaved Changes", isPresented: dirtyCloseAlertPresented) {
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
            .alert("Open All Files in Folder?", isPresented: batchOpenAlertPresented) {
                Button("Open \(model.pendingBatchOpenPlan?.files.count ?? 0) Files") { model.confirmPendingBatchOpen() }
                Button("Cancel", role: .cancel) { model.cancelPendingBatchOpen() }
            } message: {
                Text("This folder contains more than 50 text files (\(model.pendingBatchOpenPlan?.files.count ?? 0) eligible files). Open all?")
            }
            .alert("Move Item to Trash?", isPresented: trashItemAlertPresented) {
                Button("Move to Trash", role: .destructive) { model.confirmPendingTrashItem() }
                Button("Cancel", role: .cancel) { model.cancelPendingTrashItem() }
            } message: {
                Text(model.pendingTrashItemURL?.lastPathComponent ?? "")
            }
    }

    private var dirtyCloseAlertPresented: Binding<Bool> {
        Binding(
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
    }

    private var batchOpenAlertPresented: Binding<Bool> {
        Binding(
            get: { model.pendingBatchOpenPlan != nil },
            set: { if !$0 { model.cancelPendingBatchOpen() } }
        )
    }

    private var trashItemAlertPresented: Binding<Bool> {
        Binding(
            get: { model.pendingTrashItemURL != nil },
            set: { if !$0 { model.cancelPendingTrashItem() } }
        )
    }

    private func attachKeyDownMonitor() {
        guard keyDownMonitor == nil else { return }
        let activeModel = model
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Fast path: plain typing, Shift, and Ctrl (e.g. Ctrl+C/D/L in terminal) have no Cmd/Opt shortcut;
            // except Up/Down/Return/Escape when the Document Navigator overlay is open.
            let cmdOrOpt = event.modifierFlags.intersection([.command, .option])
            let isNavigatorControlKey = event.keyCode == 36 || event.keyCode == 76 || event.keyCode == 125 || event.keyCode == 126 || event.keyCode == 53
                || event.keyCode == 123 || event.keyCode == 124
            if cmdOrOpt.isEmpty && !isNavigatorControlKey {
                return event
            }
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let eventWindow = event.window, eventWindow.attachedSheet == nil else {
                    return false
                }
                if let ownerWindow = activeModel.hostWindow {
                    guard eventWindow === ownerWindow else { return false }
                } else if eventWindow.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" || eventWindow.isSheet {
                    return false
                }
                if activeModel.elementContextualMenu != nil, cmdOrOpt.isEmpty {
                    switch event.keyCode {
                    case 36, 76: // Return / Numpad Enter
                        activeModel.activateElementContextualMenuRow()
                        return true
                    case 125: // Down Arrow
                        activeModel.elementContextualMenu?.moveHighlight(1)
                        return true
                    case 126: // Up Arrow
                        activeModel.elementContextualMenu?.moveHighlight(-1)
                        return true
                    case 124 where activeModel.elementContextualMenu?.query.isEmpty == true: // Right Arrow expands
                        activeModel.elementContextualMenu?.setHighlightedGroupExpanded(true)
                        return true
                    case 123 where activeModel.elementContextualMenu?.query.isEmpty == true: // Left Arrow collapses
                        activeModel.elementContextualMenu?.setHighlightedGroupExpanded(false)
                        return true
                    case 53: // Escape
                        activeModel.closeElementContextualMenu()
                        return true
                    default:
                        return false
                    }
                }
                if activeModel.navigatorState != nil, cmdOrOpt.isEmpty {
                    switch event.keyCode {
                    case 36, 76: // Return / Numpad Enter
                        activeModel.confirmDocumentNavigator()
                        return true
                    case 125: // Down Arrow
                        activeModel.navigatorState?.moveDown()
                        return true
                    case 126: // Up Arrow
                        activeModel.navigatorState?.moveUp()
                        return true
                    case 53: // Escape
                        activeModel.closeDocumentNavigator()
                        return true
                    default:
                        break
                    }
                }
                if cmdOrOpt.isEmpty {
                    return false
                }
                guard !activeModel.isCheatSheetPresented,
                      !activeModel.isAboutSheetPresented,
                      !activeModel.isHelpSheetPresented,
                      !activeModel.isUpdateDialogPresented,
                      activeModel.pendingDirtyCloseTabID == nil,
                      activeModel.pendingBatchOpenPlan == nil,
                      activeModel.pendingTrashItemURL == nil else {
                    return false
                }
                let responder = eventWindow.firstResponder
                // When the embedded SwiftTerm terminal is focused, only intercept Cmd+J (toggle terminal)
                // and let all other terminal shortcuts (Option-as-Meta, Cmd+C/V/K, etc.) pass straight to SwiftTerm.
                if responder is SwiftEditTerminalView {
                    let mods = event.modifierFlags.intersection(ShortcutKeyEvent.relevantModifierMask)
                    if mods == [.command], (event.charactersIgnoringModifiers ?? "").lowercased() == "j" {
                        activeModel.toggleTerminalPanel()
                        return true
                    }
                    return false
                }
                let isEditingOverlayTextField = (responder is NSTextView) && !(responder is SwiftEditNSTextView)
                // Cmd+Return on an editor selection opens the contextual palette right under the selection.
                if let editor = responder as? SwiftEditNSTextView,
                   event.modifierFlags.intersection(ShortcutKeyEvent.relevantModifierMask) == [.command],
                   event.keyCode == 36 || event.keyCode == 76 {
                    return activeModel.presentElementContextualMenu(anchor: Self.selectionAnchor(in: editor))
                }
                return SwiftEditShortcutDispatcher.dispatch(event: event, model: activeModel, isEditingOverlayTextField: isEditingOverlayTextField)
            }
            return consumed ? nil : event
        }
    }

    /// Bottom-left of the selection's first line in window-content coordinates (y down), or `nil`.
    @MainActor
    static func selectionAnchor(in textView: NSTextView) -> CGPoint? {
        guard let window = textView.window, let content = window.contentView else { return nil }
        let selection = textView.selectedRange()
        let screenRect = textView.firstRect(forCharacterRange: NSRange(location: selection.location, length: 0), actualRange: nil)
        guard screenRect != .zero else { return nil }
        let inContent = content.convert(window.convertFromScreen(screenRect), from: nil)
        let y = content.isFlipped ? inContent.maxY : content.bounds.height - inContent.minY
        return CGPoint(x: inContent.minX, y: y)
    }

    private func detachKeyDownMonitor() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
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
                    .padding(.top, model.chromeMetrics.headerHeight)
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
                    onDismiss: { model.dismissHeaderSubmenu() },
                    scale: model.chromeMetrics.factor
                )
                .padding(.leading, 12)
                .offset(y: model.chromeMetrics.headerHeight)
                .zIndex(100)
            }
        }
    }

    /// Zed-style header: unchanged Concept E2 logo menu followed by the command icon cluster on the left, the
    /// `folder / file` breadcrumb on the right; every size follows the editor zoom (`REQ-021-02`, `REQ-021-03`).
    private var toolbarBar: some View {
        let metrics = model.chromeMetrics
        return HStack(spacing: 8 * metrics.factor) {
            Button(action: { model.headerSubmenu.clickToggle() }) {
                HStack(spacing: 6 * metrics.factor) {
                    SwiftEditBrandLogoView(size: metrics.headerLogoSize)
                    Text("SwiftEdit")
                        .appFont(size: metrics.headerFontSize, weight: .semibold)
                        .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                    AppIconView(model.headerSubmenu.isOpen ? .chevronUp : .chevronDown, size: 10 * metrics.factor)
                        .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                }
                .padding(.horizontal, 6 * metrics.factor)
                .padding(.vertical, 3 * metrics.factor)
                .background(model.headerSubmenu.isOpen ? model.palette.accentSoftSurface.swiftUIColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6 * metrics.factor))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("SwiftEdit commands menu")
            .accessibilityLabel("SwiftEdit commands menu")
            .accessibilityValue(model.headerSubmenu.isOpen ? "Expanded" : "Collapsed")
            .accessibilityHint("Toggles the SwiftEdit command menu")

            HStack(spacing: 2 * metrics.factor) {
                headerIconButton(.sidebar, help: "Toggle Folder Navigator (⌘B)", isActive: !model.isLeftSidebarCollapsed) { model.toggleLeftSidebar() }
                headerIconButton(.search, help: "Find in Document (⌘F)", isActive: model.findReplaceState.mode != .hidden) { model.presentFindBar(mode: .find) }
                headerIconButton(.eye, help: "Toggle Markdown Preview (⌘P)", isActive: model.showMarkdownPreview) { model.toggleMarkdownPreview() }
                headerIconButton(.diff, help: "Toggle File Compare (⇧⌘D)", isActive: model.showDiffPane) { model.toggleDiffPane() }
                headerIconButton(.terminal, help: "Toggle Terminal Panel (⌘J)", isActive: model.isTerminalPanelVisible) { model.toggleTerminalPanel() }
                headerIconButton(.keyboard, help: "Toggle Keyboard Shortcuts Panel (⌥⌘/)", isActive: model.isShortcutsPanelVisible) { model.toggleShortcutsPanel() }
            }

            Spacer(minLength: 8)

            headerBreadcrumb
        }
        .padding(.horizontal, 12)
        .frame(height: metrics.headerHeight)
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

    /// `folder / file` breadcrumb of the active tab (muted folder, primary file name).
    @ViewBuilder
    private var headerBreadcrumb: some View {
        let parts = model.headerBreadcrumb
        if !parts.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    Text(verbatim: "/")
                        .foregroundStyle(model.palette.hairlineBorder.swiftUIColor)
                    Text(verbatim: part)
                        .foregroundStyle((index == parts.count - 1 ? model.palette.chromeForeground : model.palette.secondaryForeground).swiftUIColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: (index == parts.count - 1 ? 320 : 180) * model.chromeMetrics.factor, alignment: .trailing)
                        .fixedSize(horizontal: index == parts.count - 1, vertical: false)
                }
            }
            .appFont(size: model.chromeMetrics.headerFontSize, weight: .medium)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Current file: \(parts.joined(separator: ", "))")
        }
    }

    /// Icon-only toggle in the header cluster; active state uses the soft accent surface and accent glyph.
    private func headerIconButton(_ icon: AppIcon, help: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        let metrics = model.chromeMetrics
        return Button(action: action) {
            AppIconView(icon, size: metrics.headerIconSize)
                .foregroundStyle((isActive ? model.palette.chromeAccent : model.palette.secondaryForeground).swiftUIColor)
                .frame(width: metrics.headerIconButtonWidth, height: metrics.headerIconButtonHeight)
                .background(isActive ? model.palette.accentSoftSurface.swiftUIColor : Color.clear, in: RoundedRectangle(cornerRadius: 5 * metrics.factor))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func sidebarPercentageDivider(containerWidth: Double) -> some View {
        Rectangle()
            .fill(model.palette.hairlineBorder.swiftUIColor)
            .frame(width: 1)
            .padding(.horizontal, 2.5)
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

    /// Flat Zed-style tabs: the active tab merges with the canvas under a 2 pt accent line; close shows on the active or
    /// hovered tab, a dot marks unsaved tabs, a small pin marks pinned ones; reorder/pin live in drag and context menu (R-03).
    private var tabBar: some View {
        let metrics = model.chromeMetrics
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(model.tabSession.tabs, id: \.id) { tab in
                    let isActive = tab.id == model.tabSession.activeTabID
                    let isHovered = hoveredTabID == tab.id
                    HStack(spacing: 6) {
                        if tab.isPinned {
                            AppIconView(.pin, size: metrics.tabBadgeSize)
                                .foregroundStyle(model.palette.pinnedTabBadge.swiftUIColor)
                        }
                        Button(action: { model.activateTab(id: tab.id) }) {
                            Text(tab.title)
                                .appFont(size: metrics.tabFontSize, weight: isActive ? .medium : .regular)
                                .foregroundStyle((isActive ? model.palette.chromeForeground : model.palette.secondaryForeground).swiftUIColor)
                                .lineLimit(1)
                                .frame(minWidth: metrics.tabMinWidth, maxWidth: metrics.tabMaxWidth, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(tab.title)\(tab.isDirty ? ", unsaved" : "")\(tab.isPinned ? ", pinned" : "")")

                        Button(action: { model.requestCloseTab(id: tab.id) }) {
                            Group {
                                if tab.isDirty && !isActive && !isHovered {
                                    AppIconView(.dot, size: metrics.tabBadgeSize)
                                } else {
                                    AppIconView(.close, size: metrics.tabBadgeSize)
                                }
                            }
                            .minimumHitTarget(metrics.tabIconTarget)
                        }
                        .buttonStyle(.plain)
                        .opacity(isActive || isHovered || tab.isDirty ? 1 : 0)
                        .help("Close Tab (⇧⌘W)")
                        .accessibilityLabel("Close tab \(tab.title)")
                    }
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    .padding(.horizontal, metrics.tabHorizontalPadding + 4)
                    .frame(minHeight: metrics.tabHeight)
                    .background(isActive ? model.palette.tabActiveSurface.swiftUIColor : Color.clear)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(isActive ? model.palette.chromeAccent.swiftUIColor : Color.clear)
                            .frame(height: 2)
                    }
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(model.palette.hairlineBorder.swiftUIColor)
                            .frame(width: 1)
                    }
                    .contentShape(Rectangle())
                    .onHover { inside in hoveredTabID = inside ? tab.id : (hoveredTabID == tab.id ? nil : hoveredTabID) }
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
                .appFont(.caption)
                .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(model.palette.badgeSurface.swiftUIColor)
        }
    }

    private var sidebarView: some View {
        let metrics = model.chromeMetrics
        let sidebarFont = metrics.navigatorFontSize
        let headerFont = metrics.navigatorHeaderFontSize
        let rowSpacing = max(4, CGFloat(6.0 * model.zoomController.zoomScaleFactor))

        return VStack(alignment: .leading, spacing: rowSpacing) {
            HStack(spacing: 8) {
                Text((model.selectedFolderURL?.lastPathComponent ?? "No Folder Open").uppercased())
                    .appFont(size: headerFont, weight: .semibold)
                    .tracking(0.6)
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    .lineLimit(1)
                Spacer()
                if model.selectedFolderURL != nil {
                    Button(action: { model.navigateToParentFolder() }) {
                        AppIconView(.folderUp, size: headerFont + 3)
                            .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                            .minimumHitTarget()
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canNavigateToParentFolder)
                    .help("Go to parent folder (...)")
                    .accessibilityLabel("Go to parent folder")
                }
                Button(action: { model.toggleSidebarPinCollapse() }) {
                    AppIconView(.sidebar, size: headerFont + 3)
                        .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                        .minimumHitTarget()
                }
                .buttonStyle(.plain)
                .help("Unpin and Collapse Left Navigation Panel (Cmd+B)")
                .accessibilityLabel("Collapse left navigation panel")
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            if model.selectedFolderURL == nil {
                sidebarEmptyState
            }
            List {
                if model.canNavigateToParentFolder {
                    Button(action: { model.navigateToParentFolder() }) {
                        HStack(spacing: rowSpacing) {
                            AppIconView(.folderUp, size: metrics.navigatorIconSize + 1)
                                .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                            Text("...")
                                .appFont(size: sidebarFont, weight: .semibold)
                                .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Parent folder")
                }
                ForEach(model.folderEntries, id: \.url) { entry in
                    let binaryColor = model.palette.sidebarBinaryDisabledText.swiftUIColor
                    let icon: AppIcon = entry.isDirectory
                        ? .folder
                        : (entry.isBinary ? .fileBinary : (entry.isHiddenDotfile ? .eyeOff : .fileText))
                    let isSelected = model.selectedSidebarEntryURL == entry.url.standardizedFileURL
                    HStack(spacing: rowSpacing) {
                        AppIconView(icon, size: metrics.navigatorIconSize + 1)
                            .foregroundStyle(entry.isBinary ? binaryColor : (entry.isDirectory ? model.palette.chromeAccent : model.palette.secondaryForeground).swiftUIColor)
                        Text(entry.name)
                            .appFont(size: sidebarFont)
                            .foregroundStyle(entry.isBinary ? binaryColor : model.palette.chromeForeground.swiftUIColor)
                            .italic(entry.isBinary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: metrics.navigatorRowHeight, alignment: .leading)
                    .padding(.leading, max(0, metrics.navigatorIndent - 12))
                    .background(isSelected ? model.palette.accentSoftSurface.swiftUIColor : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { model.sidebarDoubleClick(entry) }
                    .onTapGesture(count: 1) { model.sidebarPrimaryClick(entry) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(entry.name)
                    .accessibilityAction(named: entry.isDirectory ? "Open Folder" : "Open File") {
                        model.sidebarDoubleClick(entry)
                    }
                    .help(entry.isDirectory
                        ? "Double-click to open folder"
                        : (entry.isBinary ? "Binary file (read-only disabled in sidebar)" : entry.name))
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

    /// Empty Folder Navigator: one clear call to action instead of a bare "No Folder Open" label (R-08).
    private var sidebarEmptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Open a folder to browse its files.")
                .appFont(.callout)
                .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
            Button(action: { model.openFolderViaPanel() }) {
                HStack(spacing: 6) {
                    AppIconView(.folder, size: 13)
                    Text("Open Folder…")
                        .appFont(.callout, weight: .medium)
                    Spacer(minLength: 4)
                    Text(verbatim: "⇧⌘O")
                        .appFont(.caption, monospaced: true)
                        .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                }
                .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(model.palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Folder")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
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
        Button("Copy Path to Clipboard") { model.sidebarCopyPathToClipboard(at: entry.url) }
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
            Button("Copy Folder Path to Clipboard") { model.sidebarCopyPathToClipboard(at: currentFolder) }
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
            if let tail = model.activeLogTail {
                // Read-only live tail view: its own document identity, follows the newest line (bottom in direct, top in inverse).
                TextKit2EditorView(
                    documentID: tail.viewID,
                    bufferRevision: BufferRevision(tail.generation),
                    text: tail.text,
                    isEditable: false,
                    isWordWrapEnabled: model.isWordWrapEnabled,
                    palette: model.palette,
                    fontSizePoints: model.zoomController.scaledFontSizePoints,
                    highlightProjection: EditorHighlightProjection(),
                    onTextChange: { _ in },
                    onSelectionChange: { _ in },
                    onSmartNewline: { _ in nil },
                    onListIndent: { _ in .notApplicable },
                    onTableTab: { _ in .notApplicable },
                    documentLanguage: .log,
                    programmaticSelection: SwiftEditCore.TextRange(location: tail.mode == .direct ? (tail.text as NSString).length : 0, length: 0),
                    programmaticSelectionToken: Int(truncatingIfNeeded: tail.generation),
                    onEscape: { model.handleEscape() },
                    typography: model.typography,
                    typographyGeneration: model.typographyGeneration
                )
                .accessibilityLabel("Live log tail")
            } else if let session = model.activeDocumentSession {
                HStack(spacing: 0) {
                    if !model.isDistractionFree {
                        LineNumberGutterView(
                            projection: model.activeLineNumberGutter,
                            palette: model.palette,
                            severityByLine: model.gutterSeverityByLine,
                            viewportMetrics: gutterViewportMetrics,
                            width: model.gutterWidth,
                            lintDetailsByLine: model.gutterLintDetailsByLine
                        )
                    }
                    TextKit2EditorView(
                        documentID: session.id,
                        bufferRevision: session.revision,
                        text: session.text,
                        isEditable: !session.isBinaryReadOnly,
                        isWordWrapEnabled: model.isWordWrapEnabled,
                        palette: model.palette,
                        fontSizePoints: model.zoomController.scaledFontSizePoints,
                        highlightProjection: model.activeHighlightProjection,
                        onTextChange: { model.handleEditorTextChanged($0) },
                        onSelectionChange: { model.handleSelectionChanged($0) },
                        onSmartNewline: { model.applySmartNewlineIfApplicable(at: $0) },
                        onListIndent: { model.listIndentationOutcome(outdent: $0) },
                        onTableTab: { model.tableTabOutcome(backward: $0) },
                        documentLanguage: model.editorSyntaxLanguage,
                        programmaticSelection: model.currentSelection,
                        programmaticSelectionToken: model.programmaticSelectionToken,
                        lintDiagnostics: model.visibleLintDiagnostics,
                        undoRegistry: model.undoRegistry,
                        editorFocusRequestToken: model.editorFocusRequestToken,
                        onViewportMetricsChange: { gutterViewportMetrics = $0 },
                        onEscape: { model.handleEscape() },
                        typography: model.typography,
                        typographyGeneration: model.typographyGeneration,
                        lineIndexProvider: { model.lineIndex(for: $0, revision: $1) },
                        completionProvider: { model.wordCompletionSuffix(forPrefix: $0) }
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
            if !model.isDistractionFree, model.isShortcutsPanelVisible {
                ShortcutsSidePanelView(model: model)
                    .frame(minWidth: 260, idealWidth: 320, maxWidth: 480)
            }
        }
    }

    /// Compare header: source tab on the left; on the right a "Compare with" picker (saved version or another open tab)
    /// and an X that drops the destination only, returning to saved vs current (`REQ-022-01`).
    private var compareHeader: some View {
        let palette = model.palette
        let sourceTitle = model.title(ofTab: model.compareSourceTabID) ?? "—"
        let destinationTitle = model.title(ofTab: model.compareDestinationTabID)
        return HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("SOURCE")
                    .appFont(.caption2, weight: .semibold)
                    .tracking(0.6)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                Text(verbatim: destinationTitle == nil ? "\(sourceTitle) · saved" : sourceTitle)
                    .appFont(.caption, weight: .medium)
                    .foregroundStyle(palette.chromeForeground.swiftUIColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Menu {
                    Button { model.setCompareDestination(nil) } label: {
                        Text(model.compareDestinationTabID == nil ? "✓ Saved version (current tab)" : "Saved version (current tab)")
                    }
                    let candidates = model.compareDestinationCandidates
                    if !candidates.isEmpty { Divider() }
                    ForEach(candidates, id: \.id) { tab in
                        Button { model.setCompareDestination(tab.id) } label: {
                            Text(model.compareDestinationTabID == tab.id ? "✓ \(tab.title)" : tab.title)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Compare with:")
                            .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                        Text(verbatim: destinationTitle ?? "current (unsaved)")
                            .foregroundStyle(palette.chromeForeground.swiftUIColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        AppIconView(.chevronDown, size: 10)
                            .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    }
                    .appFont(.caption, weight: .medium)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Choose another open tab to compare with the source")
                .accessibilityLabel("Compare with \(destinationTitle ?? "saved version")")
                Spacer(minLength: 0)
                if model.compareDestinationTabID != nil {
                    Button { model.setCompareDestination(nil) } label: {
                        AppIconView(.close, size: 11).minimumHitTarget(20)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    .help("Stop comparing with \(destinationTitle ?? "") (the tab stays open)")
                    .accessibilityLabel("Remove compare destination")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(palette.tabBarSurface.swiftUIColor)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.hairlineBorder.swiftUIColor).frame(height: 1) }
    }

    private var diffPanel: some View {
        VStack(spacing: 0) {
        compareHeader
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                let rows = model.diffCoordinator.rows
                ForEach(rows.indices, id: \.self) { index in
                    let row = rows[index]
                    HStack(spacing: 8) {
                        Text(row.lhsText ?? "")
                            .appFont(.caption, monospaced: true)
                            .foregroundStyle((row.lhsKind == .removed ? model.palette.editorCanvasText : model.palette.chromeForeground).swiftUIColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .background(row.lhsKind == .removed ? model.palette.diffRemovedBackground.swiftUIColor : Color.clear)
                        Text(row.rhsText ?? "")
                            .appFont(.caption, monospaced: true)
                            .foregroundStyle((row.rhsKind == .inserted ? model.palette.editorCanvasText : model.palette.chromeForeground).swiftUIColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .background(row.rhsKind == .inserted ? model.palette.diffInsertedBackground.swiftUIColor : Color.clear)
                    }
                }
            }
            .padding(12)
        }
        }
        .background(model.palette.chromeSurface.swiftUIColor)
    }

    /// Neutral 24 pt status bar: sidebar toggle, lint icon + count, bracket warning only when unbalanced; right side
    /// cursor metrics, encoding, line ending, language, zoom menu and theme toggle (R-01, R-02, V-01).
    private var statusBar: some View {
        let metrics = model.activeStatusBarMetrics
        let lintCount = model.lintDiagnostics.count
        let hasErrors = model.lintDiagnostics.contains { $0.severity == .error }
        let unbalanced = model.bracketResult?.unbalancedBrackets.count ?? 0
        let lintForeground: Color = lintCount == 0
            ? model.palette.statusBarForeground.swiftUIColor
            : (hasErrors ? model.palette.unbalancedBracketHighlight : model.palette.bidiWarningForeground).swiftUIColor
        return HStack(spacing: 14) {
            Button(action: { model.toggleLeftSidebar() }) {
                AppIconView(.sidebar, size: 13).minimumHitTarget(20)
            }
            .buttonStyle(.plain)
            .help("Toggle Folder Navigator (⌘B)")
            .accessibilityLabel(model.isLeftSidebarCollapsed ? "Show folder navigator" : "Hide folder navigator")

            Button(action: { model.toggleDiagnosticsPopover() }) {
                HStack(spacing: 4) {
                    switch model.activeLintStatus {
                    case .active(let count):
                        AppIconView(count == 0 ? .checkCircle : (hasErrors ? .error : .warning), size: 13)
                        Text("\(count)")
                    case .off, .paused:
                        Text(model.activeLintStatus.label)
                    }
                }
                .foregroundStyle(lintForeground)
            }
            .buttonStyle(.plain)
            .help("Markdown diagnostics (⇧⌘M)")
            .accessibilityLabel(model.activeLintStatus.label)
            .accessibilityHint("Opens the Markdown diagnostics popover")
            .popover(isPresented: Binding(get: { model.isDiagnosticsPopoverPresented }, set: { model.isDiagnosticsPopoverPresented = $0 })) {
                MarkdownDiagnosticsPopoverView(model: model)
            }
            if unbalanced > 0 {
                HStack(spacing: 4) {
                    AppIconView(.braces, size: 13)
                    Text("\(unbalanced) unbalanced")
                }
                .foregroundStyle(model.palette.unbalancedBracketHighlight.swiftUIColor)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Brackets: \(unbalanced) unbalanced")
            }
            Spacer()
            Text("Ln \(metrics.line), Col \(metrics.column)")
            Text("\(metrics.characterCount) chars")
            Text(metrics.encodingLabel)
            Menu {
                Button("LF (Unix / macOS)") { model.setActiveDocumentLineEnding(.lf) }
                Button("CRLF (Windows)") { model.setActiveDocumentLineEnding(.crlf) }
                Button("CR (Classic Mac)") { model.setActiveDocumentLineEnding(.cr) }
            } label: {
                Text(StatusBarMetricsProjection.displayLabel(for: metrics.lineEnding)).appFont(.caption)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            Text(model.activeDocumentLanguage.statusBarLabel)
                .accessibilityLabel("Language: \(model.activeDocumentLanguage.statusBarLabel)")
            Menu {
                Button("Zoom In (⌘+)") { model.zoomController.zoomIn() }
                Button("Zoom Out (⌘-)") { model.zoomController.zoomOut() }
                Button("Actual Size (⌘0)") { model.zoomController.resetZoom() }
            } label: {
                Text("\(model.zoomController.zoomPercent)%").appFont(.caption).monospacedDigit()
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Zoom \(model.zoomController.zoomPercent) percent")
            Button(action: { model.cycleAppearanceMode() }) {
                AppIconView(appearanceIcon, size: 13).minimumHitTarget(20)
            }
            .buttonStyle(.plain)
            .help("Appearance: \(appearanceTitle) (click to switch Light → Dark → Auto)")
            .accessibilityLabel("Appearance \(appearanceTitle)")
            .accessibilityHint("Switches between Light, Dark and Auto")
        }
        .appFont(.caption)
        .foregroundStyle(model.palette.statusBarForeground.swiftUIColor)
        .tint(model.palette.statusBarForeground.swiftUIColor)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(model.palette.statusBarSurface.swiftUIColor)
        .overlay(alignment: .top) {
            Rectangle().fill(model.palette.hairlineBorder.swiftUIColor).frame(height: 1)
        }
    }

    private var appearanceIcon: AppIcon {
        switch model.appearanceMode {
        case .light: return .sun
        case .black: return .moon
        case .auto: return .monitor
        }
    }

    private var appearanceTitle: String {
        switch model.appearanceMode {
        case .light: return "Light"
        case .black: return "Dark"
        case .auto: return "Auto"
        }
    }
}

private struct HostingWindowFinder: NSViewRepresentable {
    let onResolveWindow: (NSWindow?) -> Void

    final class ProbeNSView: NSView {
        var onResolveWindow: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onResolveWindow?(window)
        }
    }

    func makeNSView(context: Context) -> ProbeNSView {
        let view = ProbeNSView()
        view.onResolveWindow = onResolveWindow
        return view
    }

    func updateNSView(_ nsView: ProbeNSView, context: Context) {
        nsView.onResolveWindow = onResolveWindow
        if let win = nsView.window {
            onResolveWindow(win)
        }
    }
}
#endif
