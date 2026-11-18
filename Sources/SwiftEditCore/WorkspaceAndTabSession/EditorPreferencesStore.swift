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

    public init(
        appearanceMode: AppearanceMode = .auto,
        zoomPercent: Int = EditorPreferences.defaultZoomPercent
    ) {
        self.appearanceMode = appearanceMode
        self.zoomPercent = Self.clampZoom(zoomPercent)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawMode = try? container.decode(String.self, forKey: .appearanceMode)
        self.appearanceMode = rawMode.flatMap(AppearanceMode.init(rawValue:)) ?? .auto
        let decodedZoom = (try? container.decode(Int.self, forKey: .zoomPercent)) ?? Self.defaultZoomPercent
        self.zoomPercent = Self.clampZoom(decodedZoom)
    }

    private enum CodingKeys: String, CodingKey {
        case appearanceMode
        case zoomPercent
    }

    public static func clampZoom(_ rawZoom: Int) -> Int {
        min(max(rawZoom, minZoomPercent), maxZoomPercent)
    }
}

/// Anti-Corruption Layer adapter serializing `EditorPreferences` inside an isolated `UserDefaults` suite without storing document contents (`BC-007`, `DATA-008`, `TEST-003`).
public struct EditorPreferencesStore: Sendable {
    public static let appearanceModeKey = "swiftedit.appearanceMode"
    public static let zoomPercentKey = "swiftedit.zoomPercent"

    public let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    /// Writes `preferences` into the configured `UserDefaults` suite.
    public func save(_ preferences: EditorPreferences) {
        let defaults = resolveDefaults()
        defaults.set(preferences.appearanceMode.rawValue, forKey: Self.appearanceModeKey)
        defaults.set(preferences.zoomPercent, forKey: Self.zoomPercentKey)
    }

    /// Reads and clamps `EditorPreferences` from the configured `UserDefaults` suite, defaulting unknown modes to `.auto` and missing zoom to `100%`.
    public func load() -> EditorPreferences {
        let defaults = resolveDefaults()
        let mode = defaults.string(forKey: Self.appearanceModeKey).flatMap(AppearanceMode.init(rawValue:)) ?? .auto
        let zoom: Int
        if defaults.object(forKey: Self.zoomPercentKey) != nil {
            zoom = defaults.integer(forKey: Self.zoomPercentKey)
        } else {
            zoom = EditorPreferences.defaultZoomPercent
        }
        return EditorPreferences(appearanceMode: mode, zoomPercent: zoom)
    }

    private func resolveDefaults() -> UserDefaults {
        if let suiteName, let suiteDefaults = UserDefaults(suiteName: suiteName) {
            return suiteDefaults
        }
        return .standard
    }
}
