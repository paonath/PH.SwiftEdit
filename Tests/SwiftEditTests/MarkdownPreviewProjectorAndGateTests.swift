import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import SwiftEditCore

@Suite("MarkdownPreviewProjectorAndGateTests")
struct MarkdownPreviewProjectorAndGateTests {

    private static func snapshot(_ text: String) -> DocumentSnapshot { DocumentSession(text: text).snapshot }

    private static func writePNG(width: Int, height: Int, to url: URL) {
        let space = CGColorSpaceCreateDeviceGray()
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let image = ctx.makeImage()!
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    private static func makeWorkspace() -> (root: URL, outside: URL) {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("gfm-gate-\(UUID().uuidString)")
        let root = base.appendingPathComponent("ws")
        let outside = base.appendingPathComponent("outside")
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        return (root.standardizedFileURL.resolvingSymlinksInPath(), outside.standardizedFileURL.resolvingSymlinksInPath())
    }

    @Test("P4: preview on projects heading, table, task, quote, and inert HTML with source lines")
    func p4ProjectionWithSourceLinesAndInertHTML() {
        let text = "# Head\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n- [x] done\n\n> quote\n\n<b>x</b>"
        let doc = MarkdownPreviewProjector.project(snapshot: Self.snapshot(text), showPreview: true)
        #expect(doc != nil)
        let blocks = doc?.blocks ?? []
        #expect(blocks.contains(.heading(level: 1, text: "Head", sourceLine: 1)))
        #expect(blocks.contains(.table(header: ["a", "b"], rows: [["1", "2"]], sourceLine: 3)))
        #expect(blocks.contains(.listItem(text: "done", ordered: false, indent: 0, taskChecked: true, sourceLine: 7)))
        #expect(blocks.contains(.quote(text: "quote", sourceLine: 9)))
        #expect(blocks.contains(.inertHTML(text: "<b>x</b>", sourceLine: 11)))
        #expect(blocks.map(\.sourceLine) == [1, 3, 7, 9, 11])
    }

    @Test("N5: hidden preview performs zero projections and raw HTML is inert text")
    func n5HiddenPreviewAndInertHTML() {
        let text = "<script>x()</script>"
        #expect(MarkdownPreviewProjector.project(snapshot: Self.snapshot(text), showPreview: false) == nil)
        let shown = MarkdownPreviewProjector.project(snapshot: Self.snapshot(text), showPreview: true)
        #expect(shown?.blocks == [.inertHTML(text: "<script>x()</script>", sourceLine: 1)])
        let binary = DocumentSnapshot(id: DocumentID(), revision: BufferRevision(0), text: "# x", encoding: .utf8, lineEnding: .lf, isDegradedPlainText: false, isBinaryReadOnly: true)
        #expect(MarkdownPreviewProjector.project(snapshot: binary, showPreview: true) == nil)
    }

    @Test("P5: in-scope raster image is admitted for downsampling and an https link requires confirmation")
    func p5ImageAdmittedAndLinkConfirmed() {
        let ws = Self.makeWorkspace()
        Self.writePNG(width: 4000, height: 3000, to: ws.root.appendingPathComponent("diagram.png"))
        let gate = PreviewResourceAndLinkGate(fileSystem: LocalFileSystemAdapter(), scopeRoot: ws.root, documentDirectory: ws.root)
        #expect(gate.admitImage(reference: "./diagram.png") == .admitted(url: ws.root.appendingPathComponent("diagram.png"), targetMaxPixel: 2048))
        #expect(PreviewResourceAndLinkGate.decideLink("https://example.com") == .requiresConfirmation(canonicalURI: "https://example.com"))
        #expect(PreviewResourceAndLinkGate.decideLink("mailto:a@b.c") == .requiresConfirmation(canonicalURI: "mailto:a@b.c"))
    }

    @Test("N6: remote, data, traversal, SVG, oversize, symlink escape, and unsafe links are blocked")
    func n6HostileResourcesBlocked() throws {
        let ws = Self.makeWorkspace()
        Self.writePNG(width: 20000, height: 1, to: ws.root.appendingPathComponent("wide.png"))
        Self.writePNG(width: 10, height: 10, to: ws.outside.appendingPathComponent("secret.png"))
        try FileManager.default.createSymbolicLink(at: ws.root.appendingPathComponent("link.png"), withDestinationURL: ws.outside.appendingPathComponent("secret.png"))
        try Data("<svg/>".utf8).write(to: ws.root.appendingPathComponent("x.svg"))
        let gate = PreviewResourceAndLinkGate(fileSystem: LocalFileSystemAdapter(), scopeRoot: ws.root, documentDirectory: ws.root)

        #expect(gate.admitImage(reference: "https://tracker.example/p.png") == .blocked(.remoteOrData))
        #expect(gate.admitImage(reference: "data:image/png;base64,AA") == .blocked(.remoteOrData))
        #expect(gate.admitImage(reference: "../../etc/passwd") == .blocked(.outOfScope))
        #expect(gate.admitImage(reference: "./x.svg") == .blocked(.forbiddenExtension))
        #expect(gate.admitImage(reference: "./wide.png") == .blocked(.tooManyPixels))
        #expect(gate.admitImage(reference: "./link.png") != .admitted(url: ws.root.appendingPathComponent("link.png"), targetMaxPixel: 10))
        if case .admitted = gate.admitImage(reference: "./link.png") { Issue.record("symlink escape admitted") }
        #expect(gate.admitImage(reference: "./wide.png", admittedCount: 64) == .blocked(.tooManyImages))
        #expect(PreviewResourceAndLinkGate.decideLink("javascript:alert(1)") == .blocked)
        #expect(PreviewResourceAndLinkGate.decideLink("file:///etc/hosts") == .blocked)
        #expect(PreviewResourceAndLinkGate.decideLink("data:text/html,x") == .blocked)
    }
}

@Suite("MarkdownPreviewProjectorFenceTests")
struct MarkdownPreviewProjectorFenceTests {
    @Test("P4b: fenced code becomes one code block and following text continues")
    func p4bFencedCode() {
        let doc = MarkdownPreviewProjector.project(snapshot: DocumentSession(text: "```\na\nb\n```\ntail").snapshot, showPreview: true)
        #expect(doc?.blocks == [.code(text: "a\nb", sourceLine: 1), .paragraph(text: "tail", sourceLine: 5)])
    }
}

@Suite("PreviewZeroSocketFitnessTests")
struct PreviewZeroSocketFitnessTests {
    @Test("N6 fitness: the preview path never references AsyncImage, URLSession, or WebKit")
    func previewPathHasNoNetworkOrWebKitReferences() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let files = [
            "Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownPreviewProjector.swift",
            "Sources/SwiftEditUI/Views/MarkdownNativePreviewView.swift"
        ]
        for file in files {
            let source = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            let code = source.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            for token in ["AsyncImage", "URLSession", "import WebKit", "WKWebView", "NWConnection"] {
                #expect(!code.contains(token), "\(file) must not reference \(token)")
            }
        }
    }
}
