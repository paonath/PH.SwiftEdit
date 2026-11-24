#if os(macOS)
import AppKit
import SwiftEditCore
import SwiftUI

/// Single resolver for every font in the app, per `TypographyRole` (`REQ-004`, `REQ-008`, `UI-002`, `UI-005`).
///
/// Resolution order: the chosen family with the requested weight/italic, then that family's regular face (missing
/// trait), then the role default (missing family or unavailable OpenDyslexic). The default editor font is the
/// monospaced system font (amended `UI-002`: monospaced by default, not mandatory). Results are cached per
/// `(role, size, weight, italic)`; changing a role's choice drops only that role's entries, and zoom produces new size
/// keys, so a cached font can never be stale (`N11`).
@MainActor
public final class AppTypography {
    private struct Key: Hashable {
        let role: TypographyRole
        let size: CGFloat
        let weight: CGFloat
        let italic: Bool
        let monospaced: Bool
    }

    /// Default-choice resolver for views rendered outside the workbench environment (e.g. the Settings scene).
    public static let fallback = AppTypography()

    private var choices: [TypographyRole: FontChoice]
    private let openDyslexic: OpenDyslexicBundle
    private var cache: [Key: NSFont] = [:]

    public init(interface: FontChoice = .default, editor: FontChoice = .default, openDyslexic: OpenDyslexicBundle? = nil) {
        self.choices = [.interface: interface, .editor: editor]
        self.openDyslexic = openDyslexic ?? .shared
    }

    public func choice(for role: TypographyRole) -> FontChoice { choices[role] ?? .default }

    /// Updates `role` and invalidates only its cached fonts.
    public func setChoice(_ choice: FontChoice, for role: TypographyRole) {
        guard choices[role] != choice else { return }
        choices[role] = choice
        cache = cache.filter { $0.key.role != role }
    }

    /// `NSFont` for `role` at `size` points.
    /// `monospaced` only affects the `.default` choice (monospaced system face); a chosen family always wins.
    public func nsFont(_ role: TypographyRole, size: CGFloat, weight: NSFont.Weight = .regular, italic: Bool = false, monospaced: Bool = false) -> NSFont {
        let key = Key(role: role, size: size, weight: weight.rawValue, italic: italic, monospaced: monospaced)
        if let cached = cache[key] { return cached }
        let font = resolve(choice(for: role), role: monospaced ? .editor : role, size: size, weight: weight, italic: italic)
        cache[key] = font
        return font
    }

    /// SwiftUI `Font` backed by the same cached `NSFont`.
    public func font(_ role: TypographyRole, size: CGFloat, weight: NSFont.Weight = .regular, italic: Bool = false, monospaced: Bool = false) -> Font {
        Font(nsFont(role, size: size, weight: weight, italic: italic, monospaced: monospaced))
    }

    private func resolve(_ choice: FontChoice, role: TypographyRole, size: CGFloat, weight: NSFont.Weight, italic: Bool) -> NSFont {
        let isBold = weight.rawValue >= NSFont.Weight.semibold.rawValue
        switch choice {
        case .default:
            break
        case .openDyslexic:
            if let face = openDyslexic.verifiedFace(size: size, bold: isBold, italic: italic)
                ?? openDyslexic.verifiedFace(size: size, bold: false, italic: false) {
                return face
            }
        case .system(let family):
            if let face = Self.systemFamilyFont(family, size: size, weight: weight, italic: italic) { return face }
        }
        return Self.roleDefault(role, size: size, weight: weight, italic: italic)
    }

