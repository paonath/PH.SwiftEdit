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
    let highlights: EditorViewportHighlightColors

    init(palette: PurpleThemePalette, fonts: EditorRenderingFonts) {
        bold = [(.font, fonts.bold)]
        italic = [(.font, fonts.italic)]
        strikethrough = [(.strikethroughStyle, NSUnderlineStyle.single.rawValue)]
        let inlineBg = palette.backtickInlineBackground.nsColor
        let backtickFg = palette.backtickForeground.nsColor
        code = [(.backgroundColor, inlineBg), (.foregroundColor, backtickFg)]
        link = [(.underlineStyle, NSUnderlineStyle.single.rawValue), (.foregroundColor, palette.linkForeground.nsColor)]
        inlineHTML = [(.foregroundColor, palette.inertHTMLWarningForeground.nsColor)]
        secondary = [(.foregroundColor, palette.secondaryForeground.nsColor)]
        yamlKey = [(.foregroundColor, palette.yamlKeyForeground.nsColor), (.font, fonts.yamlKey)]
        logEntries = EditorLogAttributeEntries(
            trace: [(.foregroundColor, palette.logTraceForeground.nsColor)],
            debug: [(.foregroundColor, palette.logDebugForeground.nsColor)],
            info: [(.foregroundColor, palette.logInfoForeground.nsColor)],
            warn: [(.foregroundColor, palette.logWarnForeground.nsColor), (.font, fonts.bold)],
            error: [(.foregroundColor, palette.logErrorForeground.nsColor), (.font, fonts.bold)],
            critical: [
                (.foregroundColor, palette.logCriticalForeground.nsColor),
                (.backgroundColor, palette.logCriticalBackground.nsColor),
                (.font, fonts.bold),
            ],
            timestamp: [(.foregroundColor, palette.logTimestampForeground.nsColor)],
            guid: [(.foregroundColor, palette.logGuidForeground.nsColor)],
            string: [(.foregroundColor, palette.logStringForeground.nsColor)],
            exception: [(.foregroundColor, palette.logExceptionForeground.nsColor), (.font, fonts.italic)]
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
        switch kind {
        case .heading, .bold: return bold
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
    static func attributes(for kind: MarkdownSyntaxKind, palette: PurpleThemePalette, fonts: EditorRenderingFonts) -> [(key: NSAttributedString.Key, value: Any)] {
        if let logAttrs = logSyntaxAttributes(for: kind, palette: palette, fonts: fonts) { return logAttrs }
        switch kind {
        case .heading, .bold:
            return [(.font, fonts.bold)]
        case .italic:
            return [(.font, fonts.italic)]
        case .strikethrough:
            return [(.strikethroughStyle, NSUnderlineStyle.single.rawValue)]
        case .inlineCode, .codeBlock:
            return [(.backgroundColor, palette.backtickInlineBackground.nsColor), (.foregroundColor, palette.backtickForeground.nsColor)]
        case .link, .image:
            return [(.underlineStyle, NSUnderlineStyle.single.rawValue), (.foregroundColor, palette.linkForeground.nsColor)]
        case .inlineHTML:
            return [(.foregroundColor, palette.inertHTMLWarningForeground.nsColor)]
        case .task, .blockquote, .tableRow, .thematicBreak, .yamlPunctuation, .yamlComment:
            return [(.foregroundColor, palette.secondaryForeground.nsColor)]
        case .yamlKey:
            return [(.foregroundColor, palette.yamlKeyForeground.nsColor), (.font, fonts.yamlKey)]
        default:
            return []
        }
    }

    private static func logSyntaxAttributes(
        for kind: MarkdownSyntaxKind,
        palette: PurpleThemePalette,
        fonts: EditorRenderingFonts
    ) -> [(key: NSAttributedString.Key, value: Any)]? {
        switch kind {
        case .logLevel(let level): return logLevelStyleAttributes(level, palette: palette, fonts: fonts)
        case .logTimestamp: return [(.foregroundColor, palette.logTimestampForeground.nsColor)]
        case .logGuid: return [(.foregroundColor, palette.logGuidForeground.nsColor)]
        case .logString: return [(.foregroundColor, palette.logStringForeground.nsColor)]
        case .logException: return [(.foregroundColor, palette.logExceptionForeground.nsColor), (.font, fonts.italic)]
        default: return nil
        }
    }

    private static func logLevelStyleAttributes(
        _ level: LogLevel,
        palette: PurpleThemePalette,
        fonts: EditorRenderingFonts
    ) -> [(key: NSAttributedString.Key, value: Any)] {
        switch level {
        case .trace: return [(.foregroundColor, palette.logTraceForeground.nsColor)]
        case .debug: return [(.foregroundColor, palette.logDebugForeground.nsColor)]
        case .info: return [(.foregroundColor, palette.logInfoForeground.nsColor)]
        case .warn: return [(.foregroundColor, palette.logWarnForeground.nsColor), (.font, fonts.bold)]
        case .error: return [(.foregroundColor, palette.logErrorForeground.nsColor), (.font, fonts.bold)]
        case .critical:
            return [(.foregroundColor, palette.logCriticalForeground.nsColor), (.backgroundColor, palette.logCriticalBackground.nsColor), (.font, fonts.bold)]
        }
    }
}
#endif
