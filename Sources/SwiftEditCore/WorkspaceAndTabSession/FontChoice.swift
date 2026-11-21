import Foundation

/// Typography roles that carry an independent user font choice (`REQ-003`).
public enum TypographyRole: String, CaseIterable, Sendable {
    /// Chrome, sidebar, tabs, sheets, popovers and panels.
    case interface
    /// The TextKit 2 editor canvas and the line-number gutter.
    case editor
}

/// User font choice for one `TypographyRole`, persisted as a short string (`DATA-008`, `SEC-012`).
///
/// Stores family names only, never file paths or URLs, so a preference value can never make the app load a font file.
/// `validated(_:)` is fail-closed: anything that is not a well-formed choice decodes to `.default`.
public enum FontChoice: Hashable, Sendable {
    /// The built-in role font (monospaced system font for the editor, system font for the interface).
    case `default`
    /// An installed system font family, e.g. `"Avenir Next"`.
    case system(family: String)
    /// The bundled, hash-verified OpenDyslexic family.
    case openDyslexic

    /// Maximum family-name length in Unicode scalars.
    public static let maxFamilyScalars = 128
    private static let systemPrefix = "system:"

    /// Persisted representation: `default`, `openDyslexic` or `system:<family>`.
    public var storageValue: String {
        switch self {
        case .default: return "default"
        case .openDyslexic: return "openDyslexic"
        case .system(let family): return Self.systemPrefix + family
        }
    }

    /// Decodes a stored value; non-strings, unknown tokens, empty, oversized, control-character or path-like family
    /// names all yield `.default`.
    public static func validated(_ raw: Any?) -> FontChoice {
        guard let value = raw as? String else { return .default }
        switch value {
        case "default": return .default
        case "openDyslexic": return .openDyslexic
        default:
            guard value.hasPrefix(systemPrefix) else { return .default }
            let family = String(value.dropFirst(systemPrefix.count))
            return isAcceptableFamily(family) ? .system(family: family) : .default
        }
    }

    /// `true` for printable, trimmed names of `1...maxFamilyScalars` scalars without path separators.
    public static func isAcceptableFamily(_ family: String) -> Bool {
        let scalars = family.unicodeScalars
        guard !scalars.isEmpty, scalars.count <= maxFamilyScalars, family == family.trimmingCharacters(in: .whitespaces) else { return false }
        guard !family.contains("/"), !family.contains("\\"), !family.hasPrefix(".") else { return false }
        return !scalars.contains { CharacterSet.controlCharacters.contains($0) || CharacterSet.illegalCharacters.contains($0) }
    }
}