    /// Family face with the requested traits via `NSFontDescriptor` and `NSFontManager.convert` (avoiding `.font(...)` call-graph cycles), or the family's regular face when a trait is missing; `nil` if absent (`REQ-007`).
    private static func systemFamilyFont(_ family: String, size: CGFloat, weight: NSFont.Weight, italic: Bool) -> NSFont? {
        let baseDescriptor = NSFontDescriptor(fontAttributes: [.family: family])
        guard let matchedDescriptor = baseDescriptor.matchingFontDescriptors(withMandatoryKeys: [.family]).first,
              let regularFace = NSFont(descriptor: matchedDescriptor, size: size) else {
            return nil
        }
        let manager = NSFontManager.shared
        var resolved = regularFace
        if weight.rawValue >= NSFont.Weight.semibold.rawValue {
            let bolded = manager.convert(resolved, toHaveTrait: .boldFontMask)
            if bolded.familyName == regularFace.familyName { resolved = bolded }
        } else if weight.rawValue <= NSFont.Weight.light.rawValue {
            let lighter = manager.convertWeight(false, of: resolved)
            if lighter.familyName == regularFace.familyName { resolved = lighter }
        }
        if italic {
            let italicized = manager.convert(resolved, toHaveTrait: .italicFontMask)
            if italicized.familyName == regularFace.familyName { resolved = italicized }
        }
        return resolved
    }

    private static func roleDefault(_ role: TypographyRole, size: CGFloat, weight: NSFont.Weight, italic: Bool) -> NSFont {
        let base = role == .editor
            ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)
        return italic ? NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask) : base
    }
}

/// Semantic text styles mapped to fixed macOS point sizes (the system's default text-style metrics), so every style
/// can be rendered in the user's chosen family (`REQ-008`).
public enum AppTextStyle: Sendable {
    case caption2, caption, footnote, subheadline, callout, body, headline, title3, title2, title

    public var pointSize: CGFloat {
        switch self {
        case .caption2: return 10
        case .caption, .footnote: return 10
        case .subheadline: return 11
        case .callout: return 12
        case .body, .headline: return 13
        case .title3: return 15
        case .title2: return 17
        case .title: return 22
        }
    }

    /// Weight implied by the style when the call site does not override it.
    public var defaultWeight: Font.Weight { self == .headline ? .semibold : .regular }
}

/// Typography handed down the SwiftUI environment from the root view; `generation` changes whenever a font choice does.
public struct AppTypographyContext: @unchecked Sendable {
    public let typography: AppTypography?
    public let generation: Int
    public init(typography: AppTypography?, generation: Int) {
        self.typography = typography
        self.generation = generation
    }
}

private struct AppTypographyContextKey: EnvironmentKey {
    static let defaultValue = AppTypographyContext(typography: nil, generation: 0)
}

public extension EnvironmentValues {
    var appTypography: AppTypographyContext {
        get { self[AppTypographyContextKey.self] }
        set { self[AppTypographyContextKey.self] = newValue }
    }
}

extension Font.Weight {
    /// AppKit weight equivalent used by `AppTypography`.
    var nsWeight: NSFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.appTypography) private var context
    let role: TypographyRole
    let size: CGFloat
    let weight: Font.Weight
    let italic: Bool
    let monospaced: Bool

    func body(content: Content) -> some View {
        let typography = context.typography ?? AppTypography.fallback
        return content.font(typography.font(role, size: size, weight: weight.nsWeight, italic: italic, monospaced: monospaced))
    }
}

public extension View {
    /// Applies a semantic style in the user's interface (or editor) font (`REQ-008`).
    func appFont(_ style: AppTextStyle, weight: Font.Weight? = nil, italic: Bool = false, monospaced: Bool = false, role: TypographyRole = .interface) -> some View {
        modifier(AppFontModifier(role: role, size: style.pointSize, weight: weight ?? style.defaultWeight, italic: italic, monospaced: monospaced))
    }

    /// Applies an explicit point size (zoom-scaled chrome) in the user's interface (or editor) font.
    func appFont(size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false, monospaced: Bool = false, role: TypographyRole = .interface) -> some View {
        modifier(AppFontModifier(role: role, size: size, weight: weight, italic: italic, monospaced: monospaced))
    }
}
#endif
