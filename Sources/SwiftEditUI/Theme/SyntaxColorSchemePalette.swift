import Foundation
import SwiftEditCore

/// WCAG AA (`>= 4.5:1` against `#FFFFFF` Light / `#000000` Black canvas) semantic syntax color slots shared across HTML, Markdown, YAML, JSON, and Log highlighting (`UI-002`, `UI-009`, `AR-005`).
public struct SyntaxColorSchemePalette: Equatable, Sendable {
    public let scheme: SyntaxColorScheme
    public let keyOrTag: RGBAColorToken
    public let attributeOrKeyword: RGBAColorToken
    public let string: RGBAColorToken
    public let numberOrTimestamp: RGBAColorToken
    public let commentOrPunctuation: RGBAColorToken
    public let linkOrEntity: RGBAColorToken
    public let warn: RGBAColorToken
    public let error: RGBAColorToken

    /// Resolves WCAG-AA-calibrated tokens for `scheme` on either `#FFFFFF` (`.light`) or `#000000` (`.black`).
    public static func resolve(scheme: SyntaxColorScheme, mode: ResolvedThemeMode) -> SyntaxColorSchemePalette {
        switch (scheme, mode) {
        case (.swiftEditDefault, .light):
            return SyntaxColorSchemePalette(
                scheme: .swiftEditDefault,
                keyOrTag: RGBAColorToken(hex: "#6D28D9"),
                attributeOrKeyword: RGBAColorToken(hex: "#7C3AED"),
                string: RGBAColorToken(hex: "#15803D"),
                numberOrTimestamp: RGBAColorToken(hex: "#0369A1"),
                commentOrPunctuation: RGBAColorToken(hex: "#57534E"),
                linkOrEntity: RGBAColorToken(hex: "#5B21B6"),
                warn: RGBAColorToken(hex: "#9A3412"),
                error: RGBAColorToken(hex: "#B91C1C")
            )
        case (.swiftEditDefault, .black):
            return SyntaxColorSchemePalette(
                scheme: .swiftEditDefault,
                keyOrTag: RGBAColorToken(hex: "#C4B5FD"),
                attributeOrKeyword: RGBAColorToken(hex: "#A78BFA"),
                string: RGBAColorToken(hex: "#86EFAC"),
                numberOrTimestamp: RGBAColorToken(hex: "#7DD3FC"),
                commentOrPunctuation: RGBAColorToken(hex: "#A8A29E"),
                linkOrEntity: RGBAColorToken(hex: "#C4B5FD"),
                warn: RGBAColorToken(hex: "#FCD34D"),
                error: RGBAColorToken(hex: "#FCA5A5")
            )
        case (.catppuccin, .light):
            return SyntaxColorSchemePalette(
                scheme: .catppuccin,
                keyOrTag: RGBAColorToken(hex: "#1E66F5"),
                attributeOrKeyword: RGBAColorToken(hex: "#7928CA"),
                string: RGBAColorToken(hex: "#2B7A1F"),
                numberOrTimestamp: RGBAColorToken(hex: "#B45309"),
                commentOrPunctuation: RGBAColorToken(hex: "#5C5F77"),
                linkOrEntity: RGBAColorToken(hex: "#0F766E"),
                warn: RGBAColorToken(hex: "#A16207"),
                error: RGBAColorToken(hex: "#C81E3A")
            )
        case (.catppuccin, .black):
            return SyntaxColorSchemePalette(
                scheme: .catppuccin,
                keyOrTag: RGBAColorToken(hex: "#89B4FA"),
                attributeOrKeyword: RGBAColorToken(hex: "#CBA6F7"),
                string: RGBAColorToken(hex: "#A6E3A1"),
                numberOrTimestamp: RGBAColorToken(hex: "#FAB387"),
                commentOrPunctuation: RGBAColorToken(hex: "#9399B2"),
                linkOrEntity: RGBAColorToken(hex: "#94E2D5"),
                warn: RGBAColorToken(hex: "#F9E2AF"),
                error: RGBAColorToken(hex: "#F38BA8")
            )
        case (.github, .light):
            return SyntaxColorSchemePalette(
                scheme: .github,
                keyOrTag: RGBAColorToken(hex: "#0550AE"),
                attributeOrKeyword: RGBAColorToken(hex: "#6639BA"),
                string: RGBAColorToken(hex: "#0A3069"),
                numberOrTimestamp: RGBAColorToken(hex: "#953800"),
                commentOrPunctuation: RGBAColorToken(hex: "#57606A"),
                linkOrEntity: RGBAColorToken(hex: "#0969DA"),
                warn: RGBAColorToken(hex: "#9A6700"),
                error: RGBAColorToken(hex: "#CF222E")
            )
        case (.github, .black):
            return SyntaxColorSchemePalette(
                scheme: .github,
                keyOrTag: RGBAColorToken(hex: "#79C0FF"),
                attributeOrKeyword: RGBAColorToken(hex: "#D2A8FF"),
                string: RGBAColorToken(hex: "#A5D6FF"),
                numberOrTimestamp: RGBAColorToken(hex: "#FFA657"),
                commentOrPunctuation: RGBAColorToken(hex: "#8B949E"),
                linkOrEntity: RGBAColorToken(hex: "#58A6FF"),
                warn: RGBAColorToken(hex: "#E3B341"),
                error: RGBAColorToken(hex: "#FF7B72")
            )
        case (.tokyoNight, .light):
            return SyntaxColorSchemePalette(
                scheme: .tokyoNight,
                keyOrTag: RGBAColorToken(hex: "#2E58D6"),
                attributeOrKeyword: RGBAColorToken(hex: "#7847BD"),
                string: RGBAColorToken(hex: "#2E6F40"),
                numberOrTimestamp: RGBAColorToken(hex: "#8C5A1E"),
                commentOrPunctuation: RGBAColorToken(hex: "#5A658E"),
                linkOrEntity: RGBAColorToken(hex: "#006A8E"),
                warn: RGBAColorToken(hex: "#8F5E15"),
                error: RGBAColorToken(hex: "#C6284F")
            )
        case (.tokyoNight, .black):
            return SyntaxColorSchemePalette(
                scheme: .tokyoNight,
                keyOrTag: RGBAColorToken(hex: "#7AA2F7"),
                attributeOrKeyword: RGBAColorToken(hex: "#BB9AF7"),
                string: RGBAColorToken(hex: "#9ECE6A"),
                numberOrTimestamp: RGBAColorToken(hex: "#FF9E64"),
                commentOrPunctuation: RGBAColorToken(hex: "#787C99"),
                linkOrEntity: RGBAColorToken(hex: "#7DCFFF"),
                warn: RGBAColorToken(hex: "#E0AF68"),
                error: RGBAColorToken(hex: "#F7768E")
            )
        }
    }

    /// All 8 foreground color tokens for automated WCAG AA contrast verification (`>= 4.5:1`).
    public var allForegroundTokens: [RGBAColorToken] {
        [keyOrTag, attributeOrKeyword, string, numberOrTimestamp, commentOrPunctuation, linkOrEntity, warn, error]
    }
}
