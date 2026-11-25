import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

#if os(macOS)
import AppKit
import SwiftUI

@Suite("Unit 2: Zoom-Scaled Preview, Frontmatter Card, Top-Right Code Copy & Native Diagrams (REQ-003, REQ-004)")
struct PreviewZoomCopyAndNativeDiagramsTests {

    @Test("P3: Markdown preview scales linearly across 50%..300% zoom, projects YAML frontmatter card, and copies fenced code via top-right button")
    @MainActor
    func p3PreviewZoomScalingFrontmatterCardAndTopRightCopyButton() throws {
        // 1. ZoomedChromeMetrics scales preview typography linearly at 50%, 100%, 150%, 200%, 300% while keeping >= 24pt action target
        let m50 = ZoomedChromeMetrics(zoomPercent: 50)
        let m100 = ZoomedChromeMetrics(zoomPercent: 100)
        let m200 = ZoomedChromeMetrics(zoomPercent: 200)
        #expect(m200.previewH1FontSize == m100.previewH1FontSize * 2)
        #expect(m200.previewH2FontSize == m100.previewH2FontSize * 2)
        #expect(m200.previewH3FontSize == m100.previewH3FontSize * 2)
        #expect(m200.previewBodyFontSize == m100.previewBodyFontSize * 2)
        #expect(m200.previewCodeFontSize == m100.previewCodeFontSize * 2)
        #expect(m50.previewBodyFontSize == m100.previewBodyFontSize * 0.5)
        #expect(m50.previewActionTarget >= 24)

        // 2. Enriched preview extracts line-1 YAML frontmatter as metadata entries (removing raw --- thematic breaks) and extracts fence languages
        var copiedPayloads: [String] = []
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("prev-\(UUID().uuidString)"),
            clipboardWriter: { copiedPayloads.append($0) }
        )
        model.newUntitledTab()
        model.showMarkdownPreview = true
        model.handleEditorTextChanged("""
        ---
        title: Architecture Spec
        tags: [swift, canvas]
        ---
        # Heading One

        Paragraph with `inline` code.

        ```swift
        let answer = 42
        ```
        """)

