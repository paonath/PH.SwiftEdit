import AppKit
import Foundation
import Testing
@testable import SwiftEditUI

/// In-memory reader returning real bundle bytes except for overridden or removed files.
private struct OverridingFontReader: FontFileReading {
    var overrides: [String: Data] = [:]
    var missing: Set<String> = []
    func data(at url: URL) throws -> Data {
        let name = url.lastPathComponent
        if missing.contains(name) { throw CocoaError(.fileNoSuchFile) }
        if let data = overrides[name] { return data }
        return try Data(contentsOf: url)
    }
}

/// Registrar spy counting registration attempts without touching CoreText.
private final class SpyRegistrar: FontRegistering, @unchecked Sendable {
    private(set) var registeredURLs: [URL] = []
    func registerForProcess(_ url: URL) -> Bool { registeredURLs.append(url); return true }
}

@Suite("OpenDyslexicBundleTests", .serialized)
@MainActor
struct OpenDyslexicBundleTests {

    @Test("P6: bundled files match pinned digests, register once for the process and resolve by PostScript name")
    func p6VerifiedFilesRegisterOnceAndResolve() throws {
        // GIVEN the real bundled OpenDyslexic directory
        let directory = try #require(OpenDyslexicBundle.defaultDirectory)
        let bundle = OpenDyslexicBundle(directory: directory)
        // WHEN registration runs twice and faces are resolved
        let first = bundle.registerIfNeeded()
        let second = bundle.registerIfNeeded()
        let regular = bundle.font(size: 14, bold: false, italic: false)
        let boldItalic = bundle.font(size: 14, bold: true, italic: true)
        // THEN every pinned file exists, the bundle is available once, and faces carry the OpenDyslexic family
        #expect(Set(OpenDyslexicBundle.pinnedDigests.keys) == ["OpenDyslexic-Regular.otf", "OpenDyslexic-Bold.otf", "OpenDyslexic-Italic.otf", "OpenDyslexic-Bold-Italic.otf", "OFL.txt"])
        #expect(first.isAvailable)
        #expect(second == first)
        #expect(bundle.registrationPasses == 1)
        #expect(regular?.familyName == "OpenDyslexic")
        #expect(boldItalic?.fontDescriptor.symbolicTraits.contains([.bold, .italic]) == true)
    }

    @Test("N6 [Security]: tampered or missing files disable OpenDyslexic without registering anything")
    func n6TamperedOrMissingFailClosed() throws {
        // GIVEN the real directory read through readers that tamper with one file or hide another
        let directory = try #require(OpenDyslexicBundle.defaultDirectory)
        let tamperedRegistrar = SpyRegistrar()
        let missingRegistrar = SpyRegistrar()
        let tampered = OpenDyslexicBundle(directory: directory, reader: OverridingFontReader(overrides: ["OpenDyslexic-Bold.otf": Data("evil".utf8)]), registrar: tamperedRegistrar)
        let missing = OpenDyslexicBundle(directory: directory, reader: OverridingFontReader(missing: ["OFL.txt"]), registrar: missingRegistrar)
        // WHEN registration is attempted
        let tamperedResult = tampered.registerIfNeeded()
        let missingResult = missing.registerIfNeeded()
        // THEN both are unavailable, nothing is registered and no face is resolved
        #expect(!tamperedResult.isAvailable)
        #expect(!missingResult.isAvailable)
        #expect(tamperedRegistrar.registeredURLs.isEmpty)
        #expect(missingRegistrar.registeredURLs.isEmpty)
        #expect(tampered.font(size: 14, bold: false, italic: false) == nil)
    }

    @Test("N6b [Security]: faces are resolved from the registered files, never by looking up a family named OpenDyslexic")
    func n6bShadowFamilyNeverUsed() throws {
        // GIVEN a verified bundle using a spy registrar (so CoreText never sees these files through it)
        let directory = try #require(OpenDyslexicBundle.defaultDirectory)
        let registrar = SpyRegistrar()
        let bundle = OpenDyslexicBundle(directory: directory, registrar: registrar)
        // WHEN it registers and resolves a face
        let availability = bundle.registerIfNeeded()
        let font = bundle.font(size: 12, bold: false, italic: false)
        // THEN the face comes from the bundle file URL descriptor and the registrar received only bundle URLs
        #expect(availability.isAvailable)
        #expect(registrar.registeredURLs.allSatisfy { $0.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL })
        #expect(registrar.registeredURLs.count == 4)
        #expect(font?.fontDescriptor.object(forKey: .name) as? String == bundle.postScriptName(bold: false, italic: false))
    }
}
