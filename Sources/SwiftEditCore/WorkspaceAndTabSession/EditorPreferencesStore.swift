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

    public init(
        appearanceMode: AppearanceMode = .auto,
        zoomPercent: Int = EditorPreferences.defaultZoomPercent,
        interfaceFont: FontChoice = .default,
        editorFont: FontChoice = .default,
        preferredTerminalBundleID: String? = nil
    ) {
        self.appearanceMode = appearanceMode
        self.zoomPercent = Self.clampZoom(zoomPercent)
        self.interfaceFont = interfaceFont
        self.editorFont = editorFont
        self.preferredTerminalBundleID = preferredTerminalBundleID?.isEmpty == true ? nil : preferredTerminalBundleID
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
    }

    private enum CodingKeys: String, CodingKey {
        case appearanceMode
        case zoomPercent
    }

    public static func clampZoom(_ rawZoom: Int) -> Int {
        min(max(rawZoom, minZoomPercent), maxZoomPercent)
    }
}

/// Anti-Corruption Layer adapter serializing `EditorPreferences` through `PreferencesProviding` (`UserDefaults.standard` in production or `InMemoryKeyValueStore` in tests) without storing document contents (`BC-007`, `DATA-008`, `PERF-003`, `TEST-003`).
public struct EditorPreferencesStore: Sendable {
    public static let appearanceModeKey = "swiftedit.appearanceMode"
    public static let zoomPercentKey = "swiftedit.zoomPercent"
    public static let interfaceFontKey = "swiftedit.font.interface"
    public static let editorFontKey = "swiftedit.font.editor"
    public static let preferredTerminalBundleIDKey = "swiftedit.terminal.bundleID"

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

    /// Writes `preferences` into the configured preferences store.
    public func save(_ preferences: EditorPreferences) {
        store.set(preferences.appearanceMode.rawValue, forKey: Self.appearanceModeKey)
        store.set(preferences.zoomPercent, forKey: Self.zoomPercentKey)
        store.set(preferences.interfaceFont.storageValue, forKey: Self.interfaceFontKey)
        store.set(preferences.editorFont.storageValue, forKey: Self.editorFontKey)
        store.set(preferences.preferredTerminalBundleID, forKey: Self.preferredTerminalBundleIDKey)
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
        // Missing keys (pre-017 preferences) and malformed values both resolve to `.default` (fail closed).
        return EditorPreferences(
            appearanceMode: mode,
            zoomPercent: zoom,
            interfaceFont: FontChoice.validated(store.object(forKey: Self.interfaceFontKey)),
            editorFont: FontChoice.validated(store.object(forKey: Self.editorFontKey)),
            preferredTerminalBundleID: preferredTerminal
        )
    }
}
