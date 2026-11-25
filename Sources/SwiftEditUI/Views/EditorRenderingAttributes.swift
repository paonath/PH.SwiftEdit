import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Editor font set cached once per zoom level so the rendering validator never creates fonts per fragment (`UI-012`).
struct EditorRenderingFonts {
    let regular: NSFont
    let bold: NSFont
    let italic: NSFont
    /// YAML keys use a lighter (not ultra-light) weight to read as secondary while staying legible at `50%` zoom (`REQ-010`).
    let yamlKey: NSFont

    /// Editor faces resolved through `AppTypography` (`REQ-008`); the YAML key face uses a lighter weight (`REQ-010`).
    @MainActor
    init(fontSizePoints: Double, typography: AppTypography) {
        let size = CGFloat(fontSizePoints)
        regular = typography.nsFont(.editor, size: size)
        bold = typography.nsFont(.editor, size: size, weight: .bold)
        italic = typography.nsFont(.editor, size: size, italic: true)
        yamlKey = typography.nsFont(.editor, size: size, weight: .light)
    }

    /// Default-choice faces (monospaced system font).
    @MainActor
    init(fontSizePoints: Double) {
        self.init(fontSizePoints: fontSizePoints, typography: AppTypography.fallback)
    }
}

/// Pre-built log syntax attribute entries grouped out of `EditorRenderingAttributeTable` (`REQ-004`).
struct EditorLogAttributeEntries {
    typealias Entries = [(key: NSAttributedString.Key, value: Any)]
    let trace: Entries
    let debug: Entries
    let info: Entries
    let warn: Entries
    let error: Entries
    let critical: Entries
    let timestamp: Entries
    let guid: Entries
    let string: Entries
    let exception: Entries
}

/// Cached `NSColor`s for non-mutating viewport highlights grouped out of `EditorRenderingAttributeTable` (`REQ-004`).
struct EditorViewportHighlightColors {
    let backtickForeground: NSColor
    let backtickInlineBackground: NSColor
    let backtickMultilineBackground: NSColor
    let primarySelectionBackground: NSColor
    let primarySelectionForeground: NSColor
    let wordOccurrenceBackground: NSColor
    let wordOccurrenceUnderline: NSColor
    let nestedBracketColors: [NSColor]
    let activeBracketHighlight: NSColor
    let lintWarnColor: NSColor
    let lintWarnBackground: NSColor
    let lintErrorColor: NSColor
    let lintErrorBackground: NSColor
    let unbalancedBracketForeground: NSColor
    let unbalancedBracketBackground: NSColor
}

/// Pre-built HTML and semantic JSON/scheme attribute entries grouped out of `EditorRenderingAttributeTable` (`UI-002`, `UI-009`).
struct EditorSemanticSyntaxEntries {
    typealias Entries = [(key: NSAttributedString.Key, value: Any)]
    let heading: Entries
    let htmlTag: Entries
    let htmlAttribute: Entries
    let htmlString: Entries
    let htmlComment: Entries
    let htmlEntity: Entries
    let htmlDoctype: Entries
    let jsonKey: Entries
    let jsonString: Entries
    let jsonNumber: Entries
    let jsonLiteral: Entries
    let jsonPunctuation: Entries
}

/// Pre-built per-`(palette, fonts)` attribute cache so `renderingAttributesValidator` allocates zero `NSColor`s or arrays per span.
@MainActor
struct EditorRenderingAttributeTable {
    typealias Entries = [(key: NSAttributedString.Key, value: Any)]

    let bold: Entries
    let italic: Entries
    let strikethrough: Entries
    let code: Entries
    let link: Entries
    let inlineHTML: Entries
    let secondary: Entries
    let yamlKey: Entries
    let logEntries: EditorLogAttributeEntries
    let semanticEntries: EditorSemanticSyntaxEntries
    let highlights: EditorViewportHighlightColors

