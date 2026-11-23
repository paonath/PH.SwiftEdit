import Foundation
import SwiftEditCore
import SwiftUI

/// Presentation mode of the inline Find / Find & Replace / Go-to-Line bar (`Cmd+F`, `Cmd+H`, `Cmd+G`) (`UI-009`).
public enum FindBarPresentationMode: String, Equatable, Sendable {
    case hidden
    case find
    case findAndReplace
    case goToLine
}

/// User resolution choice for closing a dirty tab (`Cmd+W`) or quitting with unsaved changes (`Cmd+Q`) (`BC-008`, `DATA-006`).
public enum DirtyCloseDecision: Equatable, Sendable {
    case save
    case dontSave
    case cancel
}

/// Value-type state backing `FindReplaceGoToLineBar` and `SwiftEditWorkbenchModel` search/navigation operations (`BC-004`, `BC-011`).
public struct FindReplaceBarState: Equatable, Sendable {
    public var mode: FindBarPresentationMode = .hidden
    public var query: String = ""
    public var replacement: String = ""
    public var isCaseSensitive: Bool = false
    public var goToLineText: String = ""
    public var matches: [SwiftEditCore.TextRange] = []
    public var activeMatchIndex: Int = 0

    public init() {}

    /// Advances `activeMatchIndex` forward modulo `matches.count` and returns the selected `TextRange` (`nil` when `matches` is empty).
    public mutating func selectNextMatch() -> SwiftEditCore.TextRange? {
        guard !matches.isEmpty else { return nil }
        activeMatchIndex = (activeMatchIndex + 1) % matches.count
        return matches[activeMatchIndex]
    }

    /// Moves `activeMatchIndex` backward modulo `matches.count` and returns the selected `TextRange` (`nil` when `matches` is empty).
    public mutating func selectPreviousMatch() -> SwiftEditCore.TextRange? {
        guard !matches.isEmpty else { return nil }
        activeMatchIndex = (activeMatchIndex - 1 + matches.count) % matches.count
        return matches[activeMatchIndex]
    }
}

#if os(macOS)
/// Inline Purple-themed bar supporting Find (`Cmd+F`), Find & Replace (`Opt+Cmd+F`), and Go to Line (`Cmd+G`) with `@FocusState` auto-focus and single Replace (`BUG-008`, `BUG-009`, `UI-001`, `UI-009`).
public struct FindReplaceGoToLineBar: View {
    private enum FocusTarget: Hashable {
        case query
        case replacement
        case goToLine
    }

    @Binding public var state: FindReplaceBarState
    public let palette: PurpleThemePalette
    public let onFind: () -> Void
    public let onFindNext: () -> Void
    public let onFindPrevious: () -> Void
    public let onReplace: () -> Void
    public let onReplaceAll: () -> Void
    public let onGoToLine: () -> Void
    public let onClose: () -> Void
    @FocusState private var focusedField: FocusTarget?

    public init(
        state: Binding<FindReplaceBarState>,
        palette: PurpleThemePalette,
        onFind: @escaping () -> Void,
        onFindNext: @escaping () -> Void,
        onFindPrevious: @escaping () -> Void,
        onReplace: @escaping () -> Void = {},
        onReplaceAll: @escaping () -> Void,
        onGoToLine: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._state = state
        self.palette = palette
        self.onFind = onFind
        self.onFindNext = onFindNext
        self.onFindPrevious = onFindPrevious
        self.onReplace = onReplace
        self.onReplaceAll = onReplaceAll
        self.onGoToLine = onGoToLine
        self.onClose = onClose
    }

    public var body: some View {
        Group {
            if state.mode != .hidden {
                HStack(spacing: 8) {
                    if state.mode == .goToLine {
                        Text("Go to Line:")
                            .appFont(.caption, weight: .semibold)
                        TextField("Line number (1...)", text: $state.goToLineText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                            .focused($focusedField, equals: .goToLine)
                            .onSubmit { onGoToLine() }
                        Button("Jump") { onGoToLine() }
                    } else {
                        TextField("Find…", text: $state.query)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                            .focused($focusedField, equals: .query)
                            .onSubmit { onFind() }
                        Toggle("Aa", isOn: $state.isCaseSensitive)
                            .toggleStyle(.button)
                        Button("Find") { onFind() }
                        Button { onFindPrevious() } label: { AppIconView(.chevronUp, size: 13).minimumHitTarget() }
                            .buttonStyle(.plain)
                            .disabled(state.matches.isEmpty)
                            .help("Previous match")
                            .accessibilityLabel("Previous match")
                        Button { onFindNext() } label: { AppIconView(.chevronDown, size: 13).minimumHitTarget() }
                            .buttonStyle(.plain)
                            .disabled(state.matches.isEmpty)
                            .help("Next match")
                            .accessibilityLabel("Next match")
                        Text("\(state.matches.count) match(es)")
                            .appFont(.caption, monospaced: true)
                        if state.mode == .findAndReplace {
                            TextField("Replace…", text: $state.replacement)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)
                                .focused($focusedField, equals: .replacement)
                            Button("Replace") { onReplace() }
                                .disabled(state.query.isEmpty || state.matches.isEmpty)
                            Button("Replace All") { onReplaceAll() }
                                .disabled(state.query.isEmpty)
                        }
                    }
                    Spacer()
                    Button(action: onClose) {
                        AppIconView(.close, size: 12)
                            .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                            .minimumHitTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close Find Bar")
                }
                .controlSize(.small)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .foregroundStyle(palette.chromeForeground.swiftUIColor)
                .tint(palette.chromeAccent.swiftUIColor)
                .background(palette.findBarSurface.swiftUIColor)
                .purpleHairlineBorder(palette: palette, edge: .bottom)
                .onAppear { syncFocus(for: state.mode) }
                .onExitCommand { onClose() }
            }
        }
        .onChange(of: state.mode) { _, newMode in
            syncFocus(for: newMode)
        }
    }

    private func syncFocus(for mode: FindBarPresentationMode) {
        switch mode {
        case .find, .findAndReplace:
            focusedField = .query
        case .goToLine:
            focusedField = .goToLine
        case .hidden:
            focusedField = nil
        }
    }
}
#endif
