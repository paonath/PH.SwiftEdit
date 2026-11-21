import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("AppTypographyTests", .serialized)
@MainActor
struct AppTypographyTests {

    private static func traits(_ font: NSFont) -> NSFontDescriptor.SymbolicTraits { font.fontDescriptor.symbolicTraits }

    @Test("P4: system family, OpenDyslexic and default resolve with traits and are cached")
    func p4ResolvesChoicesWithTraitsAndCaches() {
        // GIVEN Helvetica Neue for the interface, OpenDyslexic for the editor and a default-only typography
        let typography = AppTypography(interface: .system(family: "Helvetica Neue"), editor: .openDyslexic)
        let defaults = AppTypography(interface: .default, editor: .default)
        // WHEN fonts are resolved at 14 pt regular, bold and italic
        let uiRegular = typography.nsFont(.interface, size: 14)
        let uiBold = typography.nsFont(.interface, size: 14, weight: .bold)
        let uiItalic = typography.nsFont(.interface, size: 14, italic: true)
        let editorBold = typography.nsFont(.editor, size: 14, weight: .bold)
        let defaultEditor = defaults.nsFont(.editor, size: 14)
        let again = typography.nsFont(.interface, size: 14)
        // THEN families, traits, monospacing and cache identity match
        #expect(uiRegular.familyName == "Helvetica Neue")
        #expect(Self.traits(uiBold).contains(.bold))
        #expect(Self.traits(uiItalic).contains(.italic))
        #expect(editorBold.familyName == "OpenDyslexic")
        #expect(Self.traits(editorBold).contains(.bold))
        #expect(defaultEditor.isFixedPitch)
        #expect(again === uiRegular)
    }

    @Test("N4: a missing family falls back to the role default and a missing trait to the regular face")
    func n4MissingFamilyAndTraitFallBack() {
        // GIVEN a non-existent family and Monaco, which ships without an italic face
        let typography = AppTypography(interface: .system(family: "NoSuchFamily 123"), editor: .system(family: "Monaco"))
        // WHEN regular and italic fonts are resolved
        let missing = typography.nsFont(.interface, size: 13)
        let monacoItalic = typography.nsFont(.editor, size: 13, italic: true)
        // THEN the interface uses the system font and the editor keeps Monaco regular
        #expect(missing.familyName == NSFont.systemFont(ofSize: 13).familyName)
        #expect(monacoItalic.familyName == "Monaco")
    }

    @Test("N4b: changing a choice invalidates only that role and resolves the new family")
    func n4bChoiceChangeInvalidatesCache() {
        // GIVEN a typography whose editor font was resolved as Menlo
        let typography = AppTypography(interface: .default, editor: .system(family: "Menlo"))
        let before = typography.nsFont(.editor, size: 12)
        let interfaceBefore = typography.nsFont(.interface, size: 12)
        // WHEN the editor choice changes to Courier New
        typography.setChoice(.system(family: "Courier New"), for: .editor)
        // THEN the editor resolves the new family and the interface cache entry is reused
        #expect(before.familyName == "Menlo")
        #expect(typography.nsFont(.editor, size: 12).familyName == "Courier New")
        #expect(typography.nsFont(.interface, size: 12) === interfaceBefore)
        #expect(typography.choice(for: .editor) == .system(family: "Courier New"))
    }
}
