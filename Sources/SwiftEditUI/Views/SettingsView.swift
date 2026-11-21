#if os(macOS)
import AppKit
import SwiftEditCore
import SwiftUI

/// Sidebar sections of the redesigned `Cmd+,` Settings window (`UI-001`, `UI-010`).
public enum SettingsSection: String, CaseIterable, Identifiable, Equatable, Sendable {
    case fonts
    case terminal
    case updates

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fonts: return "Fonts"
        case .terminal: return "Terminal"
        case .updates: return "Updates"
        }
    }

    public var systemImage: String {
        switch self {
        case .fonts: return "textformat"
        case .terminal: return "terminal"
        case .updates: return "arrow.down.circle"
        }
    }
}

/// One row of a Settings font picker (pure, headless-testable) (`REQ-007`, `UI-010`).
struct SettingsFontRow: Identifiable, Equatable {
    let title: String
    let choice: FontChoice
    let isSelected: Bool
    let isHighlighted: Bool
    /// VoiceOver label naming the role, the family and the selection state.
    let accessibilityLabel: String
    var id: String { choice.storageValue }
}

/// Logic of the redesigned Settings window: categorized sections, font pickers, installed terminal discovery, and update checks.
@MainActor
@Observable
final class SettingsViewModel {
    @ObservationIgnored let model: SwiftEditWorkbenchModel
    @ObservationIgnored private let catalog: SystemFontCatalog
    @ObservationIgnored private let installedTerminalsProvider: @MainActor () -> [KnownTerminalApp]

    var selectedSection: SettingsSection = .fonts
    var queries: [TypographyRole: String] = [:]
    private var highlights: [TypographyRole: Int] = [:]
    private(set) var installedTerminals: [KnownTerminalApp] = []

    init(
        model: SwiftEditWorkbenchModel,
        catalog: SystemFontCatalog,
        installedTerminalsProvider: (@MainActor () -> [KnownTerminalApp])? = nil
    ) {
        self.model = model
        self.catalog = catalog
        let provider = installedTerminalsProvider ?? { TerminalCatalog.installedTerminals() }
        self.installedTerminalsProvider = provider
        self.installedTerminals = provider()
    }

    var palette: PurpleThemePalette { model.palette }

    var selectedTerminalBundleID: String? { model.preferredTerminalBundleID }

    var autoResolvedTerminalName: String {
        let installedIDs = Set(installedTerminals.map(\.bundleIdentifier))
        let resolvedID = TerminalCatalog.resolveBundleID(preferredBundleID: nil, installedBundleIDs: installedIDs)
        return TerminalCatalog.knownTerminals.first(where: { $0.bundleIdentifier == resolvedID })?.displayName ?? "Terminal"
    }

    func refreshInstalledTerminals() {
        installedTerminals = installedTerminalsProvider()
    }

    func selectTerminal(_ bundleID: String?) {
        model.setPreferredTerminalBundleID(bundleID)
    }

    func checkForUpdatesInline() {
        Task { @MainActor [weak model] in
            await model?.performUpdateCheck(presentDialog: false)
        }
    }

    private func entries(for role: TypographyRole) -> [FontCatalogEntry] {
        catalog.entries(matching: queries[role] ?? "")
    }

    private func selected(for role: TypographyRole) -> FontChoice {
        role == .interface ? model.interfaceFont : model.editorFont
    }

    func rows(for role: TypographyRole) -> [SettingsFontRow] {
        let current = selected(for: role)
        let highlight = highlights[role]
        let prefix = role == .interface ? "Interface font" : "Editor font"
        return entries(for: role).enumerated().map { index, entry in
            let isSelected = entry.choice == current
            return SettingsFontRow(
                title: entry.title,
                choice: entry.choice,
                isSelected: isSelected,
                isHighlighted: highlight == index,
                accessibilityLabel: "\(prefix) \(entry.title)\(isSelected ? ", selected" : "")"
            )
        }
    }

    func select(_ choice: FontChoice, for role: TypographyRole) {
        model.setFontChoice(choice, for: role)
    }

    /// Arrow-key navigation; the highlight starts on the selected row and clamps at both ends.
    func moveHighlight(by delta: Int, for role: TypographyRole) {
        let list = entries(for: role)
        guard !list.isEmpty else { return }
        let start = highlights[role] ?? list.firstIndex { $0.choice == selected(for: role) } ?? 0
        highlights[role] = min(max(0, start + delta), list.count - 1)
    }

    /// `Return` applies the highlighted row.
    func confirmHighlight(for role: TypographyRole) {
        let list = entries(for: role)
        guard let index = highlights[role], list.indices.contains(index) else { return }
        select(list[index].choice, for: role)
    }

    @ObservationIgnored private var previewFonts: [FontChoice: Font] = [:]

    /// Preview font for a catalog row (the family itself, at 13 pt), resolved once per choice.
    func previewFont(for choice: FontChoice) -> Font {
        if let cached = previewFonts[choice] { return cached }
        let font = AppTypography(interface: choice, editor: choice).font(.interface, size: 13)
        previewFonts[choice] = font
        return font
    }
}

