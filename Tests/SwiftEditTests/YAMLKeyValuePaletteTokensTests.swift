import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("YAMLKeyValuePaletteTokensTests")
@MainActor
struct YAMLKeyValuePaletteTokensTests {

    private static func weight(_ font: NSFont) -> Double {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any]
        return (traits?[.weight] as? Double) ?? 0
    }

    @Test("P10: yamlKeyForeground meets 4.5:1 on the Light and Black canvas and keys use a lighter weight")
    func p10KeyTokenContrastAndLighterWeight() {
        // GIVEN the Light and Black palettes and the editor font set at 13 pt
        let light = PurpleThemePalette.resolve(appearance: .light, systemPrefersDark: false)
        let black = PurpleThemePalette.resolve(appearance: .black, systemPrefersDark: true)
        let fonts = EditorRenderingFonts(fontSizePoints: 13)
        // WHEN contrast and weights are measured
        let lightRatio = light.yamlKeyForeground.contrastRatio(against: light.editorCanvasBackground)
        let blackRatio = black.yamlKeyForeground.contrastRatio(against: black.editorCanvasBackground)
        // THEN both ratios are at least 4.5:1, the tokens are the specified greys, and the key font is lighter than regular
        #expect(lightRatio >= 4.5)
        #expect(blackRatio >= 4.5)
        #expect(light.yamlKeyForeground.hex == "#6B7280")
        #expect(black.yamlKeyForeground.hex == "#9CA3AF")
        #expect(Self.weight(fonts.yamlKey) < Self.weight(fonts.regular))
    }

    @Test("N10: YAML values are never tinted while keys, punctuation and comments are")
    func n10ValuesNeverTinted() {
        // GIVEN the Light palette and the font set
        let palette = PurpleThemePalette.resolve(appearance: .light, systemPrefersDark: false)
        let fonts = EditorRenderingFonts(fontSizePoints: 13)
        // WHEN rendering attributes are derived for each YAML kind
        let value = EditorRenderingAttributes.attributes(for: .yamlValue, palette: palette, fonts: fonts)
        let key = EditorRenderingAttributes.attributes(for: .yamlKey, palette: palette, fonts: fonts)
        let comment = EditorRenderingAttributes.attributes(for: .yamlComment, palette: palette, fonts: fonts)
        // THEN values get no attribute (canvas text 21:1) and keys get the grey token plus the lighter font
        #expect(value.isEmpty)
        #expect(key.map(\.key).contains(.foregroundColor))
        #expect(key.map(\.key).contains(.font))
        #expect(comment.map(\.key) == [.foregroundColor])
    }

    @Test("N10b: switching appearance keeps a YAML buffer and its revision intact")
    func n10bAppearanceSwitchKeepsBuffer() throws {
        // GIVEN an open config.yml with an unsaved edit
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("config.yml", "a: 1\n")])
        defer { try? FileManager.default.removeItem(at: dir) }
        model.handleEditorTextChanged("a: 2\n")
        let before = try #require(model.activeDocumentSession)
        // WHEN the appearance switches from Light to Black
        model.appearanceMode = .black
        let after = try #require(model.activeDocumentSession)
        // THEN text and revision are unchanged and the tab is still YAML
        #expect(after.text == before.text)
        #expect(after.revision == before.revision)
        #expect(model.activeDocumentLanguage == .yaml)
    }
}
