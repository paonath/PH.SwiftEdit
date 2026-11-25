import Foundation

/// Supported appearance modes for the Concept E2 Purple chrome and inverted `#FFFFFF`/`#000000` editor canvas (`DATA-008`, `UI-003`).
public enum AppearanceMode: String, CaseIterable, Codable, Equatable, Sendable {
    case light
    case black
    case auto
}

/// Selectable Base16 / Tinted-Theming-inspired semantic syntax color schemes (MIT, zero external dependencies, WCAG AA `>= 4.5:1` on `#FFFFFF`/`#000000`) (`UI-002`, `UI-009`).
public enum SyntaxColorScheme: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case swiftEditDefault
    case catppuccin
    case github
    case tokyoNight

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .swiftEditDefault: return "SwiftEdit Default"
        case .catppuccin: return "Catppuccin"
        case .github: return "GitHub"
        case .tokyoNight: return "Tokyo Night"
        }
    }

    public var subtitle: String {
        switch self {
        case .swiftEditDefault: return "Purple accents & high-contrast semantic tokens"
        case .catppuccin: return "Soothing pastel Latte (Light) & Mocha (Black)"
        case .github: return "Crisp GitHub Light & Dark high-contrast tokens"
        case .tokyoNight: return "Calibrated indigo & emerald Day / Night tokens"
        }
    }
}

/// Schema-clamped non-sensitive UI preferences value object (`DATA-008`, `UI-007`).
public struct EditorPreferences: Codable, Equatable, Sendable {
    public static let minZoomPercent: Int = 50
    public static let maxZoomPercent: Int = 300
    public static let defaultZoomPercent: Int = 100

    public let appearanceMode: AppearanceMode
    public let syntaxColorScheme: SyntaxColorScheme
    public let zoomPercent: Int
    public let interfaceFont: FontChoice
    public let editorFont: FontChoice
    /// Selected terminal bundle identifier (`nil` = Auto, preferring iTerm2 if installed; otherwise explicit allowlisted bundle ID).
    public let preferredTerminalBundleID: String?
    /// Whether soft line wrapping is enabled in the editor (`Cmd+W`). Defaults to `true`.
    public let isWordWrapEnabled: Bool
    /// Whether SwiftEdit opens in full-screen mode by default on launch. Defaults to `true`.
    public let launchInFullScreen: Bool
    /// Persisted height of the embedded bottom terminal panel in points (`120...720`).
    public let terminalPanelHeight: Int
    /// Whether trailing horizontal whitespace is automatically stripped on explicit Save (`REQ-009`). Defaults to `false`.
    public let trimTrailingWhitespaceOnSave: Bool

    public static let minTerminalPanelHeight: Int = 120
    public static let maxTerminalPanelHeight: Int = 720
    public static let defaultTerminalPanelHeight: Int = 240

    public init(
        appearanceMode: AppearanceMode = .auto,
        syntaxColorScheme: SyntaxColorScheme = .swiftEditDefault,
        zoomPercent: Int = EditorPreferences.defaultZoomPercent,
        interfaceFont: FontChoice = .default,
        editorFont: FontChoice = .default,
        preferredTerminalBundleID: String? = nil,
        isWordWrapEnabled: Bool = true,
        launchInFullScreen: Bool = true,
        terminalPanelHeight: Int = EditorPreferences.defaultTerminalPanelHeight,
        trimTrailingWhitespaceOnSave: Bool = false
    ) {
        self.appearanceMode = appearanceMode
        self.syntaxColorScheme = syntaxColorScheme
        self.zoomPercent = Self.clampZoom(zoomPercent)
        self.interfaceFont = interfaceFont
        self.editorFont = editorFont
        self.preferredTerminalBundleID = preferredTerminalBundleID?.isEmpty == true ? nil : preferredTerminalBundleID
        self.isWordWrapEnabled = isWordWrapEnabled
        self.launchInFullScreen = launchInFullScreen
        self.terminalPanelHeight = Self.clampTerminalHeight(terminalPanelHeight)
        self.trimTrailingWhitespaceOnSave = trimTrailingWhitespaceOnSave
    }