/// `Cmd+,` Settings window featuring categorized sidebar sections (`Fonts`, `Terminal`, `Updates`) (`UI-001`, `UI-010`, `SEC-004`).
public struct SwiftEditSettingsView: View {
    @State private var settings: SettingsViewModel?
    private let modelProvider: @MainActor () -> SwiftEditWorkbenchModel?

    /// `modelProvider` is evaluated when the window appears: the Settings scene is built before any workbench window.
    public init(modelProvider: @escaping @MainActor () -> SwiftEditWorkbenchModel? = { SwiftEditAppLifecycleBridge.shared.activeWorkbench }) {
        self.modelProvider = modelProvider
    }

    public var body: some View {
        Group {
            if let settings {
                HStack(spacing: 0) {
                    SettingsSidebarView(settings: settings)
                        .frame(width: 176)
                        .background(settings.palette.sidebarSurface.swiftUIColor)
                        .purpleHairlineBorder(palette: settings.palette, edge: .trailing)

                    detailPane(for: settings)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(settings.palette.chromeSurface.swiftUIColor)
                }
                .foregroundStyle(settings.palette.chromeForeground.swiftUIColor)
            } else {
                Text("Open a window to edit settings.")
                    .appFont(.callout)
                    .padding(24)
            }
        }
        .frame(minWidth: 740, minHeight: 460)
        .onAppear {
            guard settings == nil, let model = modelProvider() else { return }
            settings = SettingsViewModel(
                model: model,
                catalog: SystemFontCatalog(isOpenDyslexicAvailable: { OpenDyslexicBundle.shared.registerIfNeeded().isAvailable })
            )
        }
    }

    @ViewBuilder
    private func detailPane(for settings: SettingsViewModel) -> some View {
        switch settings.selectedSection {
        case .fonts:
            HStack(alignment: .top, spacing: 16) {
                FontPickerColumn(title: "Interface Font", role: .interface, settings: settings)
                FontPickerColumn(title: "Editor Font", role: .editor, settings: settings)
            }
            .padding(16)
        case .terminal:
            TerminalSettingsPane(settings: settings)
                .padding(20)
        case .updates:
            UpdatesSettingsPane(settings: settings)
                .padding(20)
        }
    }
}

