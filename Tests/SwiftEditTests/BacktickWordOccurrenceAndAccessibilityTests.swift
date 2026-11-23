import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("BacktickWordOccurrenceAndAccessibilityTests")
struct BacktickWordOccurrenceAndAccessibilityTests {

    @Test("P-BT1: Backtick tokens use light antique parchment yellow with WCAG AAA (>= 7.0:1) text contrast in Light and Black modes")
    func pAntiqueParchmentBacktickContrast() {
        let light = PurpleThemePalette.resolve(appearance: .light, systemPrefersDark: false)
        let black = PurpleThemePalette.resolve(appearance: .black, systemPrefersDark: true)

        #expect(light.backtickInlineBackground.hex == "#F7F0D4")
        #expect(light.backtickMultilineBackground.hex == "#FBF6E2")
        #expect(black.backtickInlineBackground.hex == "#24221C")
        #expect(black.backtickMultilineBackground.hex == "#17150F")

        let lightInlineRatio = light.backtickForeground.contrastRatio(against: light.backtickInlineBackground)
        let lightMultiRatio = light.backtickForeground.contrastRatio(against: light.backtickMultilineBackground)
        let blackInlineRatio = black.backtickForeground.contrastRatio(against: black.backtickInlineBackground)
        let blackMultiRatio = black.backtickForeground.contrastRatio(against: black.backtickMultilineBackground)

        #expect(lightInlineRatio >= 7.0)
        #expect(lightMultiRatio >= 7.0)
        #expect(blackInlineRatio >= 7.0)
        #expect(blackMultiRatio >= 7.0)
    }

    @Test("P-SEL1: Primary purple selection achieves WCAG AAA (>= 7.0:1) contrast and secondary word occurrences keep >= 12:1 canvas text contrast with non-color-only underline")
    func pSelectionAndWordOccurrenceAccessibility() {
        let light = PurpleThemePalette.resolve(appearance: .light, systemPrefersDark: false)
        let black = PurpleThemePalette.resolve(appearance: .black, systemPrefersDark: true)
        let lightHC = PurpleThemePalette.resolve(appearance: .light, systemPrefersDark: false, increasedContrast: true)

        // Primary selection contrast (text on selection AND selection against canvas)
        #expect(light.selectionForeground.contrastRatio(against: light.selectionBackground) >= 7.0)
        #expect(light.selectionBackground.contrastRatio(against: light.editorCanvasBackground) >= 7.0)
        #expect(black.selectionForeground.contrastRatio(against: black.selectionBackground) >= 7.0)
        #expect(black.selectionBackground.contrastRatio(against: black.editorCanvasBackground) >= 7.0)

        // Secondary occurrence contrast: clearly softer than primary, crisp text readability
        #expect(light.editorCanvasText.contrastRatio(against: light.wordOccurrenceBackground) >= 12.0)
        #expect(black.editorCanvasText.contrastRatio(against: black.wordOccurrenceBackground) >= 12.0)
        #expect(light.wordOccurrenceBackground.hex != light.selectionBackground.hex)
        #expect(black.wordOccurrenceBackground.hex != black.selectionBackground.hex)

        // High-contrast mode strengthens the non-color-only underline cue
        #expect(lightHC.wordOccurrenceUnderline.alpha > light.wordOccurrenceUnderline.alpha)
    }

    @Test("P-OCC1: WordOccurrenceScanner finds all other whole-word instances (ASCII + accented Unicode) and excludes primary selection and substrings")
    func pWordOccurrenceWholeWordMatching() {
        let text = "alpha beta alpha_2 alpha gamma alpha\ncittà nella città e cittadina"
        let snap = DocumentSession(text: text).snapshot

        // Double-clicking first "alpha" (0..<5) finds the 2 other whole-word "alpha"s, NOT "alpha_2" and NOT 0..<5 itself
        let firstAlpha = TextRange(location: 0, length: 5)
        let alphaOccurrences = WordOccurrenceScanner.scan(selection: firstAlpha, in: snap)
        #expect(alphaOccurrences.count == 2)
        #expect(!alphaOccurrences.contains(firstAlpha))
        #expect(alphaOccurrences == [TextRange(location: 19, length: 5), TextRange(location: 31, length: 5)])

        // Unicode accented whole word "città" matches the other "città" but not "cittadina"
        let ns = text as NSString
        let firstCittaRange = ns.range(of: "città")
        let cittaSel = TextRange(location: firstCittaRange.location, length: firstCittaRange.length)
        let cittaOccurrences = WordOccurrenceScanner.scan(selection: cittaSel, in: snap)
        #expect(cittaOccurrences.count == 1)
        #expect(!cittaOccurrences.contains(cittaSel))

        // Unicode punctuation boundaries (“word”, —word) still count as whole-word boundaries for ASCII words
        let punctText = "hello “hello” —hello— helloworld"
        let punctSnap = DocumentSession(text: punctText).snapshot
        let punctOccurrences = WordOccurrenceScanner.scan(selection: TextRange(location: 0, length: 5), in: punctSnap)
        #expect(punctOccurrences.count == 2)
    }

    @Test("P-OCC3: Partial-word and symbol character groups highlight case-sensitive literal occurrences (REQ-020-05)")
    func pLiteralCharacterGroupOccurrences() {
        let snap = DocumentSession(text: "a ab abc ab cd AB x->y z->w").snapshot
        // Partial word "ab" inside "abc" matches every literal "ab" except itself, never the uppercase "AB"
        let partial = WordOccurrenceScanner.scan(selection: TextRange(location: 5, length: 2), in: snap)
        #expect(partial == [TextRange(location: 2, length: 2), TextRange(location: 9, length: 2)])
        // Symbol group "->" matches the other arrow
        let arrow = WordOccurrenceScanner.scan(selection: TextRange(location: 19, length: 2), in: snap)
        #expect(arrow == [TextRange(location: 24, length: 2)])
        // Group containing an inner space ("ab c") still matches literally
        let spaced = WordOccurrenceScanner.scan(selection: TextRange(location: 7, length: 4), in: DocumentSession(text: "x ab c ab cd").snapshot)
        #expect(spaced == [TextRange(location: 2, length: 4)])
    }

    @Test("N-OCC1: WordOccurrenceScanner ignores single-char, whitespace-only, multi-line, and binary selections")
    func nWordOccurrenceGuards() {
        let snap = DocumentSession(text: "a ab abc ab cd").snapshot
        // Single char
        #expect(WordOccurrenceScanner.scan(selection: TextRange(location: 0, length: 1), in: snap).isEmpty)
        // Whitespace only
        #expect(WordOccurrenceScanner.scan(selection: TextRange(location: 1, length: 1), in: DocumentSession(text: "a  b  c").snapshot).isEmpty)
        #expect(WordOccurrenceScanner.scan(selection: TextRange(location: 1, length: 2), in: DocumentSession(text: "a  b  c").snapshot).isEmpty)
        // Multi-line selection
        #expect(WordOccurrenceScanner.scan(selection: TextRange(location: 0, length: 4), in: DocumentSession(text: "ab\ncd ab\ncd").snapshot).isEmpty)

        let binary = DocumentSnapshot(
            id: DocumentID(),
            revision: BufferRevision(1),
            text: "alpha alpha",
            encoding: .utf8,
            lineEnding: .lf,
            isDegradedPlainText: false,
            isBinaryReadOnly: true
        )
        #expect(WordOccurrenceScanner.scan(selection: TextRange(location: 0, length: 5), in: binary).isEmpty)
    }
}
