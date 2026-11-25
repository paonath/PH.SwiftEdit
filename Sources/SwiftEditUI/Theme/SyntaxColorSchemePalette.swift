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

    private struct PaletteKey: Hashable {
        let scheme: SyntaxColorScheme
        let mode: ResolvedThemeMode
    }

    private struct PaletteHexSpec: Sendable {
        let keyOrTag: String
        let attributeOrKeyword: String
        let string: String
        let numberOrTimestamp: String
        let commentOrPunctuation: String
        let linkOrEntity: String
        let warn: String
        let error: String
    }

    private static let defaultLightSpec = PaletteHexSpec(
        keyOrTag: "#6D28D9",
        attributeOrKeyword: "#7C3AED",
        string: "#15803D",
        numberOrTimestamp: "#0369A1",
        commentOrPunctuation: "#57534E",
        linkOrEntity: "#5B21B6",
        warn: "#9A3412",
        error: "#B91C1C"
    )

    private static let specsByKey: [PaletteKey: PaletteHexSpec] = [
        PaletteKey(scheme: .swiftEditDefault, mode: .light): defaultLightSpec,
        PaletteKey(scheme: .swiftEditDefault, mode: .black): PaletteHexSpec(
            keyOrTag: "#C4B5FD",
            attributeOrKeyword: "#A78BFA",
            string: "#86EFAC",
            numberOrTimestamp: "#7DD3FC",
            commentOrPunctuation: "#A8A29E",
            linkOrEntity: "#C4B5FD",
            warn: "#FCD34D",
            error: "#FCA5A5"
        ),
        PaletteKey(scheme: .catppuccin, mode: .light): PaletteHexSpec(
            keyOrTag: "#1E66F5",
            attributeOrKeyword: "#7928CA",
            string: "#2B7A1F",
            numberOrTimestamp: "#B45309",
            commentOrPunctuation: "#5C5F77",
            linkOrEntity: "#0F766E",
            warn: "#A16207",
            error: "#C81E3A"
        ),
        PaletteKey(scheme: .catppuccin, mode: .black): PaletteHexSpec(
            keyOrTag: "#89B4FA",
            attributeOrKeyword: "#CBA6F7",
            string: "#A6E3A1",
            numberOrTimestamp: "#FAB387",
            commentOrPunctuation: "#9399B2",
            linkOrEntity: "#94E2D5",
            warn: "#F9E2AF",
            error: "#F38BA8"
        ),
        PaletteKey(scheme: .github, mode: .light): PaletteHexSpec(
            keyOrTag: "#0550AE",
            attributeOrKeyword: "#6639BA",
            string: "#0A3069",
            numberOrTimestamp: "#953800",
            commentOrPunctuation: "#57606A",
            linkOrEntity: "#0969DA",
            warn: "#9A6700",
            error: "#CF222E"
        ),
        PaletteKey(scheme: .github, mode: .black): PaletteHexSpec(
            keyOrTag: "#79C0FF",
            attributeOrKeyword: "#D2A8FF",
            string: "#A5D6FF",
            numberOrTimestamp: "#FFA657",
            commentOrPunctuation: "#8B949E",
            linkOrEntity: "#58A6FF",
            warn: "#E3B341",
            error: "#FF7B72"
        ),
        PaletteKey(scheme: .tokyoNight, mode: .light): PaletteHexSpec(
            keyOrTag: "#2E58D6",
            attributeOrKeyword: "#7847BD",
            string: "#2E6F40",
            numberOrTimestamp: "#8C5A1E",
            commentOrPunctuation: "#5A658E",
            linkOrEntity: "#006A8E",
            warn: "#8F5E15",
            error: "#C6284F"
        ),
        PaletteKey(scheme: .tokyoNight, mode: .black): PaletteHexSpec(
            keyOrTag: "#7AA2F7",
            attributeOrKeyword: "#BB9AF7",
            string: "#9ECE6A",
            numberOrTimestamp: "#FF9E64",
            commentOrPunctuation: "#787C99",
            linkOrEntity: "#7DCFFF",
            warn: "#E0AF68",
            error: "#F7768E"
        ),
    ]

    /// Resolves WCAG-AA-calibrated tokens for `scheme` on either `#FFFFFF` (`.light`) or `#000000` (`.black`).
    public static func resolve(scheme: SyntaxColorScheme, mode: ResolvedThemeMode) -> SyntaxColorSchemePalette {
        let spec = specsByKey[PaletteKey(scheme: scheme, mode: mode)] ?? defaultLightSpec
        return SyntaxColorSchemePalette(
            scheme: scheme,
            keyOrTag: RGBAColorToken(hex: spec.keyOrTag),
            attributeOrKeyword: RGBAColorToken(hex: spec.attributeOrKeyword),
            string: RGBAColorToken(hex: spec.string),
            numberOrTimestamp: RGBAColorToken(hex: spec.numberOrTimestamp),
            commentOrPunctuation: RGBAColorToken(hex: spec.commentOrPunctuation),
            linkOrEntity: RGBAColorToken(hex: spec.linkOrEntity),
            warn: RGBAColorToken(hex: spec.warn),
            error: RGBAColorToken(hex: spec.error)
        )
    }

    /// All 8 foreground color tokens for automated WCAG AA contrast verification (`>= 4.5:1`).
    public var allForegroundTokens: [RGBAColorToken] {
        [keyOrTag, attributeOrKeyword, string, numberOrTimestamp, commentOrPunctuation, linkOrEntity, warn, error]
    }
}
