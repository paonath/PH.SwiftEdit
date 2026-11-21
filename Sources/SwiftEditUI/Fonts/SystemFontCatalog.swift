#if os(macOS)
import AppKit
import SwiftEditCore

/// Installed-family seam so the catalog is testable with a fixed list (`TEST-004`).
protocol FontFamilySource: Sendable {
    func familyNames() -> [String]
    /// `true` when `familyNames()` is already filtered and sorted (skips re-normalization).
    var isNormalized: Bool { get }
}

extension FontFamilySource {
    var isNormalized: Bool { false }
}

/// Production source backed by the prewarmed `SystemFontFamilyCache` (already filtered and sorted).
struct SystemFontFamilySource: FontFamilySource {
    var isNormalized: Bool { true }
    func familyNames() -> [String] { SystemFontFamilyCache.shared.families() }
}

/// One selectable row of the Settings font pickers.
struct FontCatalogEntry: Hashable, Identifiable {
    let title: String
    let choice: FontChoice
    var id: String { choice.storageValue }
}

/// Cached, searchable list of font choices: `Default`, then `OpenDyslexic` (only when the bundle verified), then the
/// installed families sorted case-insensitively (`REQ-005`).
///
/// Installed families named "OpenDyslexic" are never listed, so a system font cannot impersonate the verified bundle.
@MainActor
final class SystemFontCatalog {
    private let source: any FontFamilySource
    private let isOpenDyslexicAvailable: @MainActor () -> Bool
    private lazy var families: [String] = source.isNormalized ? source.familyNames() : Self.normalized(source.familyNames())

    /// Drops families impersonating the bundled OpenDyslexic and sorts case-insensitively.
    nonisolated static func normalized(_ names: [String]) -> [String] {
        names.filter { $0.caseInsensitiveCompare("OpenDyslexic") != .orderedSame }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    init(source: any FontFamilySource = SystemFontFamilySource(), isOpenDyslexicAvailable: @escaping @MainActor () -> Bool) {
        self.source = source
        self.isOpenDyslexicAvailable = isOpenDyslexicAvailable
    }

    /// Pinned entries followed by the families whose names contain `query` (case- and diacritic-insensitive).
    func entries(matching query: String) -> [FontCatalogEntry] {
        var result = [FontCatalogEntry(title: "Default", choice: .default)]
        if isOpenDyslexicAvailable() { result.append(FontCatalogEntry(title: "OpenDyslexic", choice: .openDyslexic)) }
        let needle = query.trimmingCharacters(in: .whitespaces)
        let matching = needle.isEmpty ? families : families.filter { $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        result += matching.map { FontCatalogEntry(title: $0, choice: .system(family: $0)) }
        return result
    }
}
#endif

#if os(macOS)
import CoreText
import os

/// Process-wide, prewarmable list of installed font families (`PERF-017-B2`).
///
/// The first family enumeration costs 30–98 ms; `prewarm()` performs it once off the main actor through the
/// thread-safe CoreText API (`NSFontManager` is not thread-safe), storing the list already filtered (no private
/// `.`-families, no system "OpenDyslexic") and sorted, so opening Settings reads it in microseconds.
final class SystemFontFamilyCache: Sendable {
    static let shared = SystemFontFamilyCache()
    private let storage = OSAllocatedUnfairLock<[String]?>(initialState: nil)

    /// Fills the cache on a background executor; later calls return immediately.
    func prewarm() async {
        guard storage.withLock({ $0 }) == nil else { return }
        let list = await Task.detached(priority: .utility) { Self.enumerate() }.value
        storage.withLock { if $0 == nil { $0 = list } }
    }

    /// Cached families, enumerating synchronously only if `prewarm()` has not completed yet.
    func families() -> [String] {
        if let cached = storage.withLock({ $0 }) { return cached }
        let list = Self.enumerate()
        storage.withLock { if $0 == nil { $0 = list } }
        return list
    }

    static func enumerate() -> [String] {
        let names = (CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? []
        return SystemFontCatalog.normalized(names.filter { !$0.hasPrefix(".") })
    }
}
#endif
