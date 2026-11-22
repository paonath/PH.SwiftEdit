import Foundation

/// Supported appearance modes for the Concept E2 Purple chrome and inverted `#FFFFFF`/`#000000` editor canvas (`DATA-008`, `UI-003`).
public enum AppearanceMode: String, CaseIterable, Codable, Equatable, Sendable {
    case light
    case black
    case auto
}

/// Schema-clamped non-sensitive UI preferences value object (`DATA-008`, `UI-007`).
public struct EditorPreferences: Codable, Equatable, Sendable {
    public static let minZoomPercent: Int = 50
    public static let maxZoomPercent: Int = 300
    public static let defaultZoomPercent: Int = 100

    public let appearanceMode: AppearanceMode
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

    public static let minTerminalPanelHeight: Int = 120
    public static let maxTerminalPanelHeight: Int = 720
    public static let defaultTerminalPanelHeight: Int = 240

    public init(
        appearanceMode: AppearanceMode = .auto,
        zoomPercent: Int = EditorPreferences.defaultZoomPercent,
        interfaceFont: FontChoice = .default,
        editorFont: FontChoice = .default,
        preferredTerminalBundleID: String? = nil,
        isWordWrapEnabled: Bool = true,
        launchInFullScreen: Bool = true,
        terminalPanelHeight: Int = EditorPreferences.defaultTerminalPanelHeight
    ) {
        self.appearanceMode = appearanceMode
        self.zoomPercent = Self.clampZoom(zoomPercent)
        self.interfaceFont = interfaceFont
        self.editorFont = editorFont
        self.preferredTerminalBundleID = preferredTerminalBundleID?.isEmpty == true ? nil : preferredTerminalBundleID
        self.isWordWrapEnabled = isWordWrapEnabled
        self.launchInFullScreen = launchInFullScreen
        self.terminalPanelHeight = Self.clampTerminalHeight(terminalPanelHeight)
    }

    /// Font choice for `role`.
    public func font(for role: TypographyRole) -> FontChoice {
        role == .interface ? interfaceFont : editorFont
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawMode = try? container.decode(String.self, forKey: .appearanceMode)
        self.appearanceMode = rawMode.flatMap(AppearanceMode.init(rawValue:)) ?? .auto
        let decodedZoom = (try? container.decode(Int.self, forKey: .zoomPercent)) ?? Self.defaultZoomPercent
        self.zoomPercent = Self.clampZoom(decodedZoom)
        self.interfaceFont = .default
        self.editorFont = .default
        self.preferredTerminalBundleID = nil
        self.isWordWrapEnabled = (try? container.decode(Bool.self, forKey: .isWordWrapEnabled)) ?? true
        self.launchInFullScreen = (try? container.decode(Bool.self, forKey: .launchInFullScreen)) ?? true
        let decodedHeight = (try? container.decode(Int.self, forKey: .terminalPanelHeight)) ?? Self.defaultTerminalPanelHeight
        self.terminalPanelHeight = Self.clampTerminalHeight(decodedHeight)
    }

    private enum CodingKeys: String, CodingKey {
        case appearanceMode
        case zoomPercent
        case isWordWrapEnabled
        case launchInFullScreen
        case terminalPanelHeight
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
    public static let zoomPercentKey = "swiftedit.zoomPercent"
    public static let interfaceFontKey = "swiftedit.font.interface"
    public static let editorFontKey = "swiftedit.font.editor"
    public static let preferredTerminalBundleIDKey = "swiftedit.terminal.bundleID"
    public static let isWordWrapEnabledKey = "swiftedit.editor.wordWrap"
    public static let launchInFullScreenKey = "swiftedit.window.launchInFullScreen"
    public static let terminalPanelHeightKey = "swiftedit.terminal.panelHeight"

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
            store.set(preferences.zoomPercent, forKey: Self.zoomPercentKey)
            store.set(preferences.interfaceFont.storageValue, forKey: Self.interfaceFontKey)
            store.set(preferences.editorFont.storageValue, forKey: Self.editorFontKey)
            store.set(preferences.preferredTerminalBundleID, forKey: Self.preferredTerminalBundleIDKey)
            store.set(preferences.isWordWrapEnabled, forKey: Self.isWordWrapEnabledKey)
            store.set(preferences.launchInFullScreen, forKey: Self.launchInFullScreenKey)
            store.set(preferences.terminalPanelHeight, forKey: Self.terminalPanelHeightKey)
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
        // Missing keys (pre-017 preferences) and malformed values both resolve to `.default` (fail closed).
        return EditorPreferences(
            appearanceMode: mode,
            zoomPercent: zoom,
            interfaceFont: FontChoice.validated(store.object(forKey: Self.interfaceFontKey)),
            editorFont: FontChoice.validated(store.object(forKey: Self.editorFontKey)),
            preferredTerminalBundleID: preferredTerminal,
            isWordWrapEnabled: wordWrap,
            launchInFullScreen: fullScreen,
            terminalPanelHeight: termHeight
        )
    }
}
