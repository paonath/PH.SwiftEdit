import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

extension SwiftEditWorkbenchModel {
    public internal(set) var systemPrefersDark: Bool {
        get { appearanceState.systemPrefersDark }
        set { appearanceState.systemPrefersDark = newValue }
    }
    public internal(set) var reduceTransparency: Bool {
        get { appearanceState.reduceTransparency }
        set { appearanceState.reduceTransparency = newValue }
    }
    public internal(set) var increasedContrast: Bool {
        get { appearanceState.increasedContrast }
        set { appearanceState.increasedContrast = newValue }
    }
    public internal(set) var lastWindowAppearanceTarget: MacOSWindowAppearanceTarget {
        get { appearanceState.lastWindowAppearanceTarget }
        set { appearanceState.lastWindowAppearanceTarget = newValue }
    }
    public var appearanceMode: AppearanceMode {
        get { appearanceState.appearanceMode }
        set {
            appearanceState.appearanceMode = newValue
            if newValue == .auto {
                appearanceState.systemPrefersDark = deps.systemDarkDetector()
            }
            appearanceState.lastWindowAppearanceTarget = MacOSAppearanceSynchronizer.synchronizeApplicationAppearance(for: newValue)
            appearanceState.palette = PurpleThemePalette.resolve(
                appearance: newValue,
                systemPrefersDark: appearanceState.systemPrefersDark,
                reduceTransparency: appearanceState.reduceTransparency,
                increasedContrast: appearanceState.increasedContrast,
                syntaxColorScheme: appearanceState.syntaxColorScheme
            )
            savePreferences()
        }
    }
    public var syntaxColorScheme: SyntaxColorScheme {
        get { appearanceState.syntaxColorScheme }
        set {
            guard appearanceState.syntaxColorScheme != newValue else { return }
            appearanceState.syntaxColorScheme = newValue
            appearanceState.palette = PurpleThemePalette.resolve(
                appearance: appearanceState.appearanceMode,
                systemPrefersDark: appearanceState.systemPrefersDark,
                reduceTransparency: appearanceState.reduceTransparency,
                increasedContrast: appearanceState.increasedContrast,
                syntaxColorScheme: newValue
            )
            savePreferences()
        }
    }
    public internal(set) var palette: PurpleThemePalette {
        get { appearanceState.palette }
        set { appearanceState.palette = newValue }
    }
    public internal(set) var interfaceFont: FontChoice {
        get { appearanceState.interfaceFont }
        set { appearanceState.interfaceFont = newValue }
    }
    public internal(set) var editorFont: FontChoice {
        get { appearanceState.editorFont }
        set { appearanceState.editorFont = newValue }
    }
    public internal(set) var preferredTerminalBundleID: String? {
        get { appearanceState.preferredTerminalBundleID }
        set { appearanceState.preferredTerminalBundleID = newValue }
    }
    public internal(set) var typographyGeneration: Int {
        get { appearanceState.typographyGeneration }
        set { appearanceState.typographyGeneration = newValue }
    }
    public var isWordWrapEnabled: Bool {
        get { appearanceState.isWordWrapEnabled }
        set { appearanceState.isWordWrapEnabled = newValue }
    }
    public var launchInFullScreen: Bool {
        get { appearanceState.launchInFullScreen }
        set { appearanceState.launchInFullScreen = newValue }
    }
    public var trimTrailingWhitespaceOnSave: Bool {
        get { appearanceState.trimTrailingWhitespaceOnSave }
        set {
            appearanceState.trimTrailingWhitespaceOnSave = newValue
            savePreferences()
        }
    }
    public var zoomController: EditorZoomController {
        get { appearanceState.zoomController }
        set {
            appearanceState.zoomController = newValue
            savePreferences()
        }
    }
    public var isToolbarHovered: Bool {
        get { overlayState.isToolbarHovered }
        set { overlayState.isToolbarHovered = newValue }
    }
    var hostWindow: NSWindow? {
        get { runtimeHooks.hostWindow }
        set { runtimeHooks.hostWindow = newValue }
    }
    public var windowFullScreenQuery: () -> Bool {
        get { runtimeHooks.windowFullScreenQuery }
        set { runtimeHooks.windowFullScreenQuery = newValue }
    }
    public var windowFullScreenToggle: () -> Void {
        get { runtimeHooks.windowFullScreenToggle }
        set { runtimeHooks.windowFullScreenToggle = newValue }
    }