    /// Font choice for `role`.
    public func font(for role: TypographyRole) -> FontChoice {
        role == .interface ? interfaceFont : editorFont
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawMode = try? container.decode(String.self, forKey: .appearanceMode)
        self.appearanceMode = rawMode.flatMap(AppearanceMode.init(rawValue:)) ?? .auto
        let rawScheme = try? container.decode(String.self, forKey: .syntaxColorScheme)
        self.syntaxColorScheme = rawScheme.flatMap(SyntaxColorScheme.init(rawValue:)) ?? .swiftEditDefault
        let decodedZoom = (try? container.decode(Int.self, forKey: .zoomPercent)) ?? Self.defaultZoomPercent
        self.zoomPercent = Self.clampZoom(decodedZoom)
        self.interfaceFont = .default
        self.editorFont = .default
        self.preferredTerminalBundleID = nil
        self.isWordWrapEnabled = (try? container.decode(Bool.self, forKey: .isWordWrapEnabled)) ?? true
        self.launchInFullScreen = (try? container.decode(Bool.self, forKey: .launchInFullScreen)) ?? true
        let decodedHeight = (try? container.decode(Int.self, forKey: .terminalPanelHeight)) ?? Self.defaultTerminalPanelHeight
        self.terminalPanelHeight = Self.clampTerminalHeight(decodedHeight)
        self.trimTrailingWhitespaceOnSave = (try? container.decode(Bool.self, forKey: .trimTrailingWhitespaceOnSave)) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case appearanceMode
        case syntaxColorScheme
        case zoomPercent
        case isWordWrapEnabled
        case launchInFullScreen
        case terminalPanelHeight
        case trimTrailingWhitespaceOnSave
    }

    public static func clampZoom(_ rawZoom: Int) -> Int {
        min(max(rawZoom, minZoomPercent), maxZoomPercent)
    }

    public static func clampTerminalHeight(_ rawHeight: Int) -> Int {
        min(max(rawHeight, minTerminalPanelHeight), maxTerminalPanelHeight)
    }
}

/// Anti-Corruption Layer adapter serializing `EditorPreferences` through `PreferencesProviding` (`~/.SwiftEdit/settings.json` in production or `InMemoryKeyValueStore` in tests) without storing document contents (`BC-007`, `DATA-008`, `PERF-003`, `TEST-003`).
public struct EditorPreferencesStore: Sendable {
    public static let appearanceModeKey = "swiftedit.appearanceMode"
    public static let syntaxColorSchemeKey = "swiftedit.appearance.syntaxColorScheme"
    public static let zoomPercentKey = "swiftedit.zoomPercent"
    public static let interfaceFontKey = "swiftedit.font.interface"
    public static let editorFontKey = "swiftedit.font.editor"
    public static let preferredTerminalBundleIDKey = "swiftedit.terminal.bundleID"
    public static let isWordWrapEnabledKey = "swiftedit.editor.wordWrap"
    public static let launchInFullScreenKey = "swiftedit.window.launchInFullScreen"
    public static let terminalPanelHeightKey = "swiftedit.terminal.panelHeight"
    public static let trimTrailingWhitespaceOnSaveKey = "swiftedit.editor.trimTrailingWhitespaceOnSave"

    public let suiteName: String?
    private let store: any PreferencesProviding

