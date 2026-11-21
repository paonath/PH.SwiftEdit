import Foundation
import Testing
@testable import SwiftEditCore

struct CodecRoundTripCase: Sendable, CustomTestStringConvertible {
    let encoding: TextEncoding
    let lineEnding: LineEnding

    var testDescription: String {
        "\(encoding.rawValue)-\(lineEnding == .crlf ? "CRLF" : "LF")"
    }
}

@Suite("DocumentCodecAndLoaderTests")
struct DocumentCodecAndLoaderTests {

    static let roundTripCases: [CodecRoundTripCase] = [
        CodecRoundTripCase(encoding: .utf8, lineEnding: .lf),
        CodecRoundTripCase(encoding: .utf8, lineEnding: .crlf),
        CodecRoundTripCase(encoding: .utf8WithBOM, lineEnding: .lf),
        CodecRoundTripCase(encoding: .utf8WithBOM, lineEnding: .crlf),
        CodecRoundTripCase(encoding: .utf16LEWithBOM, lineEnding: .lf),
        CodecRoundTripCase(encoding: .utf16LEWithBOM, lineEnding: .crlf),
        CodecRoundTripCase(encoding: .utf16BEWithBOM, lineEnding: .lf),
        CodecRoundTripCase(encoding: .utf16BEWithBOM, lineEnding: .crlf),
    ]

    @Test("P2: DocumentCodec and DocumentLoader preserve BOM, encoding, and LF/CRLF across atomic round-trip", arguments: roundTripCases)
    func p2EncodingAndLineEndingRoundTrip(testCase: CodecRoundTripCase) throws {
        // GIVEN a multi-line text with Unicode characters encoded in the target BOM and line ending
        let fs = InMemoryFileSystemFake()
        let loader = DocumentLoader(fileSystem: fs)
        let fileURL = URL(fileURLWithPath: "/workspace/notes.md")
        let sourceLines = "# PH.SwiftEdit 🪶\(testCase.lineEnding.rawValue)Second line {balanced}"
        let originalBytes = try DocumentCodec.encode(
            sourceLines,
            encoding: testCase.encoding,
            lineEnding: testCase.lineEnding
        )
        fs.seed(url: fileURL, data: originalBytes)

        // WHEN loading the file and saving it back atomically
        let loaded = try loader.load(from: fileURL)
        let savedSession = try loader.save(loaded, to: fileURL)
        let persistedBytes = try #require(fs.storedData(at: fileURL))

        // THEN encoding, BOM prefix, line ending, text content, and clean state are preserved identically
        #expect(loaded.encoding == testCase.encoding)
        #expect(loaded.lineEnding == testCase.lineEnding)
        #expect(loaded.text == "# PH.SwiftEdit 🪶\nSecond line {balanced}")
        #expect(loaded.isDegradedPlainText == false)
        #expect(savedSession.isDirty == false)
        #expect(persistedBytes == originalBytes)
    }

    @Test("P2: Files between 10 MiB and 64 MiB activate degraded plain-text mode")
    func p2LargeFileBetween10And64MiBActivatesDegradedMode() throws {
        // GIVEN a valid UTF-8 file reporting a 12 MiB byte size
        let fs = InMemoryFileSystemFake()
        let loader = DocumentLoader(fileSystem: fs)
        let fileURL = URL(fileURLWithPath: "/workspace/large.log")
        let sampleBytes = Data("2026-11-17 INFO Fast plain-text log\n".utf8)
        let twelveMiB: UInt64 = 12 * 1024 * 1024
        fs.seed(url: fileURL, data: sampleBytes, virtualByteSize: twelveMiB)

        // WHEN loading the file via DocumentLoader
        let session = try loader.load(from: fileURL)

        // THEN plain-text degraded mode is enabled without throwing fileTooLarge
        #expect(session.isDegradedPlainText == true)
        #expect(session.isBinaryReadOnly == false)
    }

    @Test("N2: Files exceeding 64 MiB fail pre-allocation with DomainError.fileTooLarge")
    func n2OversizedFileAbove64MiBFailsPreAllocation() {
        // GIVEN an inbound file whose metadata reports 64 MiB + 1 byte
        let fs = InMemoryFileSystemFake()
        let loader = DocumentLoader(fileSystem: fs)
        let fileURL = URL(fileURLWithPath: "/workspace/huge.dump")
        let overLimit: UInt64 = DocumentLoader.maxAllowedFileBytes + 1
        fs.seed(url: fileURL, data: Data("stub".utf8), virtualByteSize: overLimit)

        // WHEN / THEN attempting to load throws DomainError.fileTooLarge(byteCount:)
        #expect(throws: DomainError.fileTooLarge(byteCount: overLimit)) {
            _ = try loader.load(from: fileURL)
        }
    }

    @Test("N2: Malformed non-UTF-8 byte sequence without valid UTF-16 BOM throws DomainError.unsupportedEncoding")
    func n2MalformedByteStreamThrowsUnsupportedEncoding() {
        // GIVEN an invalid UTF-8 byte sequence [0xC3, 0x28] with no BOM
        let malformed = Data([0xC3, 0x28, 0xFF])

        // WHEN / THEN decoding fails closed with DomainError.unsupportedEncoding
        #expect(throws: DomainError.unsupportedEncoding) {
            _ = try DocumentCodec.decode(malformed)
        }
    }

    @Test("P2: LocalFileSystemAdapter writes atomically and loads confined UTF-8 CRLF files within workspace scope")
    func p2LocalFileSystemAdapterConfinedAtomicRoundTrip() throws {
        // GIVEN an isolated workspace directory inside .tmp/test-results
        let sandbox = try TempSandboxFactory.makeSandboxPair(name: "p2-local-fs")
        defer { try? FileManager.default.removeItem(at: sandbox.root) }
        let fileURL = sandbox.scope.appendingPathComponent("note.md")
        let loader = DocumentLoader(fileSystem: LocalFileSystemAdapter())
        let initial = DocumentSession(
            fileURL: fileURL,
            text: "Line 1\nLine 2",
            encoding: .utf8WithBOM,
            lineEnding: .crlf,
            isDirty: true
        )

        // WHEN saving atomically and reloading through LocalFileSystemAdapter
        let saved = try loader.save(initial, to: fileURL, withinScope: sandbox.scope)
        let reloaded = try loader.load(from: fileURL, withinScope: sandbox.scope)

        // THEN BOM, CRLF, clean flag, and content round-trip accurately within scope
        #expect(saved.isDirty == false)
        #expect(reloaded.encoding == .utf8WithBOM)
        #expect(reloaded.lineEnding == .crlf)
        #expect(reloaded.text == "Line 1\nLine 2")
    }
}
