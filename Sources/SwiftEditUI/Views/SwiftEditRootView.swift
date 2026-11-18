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
    public private(set) var folderEntries: [FolderEntryDescriptor] = []
    public private(set) var currentSelection = SwiftEditCore.TextRange(location: 0, length: 0)
    public private(set) var lintDiagnostics: [MarkdownLintDiagnostic] = []
    public private(set) var bracketResult: BracketBalanceResult?
    public private(set) var safetyBanner: InspectionSafetyBannerState
    public private(set) var statusBannerMessage: String?
    public var showMarkdownPreview: Bool = false
    public var showDiffPane: Bool = false

    public let diffCoordinator = DiffPaneCoordinator()
    private let loader = DocumentLoader(fileSystem: LocalFileSystemAdapter())
    private let navigator = DotfileFolderNavigator()
    private let preferencesStore = EditorPreferencesStore(suiteName: "it.ph.SwiftEdit.preferences")
    private let recoveryStore: SessionRecoveryStore

    public init() {
        let prefs = preferencesStore.load()
        self.appearanceMode = prefs.appearanceMode
        self.palette = PurpleThemePalette.resolve(appearance: prefs.appearanceMode, systemPrefersDark: true)
        self.zoomController = EditorZoomController(zoomPercent: prefs.zoomPercent)

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let recoveryURL = appSupport
            .appendingPathComponent("PH.SwiftEdit", isDirectory: true)
            .appendingPathComponent("SessionRecovery", isDirectory: true)
        self.recoveryStore = SessionRecoveryStore(recoveryDirectoryURL: recoveryURL)

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
        refreshDiagnosticsForActiveDocument()
    }

    public var activeDocumentSession: DocumentSession? {
        guard let activeID = tabSession.activeTabID else { return nil }
        return sessionsByID[activeID]
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
        selectedFolderURL = folderURL
        refreshFolderEntries()
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
        do {
            folderEntries = try navigator.listEntries(in: folderURL, withinScope: folderURL)
            statusBannerMessage = nil
        } catch {
            statusBannerMessage = "Folder access error: \(error)"
        }
    }

    public func openFolderEntry(_ entry: FolderEntryDescriptor) {
        if entry.isDirectory {
            selectedFolderURL = entry.url
            refreshFolderEntries()
            return
        }
        openFile(at: entry.url, withinScope: selectedFolderURL)
    }

    public func openFile(at url: URL, withinScope scope: URL?) {
        do {
            let loaded = try loader.load(from: url, withinScope: scope)
            sessionsByID[loaded.id] = loaded
            savedBaselineByID[loaded.id] = loaded.snapshot
            if loaded.isBinaryReadOnly {
                statusBannerMessage = "Binary file opened in transient read-only inspection mode (Save, Format, Pin & SessionRecovery disabled)."
                safetyBanner = InspectionSafetyBannerState.evaluate(snapshot: loaded.snapshot)
                return
            }
            try tabSession.openOrActivate(
                snapshot: loaded.snapshot,
                title: url.lastPathComponent,
                fileURL: url,
                isDirty: false
            )
            statusBannerMessage = nil
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Open failed: \(error)"
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

        do {
            let saved = try loader.save(session, to: targetURL, withinScope: selectedFolderURL ?? targetURL.deletingLastPathComponent())
            sessionsByID[activeID] = saved
            savedBaselineByID[activeID] = saved.snapshot
            try? tabSession.updateTabState(id: activeID, title: targetURL.lastPathComponent, fileURL: .some(targetURL), isDirty: false, revision: saved.revision)
            try? recoveryStore.removeRecoverySnapshot(for: activeID)
            statusBannerMessage = "Saved \(targetURL.lastPathComponent)."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
            refreshFolderEntries()
        } catch {
            statusBannerMessage = "Save failed: \(error)"
        }
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

    public func toggleDiffPane() {
        showDiffPane.toggle()
        refreshDiagnosticsForActiveDocument()
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
            tabBar
            safetyAndErrorBanners
            HSplitView {
                sidebarView
                    .frame(minWidth: 190, idealWidth: 230, maxWidth: 320)
                editorAndOptionalPanels
            }
            statusBar
        }
        .background(model.palette.chromeSurface.swiftUIColor)
        .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
        .frame(minWidth: 960, minHeight: 620)
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
                        Button(action: { model.closeTab(id: tab.id) }) {
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
            Text(model.selectedFolderURL?.lastPathComponent ?? "No Folder Open")
                .font(.caption.weight(.semibold))
                .foregroundStyle(model.palette.strokeLavender.swiftUIColor)
                .padding(.horizontal, 10)
                .padding(.top, 8)
            List(model.folderEntries, id: \.url) { entry in
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
            }
            .scrollContentBackground(.hidden)
        }
        .background(model.palette.brandGround.swiftUIColor.opacity(0.92))
    }

    private var editorAndOptionalPanels: some View {
        HSplitView {
            if let session = model.activeDocumentSession {
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
        HStack(spacing: 14) {
            Text("Lint: \(model.lintDiagnostics.count)")
            Text("Brackets: \(model.bracketResult?.unbalancedBrackets.isEmpty == true ? "Balanced" : "Unbalanced (\(model.bracketResult?.unbalancedBrackets.count ?? 0))")")
            Text("Mode: \(model.palette.mode.rawValue.capitalized)")
            Spacer()
            Text("Zoom: \(model.zoomController.zoomPercent)%")
            Text("Sandbox: App Sandbox")
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(model.palette.brandGround.swiftUIColor)
    }
}
#endif
