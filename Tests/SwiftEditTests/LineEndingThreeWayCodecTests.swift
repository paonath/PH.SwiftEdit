import Foundation
import Testing
@testable import SwiftEditCore

@Suite("LineEndingThreeWayCodecTests")
struct LineEndingThreeWayCodecTests {

    @Test("P1: LF, CRLF, and Classic Mac CR files round-trip byte-exact through DocumentLoader and Cmd+D")
    func p1ThreeWayLineEndingsRoundTripByteExactAndSupportCommandD() throws {
        // GIVEN three UTF-8 files using LF, CRLF, and Classic Mac CR separators in InMemoryFileSystemFake
        let fs = InMemoryFileSystemFake()
        let lfURL = URL(fileURLWithPath: "/workspace/unix.txt")
        let crlfURL = URL(fileURLWithPath: "/workspace/win.txt")
        let crURL = URL(fileURLWithPath: "/workspace/classic-mac.txt")
        fs.seed(url: lfURL, data: Data("alpha\nbeta".utf8))
        fs.seed(url: crlfURL, data: Data("alpha\r\nbeta".utf8))
        fs.seed(url: crURL, data: Data("alpha\rbeta".utf8))
        let loader = DocumentLoader(fileSystem: fs)

        // WHEN loading each file, duplicating line 1 via Cmd+D on CR, editing LF/CRLF, and saving atomically
        var lfSession = try loader.load(from: lfURL)
        var crlfSession = try loader.load(from: crlfURL)
        var crSession = try loader.load(from: crURL)
        try lfSession.applyEdit(replacing: TextRange(location: 0, length: 5), with: "ALPHA")
        try crlfSession.applyEdit(replacing: TextRange(location: 0, length: 5), with: "ALPHA")
        try crSession.duplicateLineOrSelection(selection: TextRange(location: 2, length: 0))
        _ = try loader.save(lfSession, to: lfURL)
        _ = try loader.save(crlfSession, to: crlfURL)
        _ = try loader.save(crSession, to: crURL)

        // THEN detected LineEnding values and persisted wire bytes preserve exact LF, CRLF, and CR separators
        #expect(lfSession.lineEnding == .lf)
        #expect(crlfSession.lineEnding == .crlf)
        #expect(crSession.lineEnding == .cr)
        #expect(fs.storedData(at: lfURL) == Data("ALPHA\nbeta".utf8))
        #expect(fs.storedData(at: crlfURL) == Data("ALPHA\r\nbeta".utf8))
        #expect(fs.storedData(at: crURL) == Data("alpha\ralpha\rbeta".utf8))
    }

    @Test("N1: Scalar line-ending scan never misclassifies CRLF as CR and resolves mixed endings deterministically")
    func n1CRLFNotMisclassifiedAsCRAndMixedEndingsNormalizeWithoutDuplicateBlankLines() {
        // GIVEN pure CRLF, three-way mixed, and CR+LF mixed strings
        let pureCRLF = "x\r\ny\r\nz"
        let threeWayMixed = "a\nb\r\nc\rd"
        let crAndLFMixed = "a\nb\rc"

        // WHEN detecting line endings and normalizing to canonical LF
        let detectedPureCRLF = LineEnding.detect(in: pureCRLF)
        let detectedThreeWay = LineEnding.detect(in: threeWayMixed)
        let detectedCRAndLF = LineEnding.detect(in: crAndLFMixed)
        let normalizedPureCRLF = LineEnding.normalizeToLF(pureCRLF)
        let normalizedThreeWay = LineEnding.normalizeToLF(threeWayMixed)

        // THEN CRLF takes precedence over CR, CR takes precedence over LF, and normalization emits single LF breaks
        #expect(detectedPureCRLF == .crlf)
        #expect(detectedThreeWay == .crlf)
        #expect(detectedCRAndLF == .cr)
        #expect(normalizedPureCRLF == "x\ny\nz")
        #expect(normalizedThreeWay == "a\nb\nc\nd")
    }
}