    public init(store: any PreferencesProviding) {
        self.suiteName = nil
        self.store = store
    }

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
        self.store = UserDefaultsPreferencesStore(suiteName: suiteName)
    }

    /// Creates the default production JSON preferences store at `~/.SwiftEdit/settings.json`,
    /// migrating existing `UserDefaults.standard` values once if `settings.json` does not exist yet.
    public static func defaultHomeJSONStore() -> JSONPreferencesStore {
        let jsonURL = JSONPreferencesStore.defaultSettingsFileURL()
        let existed = FileManager.default.fileExists(atPath: jsonURL.path)
        let jsonStore = JSONPreferencesStore(fileURL: jsonURL)
        if !existed {
            let legacy = EditorPreferencesStore(suiteName: nil).load()
            EditorPreferencesStore(store: jsonStore).save(legacy)
        }
        return jsonStore
    }

    /// Writes `preferences` into the configured preferences store (coalesced into one atomic write for `JSONPreferencesStore`).
    public func save(_ preferences: EditorPreferences) {
        let writeAll = {
            store.set(preferences.appearanceMode.rawValue, forKey: Self.appearanceModeKey)
            store.set(preferences.syntaxColorScheme.rawValue, forKey: Self.syntaxColorSchemeKey)
            store.set(preferences.zoomPercent, forKey: Self.zoomPercentKey)
            store.set(preferences.interfaceFont.storageValue, forKey: Self.interfaceFontKey)
            store.set(preferences.editorFont.storageValue, forKey: Self.editorFontKey)
            store.set(preferences.preferredTerminalBundleID, forKey: Self.preferredTerminalBundleIDKey)
            store.set(preferences.isWordWrapEnabled, forKey: Self.isWordWrapEnabledKey)
            store.set(preferences.launchInFullScreen, forKey: Self.launchInFullScreenKey)
            store.set(preferences.terminalPanelHeight, forKey: Self.terminalPanelHeightKey)
            store.set(preferences.trimTrailingWhitespaceOnSave, forKey: Self.trimTrailingWhitespaceOnSaveKey)
        }
        if let jsonStore = store as? JSONPreferencesStore {
            jsonStore.performBatch(writeAll)
        } else {
            writeAll()
        }
    }

    /// Reads and clamps `EditorPreferences` from the configured preferences store, defaulting unknown modes to `.auto` and missing zoom to `100%`.
    public func load() -> EditorPreferences {
        let mode = store.string(forKey: Self.appearanceModeKey).flatMap(AppearanceMode.init(rawValue:)) ?? .auto
        let scheme = store.string(forKey: Self.syntaxColorSchemeKey).flatMap(SyntaxColorScheme.init(rawValue:)) ?? .swiftEditDefault
        let zoom: Int
        if store.object(forKey: Self.zoomPercentKey) != nil {
            zoom = store.integer(forKey: Self.zoomPercentKey)
        } else {
            zoom = EditorPreferences.defaultZoomPercent
        }
        let rawTerminal = store.string(forKey: Self.preferredTerminalBundleIDKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredTerminal = (rawTerminal?.isEmpty == false) ? rawTerminal : nil
        let wordWrap: Bool = (store.object(forKey: Self.isWordWrapEnabledKey) != nil)
            ? store.bool(forKey: Self.isWordWrapEnabledKey)
            : true
        let fullScreen: Bool = (store.object(forKey: Self.launchInFullScreenKey) != nil)
            ? store.bool(forKey: Self.launchInFullScreenKey)
            : true
        let termHeight: Int = (store.object(forKey: Self.terminalPanelHeightKey) != nil)
            ? store.integer(forKey: Self.terminalPanelHeightKey)
            : EditorPreferences.defaultTerminalPanelHeight
        let trimOnSave: Bool = (store.object(forKey: Self.trimTrailingWhitespaceOnSaveKey) != nil)
            ? store.bool(forKey: Self.trimTrailingWhitespaceOnSaveKey)
            : false
        // Missing keys (pre-017 preferences) and malformed values both resolve to `.default` (fail closed).
        return EditorPreferences(
            appearanceMode: mode,
            syntaxColorScheme: scheme,
            zoomPercent: zoom,
            interfaceFont: FontChoice.validated(store.object(forKey: Self.interfaceFontKey)),
            editorFont: FontChoice.validated(store.object(forKey: Self.editorFontKey)),
            preferredTerminalBundleID: preferredTerminal,
            isWordWrapEnabled: wordWrap,
            launchInFullScreen: fullScreen,
            terminalPanelHeight: termHeight,
            trimTrailingWhitespaceOnSave: trimOnSave
        )
    }
}