        let enriched = try #require(model.enrichedMarkdownPreviewDocument)
        #expect(enriched.frontmatterEntries == [
            GFMPreviewFrontmatterEntry(key: "title", displayValue: "Architecture Spec"),
            GFMPreviewFrontmatterEntry(key: "tags", displayValue: "[swift, canvas]"),
        ])
        #expect(enriched.blocks.contains { if case .thematicBreak = $0 { return true } else { return false } } == false)
        let codeIdx = try #require(enriched.blocks.firstIndex { if case .code = $0 { return true } else { return false } })
        #expect(enriched.fenceLanguagesByBlock[codeIdx] == "swift")

        // 3. Top-right Copy to Clipboard action copies exact raw fenced body via clipboardWriter
        model.copyPreviewCodeBlock("let answer = 42")
        #expect(copiedPayloads == ["let answer = 42"])
    }

    @Test("P4: Markmap, Mindmap, and core Mermaid (flowchart, sequenceDiagram, stateDiagram) parse and render natively on SwiftUI Canvas")
    @MainActor
    func p4MarkmapMindmapAndMermaidCoreParseAndRenderNatively() throws {
        // 1. Markmap headings + lists
        let markmapSrc = """
        # SwiftEdit
        ## Core
        - DocumentSession
        - MarkdownDiagramParser
        ## UI
        - SwiftUI Canvas
        """
        guard case .diagram(.mindmap(let mmNodes, let mmW, let mmH)) = MarkdownDiagramParser.parse(language: "markmap", source: markmapSrc) else {
            Issue.record("Expected markmap diagram model")
            return
        }
        #expect(mmNodes.count == 6)
        #expect(mmW > 100 && mmH > 60)

        // 2. Mermaid mindmap
        let mindmapSrc = """
        mindmap
          root((Project))
            Origins
              Offline
            Render
              Canvas
        """
        guard case .diagram(.mindmap(let mNodes, _, _)) = MarkdownDiagramParser.parse(language: "mermaid", source: mindmapSrc) else {
            Issue.record("Expected mermaid mindmap model")
            return
        }
        #expect(mNodes.count == 5)
        #expect(mNodes.first?.label == "Project")

        // 3. Mermaid flowchart LR with shapes, labeled edges, and subgraph
        let flowSrc = """
        flowchart LR
            subgraph Core
                A[Parser] --> B{Valid?}
            end
            B -->|Yes| C([Canvas])
            B -.->|No| D((Code))
        """
        guard case .diagram(.graph(let kind, let dir, let gNodes, let gEdges, _, _)) = MarkdownDiagramParser.parse(language: "mermaid", source: flowSrc) else {
            Issue.record("Expected flowchart diagram model")
            return
        }
        #expect(kind == .flowchart)
        #expect(dir == .leftToRight)
        #expect(gNodes.count == 4)
        #expect(gEdges.count == 3)

        // 4. Mermaid sequenceDiagram
        let seqSrc = """
        sequenceDiagram
            participant User
            participant Preview
            User->>Preview: Toggle Cmd+P
            Preview-->>User: Render Canvas
        """
        guard case .diagram(.sequence(let parts, _, let msgs, _, _)) = MarkdownDiagramParser.parse(language: "mermaid", source: seqSrc) else {
            Issue.record("Expected sequenceDiagram model")
            return
        }
        #expect(parts == ["User", "Preview"])
        #expect(msgs.count == 2)
        #expect(msgs[1].isDashed == true)

        // 5. Mermaid stateDiagram-v2
        let stateSrc = """
        stateDiagram-v2
            [*] --> Clean
            Clean --> Dirty : edit
            Dirty --> Clean : undo
        """
        guard case .diagram(.graph(let sKind, _, let sNodes, let sEdges, _, _)) = MarkdownDiagramParser.parse(language: "mermaid", source: stateSrc) else {
            Issue.record("Expected stateDiagram model")
            return
        }
        #expect(sKind == .state)
        #expect(sNodes.count >= 3)
        #expect(sEdges.count == 3)
    }

    @Test("N4 [Security]: Preview zoom clamps 20%..500% into 50%..300%, avoids stale fonts, keeps HTML inert, blocks javascript:, caps 64 images, and handles empty fence copy")
    @MainActor
    func n4PreviewZoomClampingNonStaleFontsInertHTMLAndEmptyFenceCopy() throws {
        let low = ZoomedChromeMetrics(zoomPercent: 20)
        let high = ZoomedChromeMetrics(zoomPercent: 500)
        #expect(low.factor == 0.5)
        #expect(low.previewActionTarget == 24)
        #expect(high.factor == 3.0)
        #expect(high.previewH1FontSize == 66)

        let typo = AppTypography(interface: .default, editor: .default)
        let f100 = typo.nsFont(.interface, size: ZoomedChromeMetrics(zoomPercent: 100).previewBodyFontSize)
        let f200 = typo.nsFont(.interface, size: ZoomedChromeMetrics(zoomPercent: 200).previewBodyFontSize)
        #expect(f200.pointSize == f100.pointSize * 2)
        typo.setChoice(.system(family: "Helvetica"), for: .interface)
        let fHelv = typo.nsFont(.interface, size: ZoomedChromeMetrics(zoomPercent: 150).previewBodyFontSize)
        #expect(fHelv.pointSize == 19.5)
        typo.setChoice(.openDyslexic, for: .interface)
        let fDys = typo.nsFont(.interface, size: ZoomedChromeMetrics(zoomPercent: 150).previewBodyFontSize)
        #expect(fDys.pointSize == 19.5)

        #expect(PreviewResourceAndLinkGate.decideLink("javascript:alert(1)") == .blocked)
        let snap = DocumentSession(text: "<script>alert(1)</script>\n\n```\n```").snapshot
        let enriched = try #require(MarkdownPreviewProjector.projectEnriched(snapshot: snap, showPreview: true))
        #expect(enriched.blocks.contains(.inertHTML(text: "<script>alert(1)</script>", sourceLine: 1)))

        let imgs = (0..<70).map { "![img\($0)](pic\($0).png)" }.joined(separator: " ")
        let refs = PreviewResourceAndLinkGate.imageReferences(in: imgs)
        #expect(refs.count == PreviewResourceAndLinkGate.maxImagesPerDocument)

        var copied: [String] = []
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("prev-n4-\(UUID().uuidString)"),
            clipboardWriter: { copied.append($0) }
        )
        model.copyPreviewCodeBlock("")
        #expect(copied == [""])
    }

    @Test("N5 [Security]: Oversized (>256 nodes, >512 edges, >12 depth, >64 KiB), cyclic flowcharts, and HTML-bearing Mermaid blocks degrade safely without WebKit or stack overflow")
    @MainActor
    func n5SecurityBoundsCycleBreakingAndInertDiagramLabels() throws {
        // 1. > 256 nodes rejected
        let manyNodes = (0..<260).map { "- Node\($0)" }.joined(separator: "\n")
        #expect(MarkdownDiagramParser.parse(language: "markmap", source: manyNodes) == .unsupportedOrOversized)

        // 2. > 512 edges between 2 nodes rejected (edge-flood DoS CWE-400)
        let manyEdges = (["flowchart TD"] + Array(repeating: "A --> B", count: 520)).joined(separator: "\n")
        #expect(MarkdownDiagramParser.parse(language: "mermaid", source: manyEdges) == .unsupportedOrOversized)

        // 3. > 12 depth rejected
        let deepTree = (0..<15).map { String(repeating: "  ", count: $0) + "- Level\($0)" }.joined(separator: "\n")
        #expect(MarkdownDiagramParser.parse(language: "markmap", source: deepTree) == .unsupportedOrOversized)

        // 4. > 64 KiB source rejected
        let huge = "flowchart TD\nA[" + String(repeating: "x", count: 66_000) + "]"
        #expect(MarkdownDiagramParser.parse(language: "mermaid", source: huge) == .unsupportedOrOversized)

        // 5. Cyclic graph A --> B --> A terminates iteratively without recursion
        let cyclic = "flowchart LR\nA --> B\nB --> A\nB --> C"
        guard case .diagram(.graph(_, _, let cNodes, let cEdges, _, _)) = MarkdownDiagramParser.parse(language: "mermaid", source: cyclic) else {
            Issue.record("Expected cyclic flowchart to lay out iteratively")
            return
        }
        #expect(cNodes.count == 3 && cEdges.count == 3)

        // 6. Malicious HTML label stays literal text; oversized fence degrades to plain code block in enriched preview
        let xssFlow = "flowchart TD\nA[\"<img src=x onerror=alert(1)>\"] --> B[Safe]"
        guard case .diagram(.graph(_, _, let xNodes, _, _, _)) = MarkdownDiagramParser.parse(language: "mermaid", source: xssFlow) else {
            Issue.record("Expected literal label diagram")
            return
        }
        #expect(xNodes.first?.label == "<img src=x onerror=alert(1)>")

        let fallbackSnap = DocumentSession(text: "```mermaid\n\(manyNodes)\n```").snapshot
        let enriched = try #require(MarkdownPreviewProjector.projectEnriched(snapshot: fallbackSnap, showPreview: true))
        #expect(enriched.blocks.count == 1)
        #expect(enriched.diagramsByBlock == [nil])
    }

    @Test("P4b: MarkdownNativePreviewView and MarkdownDiagramPreviewView Canvas renderers lay out Markmap, Flowchart, Sequence, and State diagrams across zoom scales")
    @MainActor
    func p4bRenderNativePreviewAndDiagramCanvasesOffscreen() throws {
        let richMarkdown = """
        ---
        title: Native Preview Canvas
        author: SwiftEdit
        ---

        # Diagram Showcase

        ```swift
        let x = 42
        ```

        ```markmap
        # Product
        ## Core
        ### Speed
        ## UI
        ```

        ```mermaid
        flowchart LR
        subgraph Pipeline
        A[Rect] --> |step| B(Rounded)
        B -.-> C([Stadium])
        end
        C ==> D{Diamond}
        D --> E((Circle))
        ```

        ```mermaid
        sequenceDiagram
        participant Client
        participant Server
        Client->>Server: Request
        Server->>Server: Validate
        Server-->>Client: Response
        ```

        ```mermaid
        stateDiagram-v2
        [*] --> Idle
        Idle --> Active : start
        Active --> [*]
        ```
        """
        let snap = DocumentSession(text: richMarkdown).snapshot
        let enriched = try #require(MarkdownPreviewProjector.projectEnriched(snapshot: snap, showPreview: true))
        let palette = PurpleThemePalette.resolve(appearance: .light, systemPrefersDark: false)

        for zoom in [100, 175] {
            let metrics = ZoomedChromeMetrics(zoomPercent: zoom)
            let preview = MarkdownNativePreviewView(
                document: nil,
                enrichedDocument: enriched,
                palette: palette,
                gate: nil,
                activeSourceLine: 1,
                zoomPercent: zoom,
                onCopyCode: { _ in }
            )
            _ = NSApplication.shared
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 1400), styleMask: [.titled], backing: .buffered, defer: false)
            win.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: preview)
            host.frame = NSRect(x: 0, y: 0, width: 960, height: 1400)
            win.contentView = host
            host.layoutSubtreeIfNeeded()
            win.displayIfNeeded()
            win.contentView = nil
            win.orderOut(nil)

            for diagram in enriched.diagramsByBlock.compactMap({ $0 }) {
                let card = MarkdownDiagramPreviewView(
                    diagram: diagram,
                    rawCode: "raw",
                    languageLabel: "mermaid",
                    palette: palette,
                    metrics: metrics,
                    onCopyCode: { _ in }
                )
                let renderer = ImageRenderer(content: card.frame(width: 720, height: 480))
                #expect(renderer.nsImage != nil)
            }
        }
    }
}
#endif