    init(palette: PurpleThemePalette, fonts: EditorRenderingFonts) {
        let sc = palette.syntaxColors
        let useScheme = sc.scheme != .swiftEditDefault
        bold = [(.font, fonts.bold)]
        italic = [(.font, fonts.italic)]
        strikethrough = [(.strikethroughStyle, NSUnderlineStyle.single.rawValue)]
        let inlineBg = palette.backtickInlineBackground.nsColor
        let backtickFg = useScheme ? sc.string.nsColor : palette.backtickForeground.nsColor
        code = [(.backgroundColor, inlineBg), (.foregroundColor, backtickFg)]
        let linkColor = useScheme ? sc.linkOrEntity.nsColor : palette.linkForeground.nsColor
        link = [(.underlineStyle, NSUnderlineStyle.single.rawValue), (.foregroundColor, linkColor)]
        inlineHTML = [(.foregroundColor, useScheme ? sc.keyOrTag.nsColor : palette.inertHTMLWarningForeground.nsColor)]
        secondary = [(.foregroundColor, useScheme ? sc.commentOrPunctuation.nsColor : palette.secondaryForeground.nsColor)]
        yamlKey = [(.foregroundColor, useScheme ? sc.keyOrTag.nsColor : palette.yamlKeyForeground.nsColor), (.font, fonts.yamlKey)]
        semanticEntries = EditorSemanticSyntaxEntries(
            heading: useScheme ? [(.font, fonts.bold), (.foregroundColor, sc.keyOrTag.nsColor)] : [(.font, fonts.bold)],
            htmlTag: [(.foregroundColor, sc.keyOrTag.nsColor)],
            htmlAttribute: [(.foregroundColor, sc.attributeOrKeyword.nsColor)],
            htmlString: [(.foregroundColor, sc.string.nsColor)],
            htmlComment: [(.foregroundColor, sc.commentOrPunctuation.nsColor), (.font, fonts.italic)],
            htmlEntity: [(.foregroundColor, sc.linkOrEntity.nsColor)],
            htmlDoctype: [(.foregroundColor, sc.attributeOrKeyword.nsColor), (.font, fonts.bold)],
            jsonKey: [(.foregroundColor, sc.keyOrTag.nsColor), (.font, fonts.yamlKey)],
            jsonString: [(.foregroundColor, sc.string.nsColor)],
            jsonNumber: [(.foregroundColor, sc.numberOrTimestamp.nsColor)],
            jsonLiteral: [(.foregroundColor, sc.attributeOrKeyword.nsColor)],
            jsonPunctuation: [(.foregroundColor, sc.commentOrPunctuation.nsColor)]
        )
        logEntries = EditorLogAttributeEntries(
            trace: [(.foregroundColor, useScheme ? sc.commentOrPunctuation.nsColor : palette.logTraceForeground.nsColor)],
            debug: [(.foregroundColor, useScheme ? sc.linkOrEntity.nsColor : palette.logDebugForeground.nsColor)],
            info: [(.foregroundColor, useScheme ? sc.string.nsColor : palette.logInfoForeground.nsColor)],
            warn: [(.foregroundColor, useScheme ? sc.warn.nsColor : palette.logWarnForeground.nsColor), (.font, fonts.bold)],
            error: [(.foregroundColor, useScheme ? sc.error.nsColor : palette.logErrorForeground.nsColor), (.font, fonts.bold)],
            critical: [
                (.foregroundColor, palette.logCriticalForeground.nsColor),
                (.backgroundColor, palette.logCriticalBackground.nsColor),
                (.font, fonts.bold),
            ],
            timestamp: [(.foregroundColor, useScheme ? sc.numberOrTimestamp.nsColor : palette.logTimestampForeground.nsColor)],
            guid: [(.foregroundColor, useScheme ? sc.linkOrEntity.nsColor : palette.logGuidForeground.nsColor)],
            string: [(.foregroundColor, useScheme ? sc.string.nsColor : palette.logStringForeground.nsColor)],
            exception: [(.foregroundColor, useScheme ? sc.error.nsColor : palette.logExceptionForeground.nsColor), (.font, fonts.italic)]
        )

        let warnColor = palette.bidiWarningForeground.nsColor
        let errColor = palette.unbalancedBracketHighlight.nsColor
        highlights = EditorViewportHighlightColors(
            backtickForeground: backtickFg,
            backtickInlineBackground: inlineBg,
            backtickMultilineBackground: palette.backtickMultilineBackground.nsColor,
            primarySelectionBackground: palette.selectionBackground.nsColor,
            primarySelectionForeground: palette.selectionForeground.nsColor,
            wordOccurrenceBackground: palette.wordOccurrenceBackground.nsColor,
            wordOccurrenceUnderline: palette.wordOccurrenceUnderline.nsColor,
            nestedBracketColors: palette.nestedBracketPalette.isEmpty
                ? [palette.primaryAccent.nsColor]
                : palette.nestedBracketPalette.map(\.nsColor),
            activeBracketHighlight: palette.activeBracketHighlight.nsColor,
            lintWarnColor: warnColor,
            lintWarnBackground: warnColor.withAlphaComponent(0.18),
            lintErrorColor: errColor,
            lintErrorBackground: errColor.withAlphaComponent(0.24),
            unbalancedBracketForeground: errColor,
            unbalancedBracketBackground: palette.unbalancedBracketBackground.nsColor
        )
    }
}