    /// `true` while the left sidebar is open and pinned; unpinning collapses the sidebar cleanly (`UI-001`).
    public var isLeftSidebarPinned: Bool { !isLeftSidebarCollapsed }

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
            let idx = caches.textIndexCache.index(for: session.snapshot)
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
}

extension SwiftEditWorkbenchModel {
    func cachedWordOccurrencesForActiveSelection() -> [SwiftEditCore.TextRange] {
        guard currentSelection.length >= WordOccurrenceScanner.minWordUTF16Length,
              let session = activeDocumentSession else {
            return []
        }
        if let cache = caches.wordOccurrenceCache,
           cache.id == session.id,
           cache.revision == session.revision,
           cache.selection == currentSelection {
            return cache.ranges
        }
        let ranges = WordOccurrenceScanner.scan(selection: currentSelection, in: session.snapshot)
        caches.wordOccurrenceCache = (session.id, session.revision, currentSelection, ranges)
        return ranges
    }

    /// Synchronizes live macOS system dark/light appearance and refreshes `palette` dynamically when in `.auto` mode without reloading buffers (`UI-003`).
    public func updateSystemColorScheme(prefersDark: Bool) {
        guard appearanceMode == .auto else { return }
        systemPrefersDark = prefersDark
        palette = PurpleThemePalette.resolve(
            appearance: appearanceMode,
            systemPrefersDark: systemPrefersDark,
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast,
            syntaxColorScheme: syntaxColorScheme
        )
    }