private struct SettingsSidebarView: View {
    @Bindable var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .appFont(.headline, weight: .semibold)
                .foregroundStyle(settings.palette.secondaryForeground.swiftUIColor)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            ForEach(SettingsSection.allCases) { section in
                let isSelected = settings.selectedSection == section
                Button {
                    settings.selectedSection = section
                    if section == .terminal {
                        settings.refreshInstalledTerminals()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.systemImage)
                            .appFont(.callout, weight: .medium)
                            .foregroundStyle((isSelected ? settings.palette.chromeAccent : settings.palette.secondaryForeground).swiftUIColor)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        Text(section.title)
                            .appFont(.callout, weight: isSelected ? .semibold : .regular)
                            .foregroundStyle(settings.palette.chromeForeground.swiftUIColor)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isSelected ? settings.palette.tabActiveSurface.swiftUIColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? settings.palette.chromeAccent.swiftUIColor : Color.clear, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(section.title) settings")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
    }
}

/// Searchable list for one role; arrow keys move the highlight, `Return` applies it, clicks apply directly.
private struct FontPickerColumn: View {
    let title: String
    let role: TypographyRole
    @Bindable var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).appFont(.headline)
            TextField("Search fonts", text: Binding(get: { settings.queries[role] ?? "" }, set: { settings.queries[role] = $0 }))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search \(title.lowercased())s")
            List(settings.rows(for: role)) { row in
                Button { settings.select(row.choice, for: role) } label: {
                    HStack {
                        Text(row.title).font(settings.previewFont(for: row.choice))
                        Spacer()
                        if row.isSelected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(settings.palette.chromeAccent.swiftUIColor)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                    .frame(minHeight: ChromeHitTarget.minimumPoints)
                }
                .buttonStyle(.plain)
                .listRowBackground(row.isHighlighted ? Color.accentColor.opacity(0.2) : Color.clear)
                .accessibilityLabel(row.accessibilityLabel)
            }
            .focusable()
            .onKeyPress(.downArrow) { settings.moveHighlight(by: 1, for: role); return .handled }
            .onKeyPress(.upArrow) { settings.moveHighlight(by: -1, for: role); return .handled }
            .onKeyPress(.return) { settings.confirmHighlight(for: role); return .handled }
            if role == .editor {
                Text("Proportional fonts do not align table or code columns.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Terminal discovery & selection pane driving `Open in Terminal` across the sidebar (`SEC-004`).
private struct TerminalSettingsPane: View {
    @Bindable var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Terminal Application")
                        .appFont(.headline, weight: .semibold)
                    Text("Detected allowlisted terminals installed on this Mac for Open in Terminal.")
                        .appFont(.caption)
                        .foregroundStyle(settings.palette.secondaryForeground.swiftUIColor)
                }
                Spacer()
                Button {
                    settings.refreshInstalledTerminals()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .appFont(.caption, weight: .medium)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Refresh installed terminals")
            }

            List {
                terminalRow(
                    title: "Auto (Default: \(settings.autoResolvedTerminalName))",
                    subtitle: "Uses iTerm2 when installed, otherwise macOS Terminal",
                    isSelected: settings.selectedTerminalBundleID == nil,
                    accessibilityLabel: "Auto terminal selection, defaults to \(settings.autoResolvedTerminalName)"
                ) {
                    settings.selectTerminal(nil)
                }

                ForEach(settings.installedTerminals) { terminal in
                    let isSelected = settings.selectedTerminalBundleID == terminal.bundleIdentifier
                    terminalRow(
                        title: terminal.displayName,
                        subtitle: terminal.bundleIdentifier,
                        isSelected: isSelected,
                        accessibilityLabel: "Terminal \(terminal.displayName)\(isSelected ? ", selected" : "")"
                    ) {
                        settings.selectTerminal(terminal.bundleIdentifier)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Detected \(settings.installedTerminals.count) installed terminal(s). Launches pass strictly a verified directory URL with zero shell arguments.")
                .appFont(.caption)
                .foregroundStyle(settings.palette.secondaryForeground.swiftUIColor)
        }
        .onAppear {
            settings.refreshInstalledTerminals()
        }
    }

    private func terminalRow(
        title: String,
        subtitle: String,
        isSelected: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .appFont(.callout, weight: isSelected ? .semibold : .regular)
                        .foregroundStyle(settings.palette.chromeForeground.swiftUIColor)
                    Text(subtitle)
                        .appFont(.caption2, monospaced: true)
                        .foregroundStyle(settings.palette.secondaryForeground.swiftUIColor)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(settings.palette.chromeAccent.swiftUIColor)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .frame(minHeight: ChromeHitTarget.minimumPoints)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Updates pane inside Settings displaying installed version and manual GitHub Releases check (`SEC-001`, `SEC-004`).
private struct UpdatesSettingsPane: View {
    @Bindable var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                SwiftEditBrandLogoView(size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("SwiftEdit")
                        .appFont(.title3, weight: .bold)
                    Text("Current version: \(settings.model.currentAppVersionString)")
                        .appFont(.callout, monospaced: true)
                        .foregroundStyle(settings.palette.secondaryForeground.swiftUIColor)
                    Text("GitHub Releases: paonath/PH.SwiftEdit")
                        .appFont(.caption)
                        .foregroundStyle(settings.palette.secondaryForeground.swiftUIColor)
                }
            }

            HStack(spacing: 10) {
                Button("Check for Updates…") {
                    settings.checkForUpdatesInline()
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.palette.activeControlFill.swiftUIColor)
                .disabled(settings.model.isCheckingForUpdates)

                if settings.model.isCheckingForUpdates {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking GitHub Releases…")
                        .appFont(.caption)
                        .foregroundStyle(settings.palette.secondaryForeground.swiftUIColor)
                }
            }

            updateOutcomeView
            Spacer()
        }
    }

    @ViewBuilder
    private var updateOutcomeView: some View {
        switch settings.model.updateCheckOutcome {
        case .upToDate(let current):
            Text("SwiftEdit \(current) is the latest version.")
                .appFont(.callout, weight: .medium)
                .foregroundStyle(settings.palette.chromeForeground.swiftUIColor)
        case .noReleasesFound(let current):
            Text("No releases found on GitHub. SwiftEdit \(current) is up to date.")
                .appFont(.callout, weight: .medium)
                .foregroundStyle(settings.palette.chromeForeground.swiftUIColor)
        case .updateAvailable(let current, let latest, let releaseURL, let downloadURL):
            VStack(alignment: .leading, spacing: 8) {
                Text("New release available: SwiftEdit \(latest) (installed: \(current))")
                    .appFont(.callout, weight: .semibold)
                    .foregroundStyle(settings.palette.chromeAccent.swiftUIColor)
                HStack(spacing: 10) {
                    Button("Download Update…") {
                        settings.model.openVerifiedUpdateURL(downloadURL ?? releaseURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.palette.activeControlFill.swiftUIColor)
                    Button("View Release Page…") {
                        settings.model.openVerifiedUpdateURL(releaseURL)
                    }
                    .buttonStyle(.bordered)
                }
            }
        case .error(let message):
            Text(message)
                .appFont(.caption)
                .foregroundStyle(settings.palette.bidiWarningForeground.swiftUIColor)
        case .none:
            Text("Press \"Check for Updates…\" to query GitHub Releases.")
                .appFont(.caption)
                .foregroundStyle(settings.palette.secondaryForeground.swiftUIColor)
        }
    }
}
#endif