extension EditorRenderingAttributeTable {
    var backtickForeground: NSColor { highlights.backtickForeground }
    var backtickInlineBackground: NSColor { highlights.backtickInlineBackground }
    var backtickMultilineBackground: NSColor { highlights.backtickMultilineBackground }
    var primarySelectionBackground: NSColor { highlights.primarySelectionBackground }
    var primarySelectionForeground: NSColor { highlights.primarySelectionForeground }
    var wordOccurrenceBackground: NSColor { highlights.wordOccurrenceBackground }
    var wordOccurrenceUnderline: NSColor { highlights.wordOccurrenceUnderline }
    var nestedBracketColors: [NSColor] { highlights.nestedBracketColors }
    var activeBracketHighlight: NSColor { highlights.activeBracketHighlight }
    var lintWarnColor: NSColor { highlights.lintWarnColor }
    var lintWarnBackground: NSColor { highlights.lintWarnBackground }
    var lintErrorColor: NSColor { highlights.lintErrorColor }
    var lintErrorBackground: NSColor { highlights.lintErrorBackground }
    var unbalancedBracketForeground: NSColor { highlights.unbalancedBracketForeground }
    var unbalancedBracketBackground: NSColor { highlights.unbalancedBracketBackground }

    func attributes(for kind: MarkdownSyntaxKind) -> Entries {
        if let logResult = lookupLogEntries(for: kind) { return logResult }
        if let semanticResult = lookupSemanticEntries(for: kind) { return semanticResult }
        switch kind {
        case .bold: return bold
        case .italic: return italic
        case .strikethrough: return strikethrough
        case .inlineCode, .codeBlock: return code
        case .link, .image: return link
        case .inlineHTML: return inlineHTML
        case .task, .blockquote, .tableRow, .thematicBreak, .yamlPunctuation, .yamlComment: return secondary
        case .yamlKey: return yamlKey
        default: return []
        }
    }
}

extension EditorRenderingAttributeTable {
    private func lookupSemanticEntries(for kind: MarkdownSyntaxKind) -> Entries? {
        switch kind {
        case .heading: return semanticEntries.heading
        case .htmlTag: return semanticEntries.htmlTag
        case .htmlAttribute: return semanticEntries.htmlAttribute
        case .htmlString: return semanticEntries.htmlString
        case .htmlComment: return semanticEntries.htmlComment
        case .htmlEntity: return semanticEntries.htmlEntity
        case .htmlDoctype: return semanticEntries.htmlDoctype
        case .jsonKey: return semanticEntries.jsonKey
        case .jsonString: return semanticEntries.jsonString
        case .jsonNumber: return semanticEntries.jsonNumber
        case .jsonLiteral: return semanticEntries.jsonLiteral
        case .jsonPunctuation: return semanticEntries.jsonPunctuation
        default: return nil
        }
    }

    private func lookupLogEntries(for kind: MarkdownSyntaxKind) -> Entries? {
        switch kind {
        case .logLevel(let level): return entriesForLogLevel(level)
        case .logTimestamp: return logEntries.timestamp
        case .logGuid: return logEntries.guid
        case .logString: return logEntries.string
        case .logException: return logEntries.exception
        default: return nil
        }
    }

    private func entriesForLogLevel(_ level: LogLevel) -> Entries {
        switch level {
        case .trace: return logEntries.trace
        case .debug: return logEntries.debug
        case .info: return logEntries.info
        case .warn: return logEntries.warn
        case .error: return logEntries.error
        case .critical: return logEntries.critical
        }
    }
}

/// Single source of truth mapping every `MarkdownSyntaxKind` (GFM and YAML) to non-mutating TextKit 2 rendering attributes.
///
/// Prose and YAML values receive no foreground attribute so they keep the `#FFFFFF`/`#000000` canvas text (`21:1`, `UI-002`).
enum EditorRenderingAttributes {
    @MainActor
    static func attributes(for kind: MarkdownSyntaxKind, palette: PurpleThemePalette, fonts: EditorRenderingFonts) -> [(key: NSAttributedString.Key, value: Any)] {
        EditorRenderingAttributeTable(palette: palette, fonts: fonts).attributes(for: kind)
    }
}
#endif