    /// Re-reads the unmasked macOS interface style via `deps.systemDarkDetector` and updates `palette` when in `.auto` mode (`UI-003`).
    public func refreshUnmaskedSystemAppearance() {
        systemPrefersDark = deps.systemDarkDetector()
        if appearanceMode == .auto {
            palette = PurpleThemePalette.resolve(
                appearance: appearanceMode,
                systemPrefersDark: systemPrefersDark,
                reduceTransparency: reduceTransparency,
                increasedContrast: increasedContrast,
                syntaxColorScheme: syntaxColorScheme
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
            increasedContrast: increasedContrast,
            syntaxColorScheme: syntaxColorScheme
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
}

extension SwiftEditWorkbenchModel {
    /// Zoom-driven tab, deps.navigator and gutter sizes (`REQ-009`).
    public var chromeMetrics: ZoomedChromeMetrics { ZoomedChromeMetrics(zoomPercent: zoomController.zoomPercent) }

    /// Gutter width for the active document: digit advance of the editor font at 100% times the zoom factor (`REQ-009`).
    public var gutterWidth: CGFloat {
        let digitAdvance = ("0" as NSString).size(withAttributes: [.font: typography.nsFont(.editor, size: CGFloat(zoomController.baseFontSizePoints))]).width
        return chromeMetrics.gutterWidth(lineCount: activeLineNumberGutter.lineCount, digitAdvanceAt100: digitAdvance)
    }
    /// Per-role font choices (`REQ-003`, `REQ-007`); views read fonts through `typography`, observing `typographyGeneration`.

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
    /// Whether SwiftEdit opens in macOS Full Screen on launch by default. Persisted in `~/.SwiftEdit/settings.json`.

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
        guard !caches.didApplyInitialFullScreen else { return }
        caches.didApplyInitialFullScreen = true
        guard launchInFullScreen,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !window.styleMask.contains(.fullScreen) else { return }
        DispatchQueue.main.async { [weak window] in
            guard let window, !window.styleMask.contains(.fullScreen) else { return }
            window.toggleFullScreen(nil)
        }
    }

    /// Cached language of the active tab (`PERF-C1`): binary inspections and the empty workspace are `.plainText`; degraded buffers keep their tab language so lint reports `Paused` rather than `Off`.
    public var activeDocumentLanguage: DocumentLanguage {
        if workspaceState.activeBinaryInspection != nil { return .plainText }
        guard let activeID = tabSession.activeTabID,
              let tab = tabSession.tabs.first(where: { $0.id == activeID }) else {
            return .plainText
        }
        return tab.language
    }

    public var activeTabTitle: String {
        if let bin = workspaceState.activeBinaryInspection {
            return bin.title
        }
        guard let activeID = tabSession.activeTabID,
              let tab = tabSession.tabs.first(where: { $0.id == activeID }) else {
            return "Untitled"
        }
        return tab.title
    }

    /// Persists appearance, zoom, font choices, word wrap, full-screen default, terminal height, and preferred terminal together so no setting overwrites another.
    func savePreferences() {
        deps.preferencesStore.save(EditorPreferences(
            appearanceMode: appearanceMode,
            syntaxColorScheme: syntaxColorScheme,
            zoomPercent: zoomController.zoomPercent,
            interfaceFont: interfaceFont,
            editorFont: editorFont,
            preferredTerminalBundleID: preferredTerminalBundleID,
            isWordWrapEnabled: isWordWrapEnabled,
            launchInFullScreen: launchInFullScreen,
            terminalPanelHeight: Int(terminalPanelHeight.rounded()),
            trimTrailingWhitespaceOnSave: trimTrailingWhitespaceOnSave
        ))
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
        if let cached = caches.cachedGutterProjection,
           cached.id == session.id,
           cached.revision == session.revision,
           cached.caret == caret,
           cached.fontSize == fontSize {
            return cached.value
        }
        let value = LineNumberGutterProjection.evaluate(
            index: caches.textIndexCache.index(for: session.snapshot),
            caretLocation: caret,
            fontSizePoints: fontSize
        )
        caches.cachedGutterProjection = (session.id, session.revision, caret, fontSize, value)
        return value
    }

    public var activeStatusBarMetrics: StatusBarMetricsProjection {
        let caret = currentSelection.location
        guard let session = activeDocumentSession else {
            return StatusBarMetricsProjection.evaluate(snapshot: DocumentSession(text: "").snapshot, caretLocation: caret)
        }
        if let cached = caches.cachedStatusBarMetrics,
           cached.id == session.id,
           cached.revision == session.revision,
           cached.caret == caret {
            return cached.value
        }
        let snapshot = session.snapshot
        let value = StatusBarMetricsProjection.evaluate(
            snapshot: snapshot,
            index: caches.textIndexCache.index(for: snapshot),
            caretLocation: caret
        )
        caches.cachedStatusBarMetrics = (session.id, session.revision, caret, value)
        return value
    }

    /// Returns `true` when `selectedFolderURL` is not `"/"` and the parent folder (`...`) is within `grantedScopeRootURL` or readable under active user permissions (`UI-001`, `BC-007`).
    public var canNavigateToParentFolder: Bool {
        guard let currentFolder = selectedFolderURL else { return false }
        if let cached = caches.cachedParentNavigation,
           cached.folder == currentFolder,
           cached.scope == grantedScopeRootURL {
            return cached.canNavigate
        }
        let resolved = try? deps.navigator.resolveParentDirectory(
            from: currentFolder,
            withinScope: grantedScopeRootURL,
            isParentReadable: deps.parentPermissionChecker
        )
        let result = resolved != nil
        caches.cachedParentNavigation = (currentFolder, grantedScopeRootURL, result)
        return result
    }

}

#endif
