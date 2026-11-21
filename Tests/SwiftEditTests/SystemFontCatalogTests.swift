import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Fixed family list that counts enumerations.
private final class CountingFamilySource: FontFamilySource, @unchecked Sendable {
    let names: [String]
    private(set) var calls = 0
    init(_ names: [String]) { self.names = names }
    func familyNames() -> [String] { calls += 1; return names }
}

@Suite("SystemFontCatalogTests")
@MainActor
struct SystemFontCatalogTests {

    @Test("P5: families are sorted, searchable, enumerated once, with Default and OpenDyslexic pinned")
    func p5SortedSearchablePinned() {
        // GIVEN a source with mixed-case families and a verified OpenDyslexic bundle
        let source = CountingFamilySource(["menlo", "Avenir Next", "Helvetica", "OpenDyslexic"])
        let catalog = SystemFontCatalog(source: source, isOpenDyslexicAvailable: { true })
        // WHEN the catalog is queried twice
        let all = catalog.entries(matching: "").map(\.title)
        let hel = catalog.entries(matching: "HÉL").map(\.title)
        // THEN ordering, filtering, pinning and single enumeration hold; a system family named OpenDyslexic is never listed
        #expect(all == ["Default", "OpenDyslexic", "Avenir Next", "Helvetica", "menlo"])
        #expect(hel == ["Default", "OpenDyslexic", "Helvetica"])
        #expect(source.calls == 1)
        #expect(catalog.entries(matching: "").map(\.choice).prefix(3) == [.default, .openDyslexic, .system(family: "Avenir Next")])
    }

    @Test("N5: no match and an unverified bundle leave only Default")
    func n5NoMatchUnverified() {
        // GIVEN an unverified OpenDyslexic bundle
        let catalog = SystemFontCatalog(source: CountingFamilySource(["Helvetica"]), isOpenDyslexicAvailable: { false })
        // WHEN the query matches nothing
        let result = catalog.entries(matching: "zzz")
        // THEN only Default remains
        #expect(result.map(\.title) == ["Default"])
    }
}
