import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Editor/preview/terminal panel layout, two-tab compare header, diff panel, and status bar for `SwiftEditRootView` (`UI-001`, `UI-006`).
extension SwiftEditRootView {
    var editorAndOptionalPanels: some View {
        HSplitView {
            if let tail = model.activeLogTail {
                // Read-only live tail view: its own document identity, follows the newest line (bottom in direct, top in inverse).
                TextKit2EditorView(
                    documentID: tail.viewID,
                    bufferRevision: BufferRevision(tail.generation),
                    text: tail.text,
                    isEditable: false,
                    isWordOccurrenceHighlightEnabled: true,
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
                    editorFocusRequestToken: model.editorFocusRequestToken,
                    onEscape: { model.handleEscape() },
                    onSendSelectionToTerminal: { range, text in
                        model.requestSendSelectionToTerminal(selection: range, sourceText: text)
                    },
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
                        isWordOccurrenceHighlightEnabled: !session.isBinaryReadOnly && !session.isDegradedPlainText,
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
                        onSendSelectionToTerminal: { range, text in
                            model.requestSendSelectionToTerminal(selection: range, sourceText: text)
                        },
                        onRevealInFolderNavigator: model.canRevealActiveDocumentInFolderNavigator ? {
                            _ = model.revealActiveDocumentInFolderNavigator()
                        } : nil,
                        onStartDictationHere: model.canStartDictationHere ? {
                            _ = model.startDictationHere()
                        } : nil,
                        typography: model.typography,
                        typographyGeneration: model.typographyGeneration,
                        lineIndexProvider: { model.lineIndex(for: $0, revision: $1) },
                        completionProvider: { model.wordCompletionSuffix(forPrefix: $0) }
                    )
                }
            } else {
                emptyWorkspaceCanvas
            }
            if !model.isDistractionFree, model.showMarkdownPreview, model.isMarkdownMenuEnabled {
                MarkdownNativePreviewView(
                    document: model.markdownPreviewDocument,
                    enrichedDocument: model.enrichedMarkdownPreviewDocument,
                    palette: model.palette,
                    gate: model.previewResourceGate,
                    activeSourceLine: model.previewSourceLine,
                    zoomPercent: model.zoomController.zoomPercent,
                    onCopyCode: { model.copyPreviewCodeBlock($0) }
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

    /// Minimal empty-workspace canvas shown when no tab is open (first launch without pinned or recovered documents).
    var emptyWorkspaceCanvas: some View {
        VStack(spacing: 16) {
            SwiftEditBrandLogoView(size: 56)
                .opacity(0.85)
            Text("SwiftEdit")
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
            HStack(spacing: 10) {
                Button { model.newUntitledTab() } label: {
                    HStack(spacing: 6) {
                        AppIconView(.filePlus, size: 13)
                        Text("New Document")
                        Text(verbatim: "⌘N")
                            .appFont(.caption, monospaced: true)
                            .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(model.palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                Button { model.openFileViaPanel() } label: {
                    HStack(spacing: 6) {
                        AppIconView(.fileText, size: 13)
                        Text("Open File…")
                        Text(verbatim: "⌘O")
                            .appFont(.caption, monospaced: true)
                            .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(model.palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                Button { model.openFolderViaPanel() } label: {
                    HStack(spacing: 6) {
                        AppIconView(.folder, size: 13)
                        Text("Open Folder…")
                        Text(verbatim: "⇧⌘O")
                            .appFont(.caption, monospaced: true)
                            .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(model.palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .appFont(.callout, weight: .medium)
            .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(model.palette.editorCanvasBackground.swiftUIColor)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Empty workspace")
    }
}

/// Side-by-side compare header, zoomed diff panel, and neutral status bar for `SwiftEditRootView` (`REQ-005`, `UI-001`).
extension SwiftEditRootView {
    /// Compare header: source tab on the left; hunk navigation (`⇧F7`/`F7`) + `Only Diff` filter in the center; "Compare with" picker on the right (`REQ-005`, `REQ-022-01`).
    var compareHeader: some View {
        let palette = model.palette
        let zoomMetrics = ZoomedChromeMetrics(zoomPercent: model.zoomController.zoomPercent)
        let sourceTitle = model.title(ofTab: model.compareSourceTabID) ?? "—"
        let destinationTitle = model.title(ofTab: model.compareDestinationTabID)
        let hunkTotal = model.diffCoordinator.hunkRowIndices.count
        let hunkCurrent = hunkTotal == 0 ? 0 : (model.diffCoordinator.activeHunkIndex + 1)
        return HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("SOURCE")
                    .appFont(size: zoomMetrics.diffHeaderBadgeFontSize, weight: .semibold)
                    .tracking(0.6)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                Text(verbatim: destinationTitle == nil ? "\(sourceTitle) · saved" : sourceTitle)
                    .appFont(size: zoomMetrics.diffHeaderFontSize, weight: .medium)
                    .foregroundStyle(palette.chromeForeground.swiftUIColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            diffHeaderHunkControls(zoomMetrics: zoomMetrics, hunkCurrent: hunkCurrent, hunkTotal: hunkTotal)
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
                        AppIconView(.chevronDown, size: max(10, 10 * zoomMetrics.factor))
                            .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    }
                    .appFont(size: zoomMetrics.diffHeaderFontSize, weight: .medium)
                    .frame(minHeight: zoomMetrics.diffActionTarget)
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
                        AppIconView(.close, size: max(11, 11 * zoomMetrics.factor))
                            .frame(minWidth: zoomMetrics.diffActionTarget, minHeight: zoomMetrics.diffActionTarget)
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

    private func diffHeaderHunkControls(zoomMetrics: ZoomedChromeMetrics, hunkCurrent: Int, hunkTotal: Int) -> some View {
        let palette = model.palette
        return HStack(spacing: 4) {
            Button { model.selectPreviousDiffHunk() } label: {
                AppIconView(.chevronUp, size: max(12, 12 * zoomMetrics.factor))
                    .frame(minWidth: zoomMetrics.diffActionTarget, minHeight: zoomMetrics.diffActionTarget)
            }
            .buttonStyle(.plain)
            .disabled(hunkTotal == 0)
            .help("Previous Change (⇧F7)")
            .accessibilityLabel("Previous difference hunk")

            Text(verbatim: "\(hunkCurrent)/\(hunkTotal)")
                .appFont(size: zoomMetrics.diffHeaderBadgeFontSize, monospaced: true)
                .foregroundStyle(palette.secondaryForeground.swiftUIColor)

            Button { model.selectNextDiffHunk() } label: {
                AppIconView(.chevronDown, size: max(12, 12 * zoomMetrics.factor))
                    .frame(minWidth: zoomMetrics.diffActionTarget, minHeight: zoomMetrics.diffActionTarget)
            }
            .buttonStyle(.plain)
            .disabled(hunkTotal == 0)
            .help("Next Change (F7)")
            .accessibilityLabel("Next difference hunk")

            Button { model.toggleDiffOnlyDifferences() } label: {
                Text("Only Diff")
                    .appFont(size: zoomMetrics.diffHeaderBadgeFontSize, weight: .medium)
                    .padding(.horizontal, 6)
                    .frame(minWidth: zoomMetrics.diffActionTarget, minHeight: zoomMetrics.diffActionTarget)
                    .background(
                        (model.diffCoordinator.onlyDifferences ? palette.activeBracketHighlight : palette.badgeSurface).swiftUIColor,
                        in: RoundedRectangle(cornerRadius: 4)
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.chromeForeground.swiftUIColor)
            .help("Show only modified hunks with ±2 context lines")
            .accessibilityLabel(model.diffCoordinator.onlyDifferences ? "Show full file comparison" : "Show only differences")
        }
    }

    var diffPanel: some View {
        let zoomMetrics = ZoomedChromeMetrics(zoomPercent: model.zoomController.zoomPercent)
        return VStack(spacing: 0) {
            compareHeader
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2 * zoomMetrics.factor) {
                        let rows = model.diffCoordinator.displayedRows
                        ForEach(rows.indices, id: \.self) { index in
                            diffSideBySideRowView(row: rows[index], zoomMetrics: zoomMetrics)
                                .id(index)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: model.diffCoordinator.activeHunkIndex) { _, _ in
                    if let target = model.diffCoordinator.activeScrollRowIndex {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
        .background(model.palette.chromeSurface.swiftUIColor)
    }

    private func diffSideBySideRowView(row: SideBySideDiffRow, zoomMetrics: ZoomedChromeMetrics) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(verbatim: row.lhsLineNumber.map(String.init) ?? "")
                    .appFont(size: zoomMetrics.diffFontSize, monospaced: true, role: .editor)
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    .frame(width: zoomMetrics.diffLineNumberWidth, alignment: .trailing)
                Text(row.lhsText ?? "")
                    .appFont(size: zoomMetrics.diffFontSize, monospaced: true, role: .editor)
                    .foregroundStyle((row.lhsKind == .removed ? model.palette.editorCanvasText : model.palette.chromeForeground).swiftUIColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .background(row.lhsKind == .removed ? model.palette.diffRemovedBackground.swiftUIColor : Color.clear)
            }
            HStack(spacing: 4) {
                Text(verbatim: row.rhsLineNumber.map(String.init) ?? "")
                    .appFont(size: zoomMetrics.diffFontSize, monospaced: true, role: .editor)
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    .frame(width: zoomMetrics.diffLineNumberWidth, alignment: .trailing)
                Text(row.rhsText ?? "")
                    .appFont(size: zoomMetrics.diffFontSize, monospaced: true, role: .editor)
                    .foregroundStyle((row.rhsKind == .inserted ? model.palette.editorCanvasText : model.palette.chromeForeground).swiftUIColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .background(row.rhsKind == .inserted ? model.palette.diffInsertedBackground.swiftUIColor : Color.clear)
            }
        }
    }

    /// Neutral 24 pt status bar: sidebar toggle, Git branch badge, lint icon + count, bracket warning; right side
    /// cursor/selection/word metrics, interactive encoding menu, line ending menu, language, zoom menu, and theme toggle (`REQ-012`).
    var statusBar: some View {
        let metrics = model.activeStatusBarMetrics
        let enriched = model.activeEnrichedStatusBarMetrics
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

            if let branch = model.activeGitBranchName {
                HStack(spacing: 4) {
                    AppIconView(.code, size: 12)
                    Text(verbatim: branch)
                        .lineLimit(1)
                        .frame(maxWidth: 140)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Git branch \(branch)")
            }

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
            if enriched.selectedCharacterCount > 0 {
                Text("Sel \(enriched.selectedCharacterCount) (\(enriched.selectedLineCount) ln)")
            } else {
                Text("\(metrics.characterCount) chars")
            }
            if let words = enriched.markdownWordCount {
                Text("\(words) words")
            }
            statusBarEncodingMenu(currentLabel: metrics.encodingLabel)
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

    var appearanceIcon: AppIcon {
        switch model.appearanceMode {
        case .light: return .sun
        case .black: return .moon
        case .auto: return .monitor
        }
    }

    var appearanceTitle: String {
        switch model.appearanceMode {
        case .light: return "Light"
        case .black: return "Dark"
        case .auto: return "Auto"
        }
    }

    private func statusBarEncodingMenu(currentLabel: String) -> some View {
        Menu {
            Section("Save with Encoding") {
                Button("UTF-8") { model.setActiveDocumentEncoding(.utf8) }
                Button("UTF-8 with BOM") { model.setActiveDocumentEncoding(.utf8WithBOM) }
                Button("UTF-16 LE") { model.setActiveDocumentEncoding(.utf16LEWithBOM) }
                Button("UTF-16 BE") { model.setActiveDocumentEncoding(.utf16BEWithBOM) }
            }
            if model.activeDocumentSession?.fileURL != nil {
                Divider()
                Section("Reopen with Encoding") {
                    Button("Reopen as UTF-8") { _ = model.reopenActiveDocumentWithEncoding(.utf8) }
                    Button("Reopen as UTF-16 LE") { _ = model.reopenActiveDocumentWithEncoding(.utf16LEWithBOM) }
                    Button("Reopen as UTF-16 BE") { _ = model.reopenActiveDocumentWithEncoding(.utf16BEWithBOM) }
                }
            }
        } label: {
            Text(currentLabel).appFont(.caption)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Encoding \(currentLabel)")
    }

}

#endif
