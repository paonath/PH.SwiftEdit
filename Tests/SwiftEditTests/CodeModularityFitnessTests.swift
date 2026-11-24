import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("CodeModularityFitnessTests")
struct CodeModularityFitnessTests {

    private static let repoRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    @Test("P1: Package.swift topology and live Sources/SwiftEditCore + Sources/SwiftEditUI pass file (<=800), block (<=400), and member (<=25) budgets")
    func p1LiveProductionSourcesPassModularityBudgets() throws {
        // GIVEN Package.swift target layout and the live SwiftEditCore + SwiftEditUI production source directories
        let packageManifest = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let directories = [
            Self.repoRoot.appendingPathComponent("Sources/SwiftEditCore"),
            Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI"),
        ]

        // WHEN scanning all production Swift source files against the tightened default modularity budgets
        let violations = try CodeModularityFitnessScanner.scanDirectories(at: directories, budgets: .default)

        // THEN Package.swift preserves the 3-target topology, default budgets are 800/400/25, and zero violations occur
        #expect(packageManifest.contains("name: \"SwiftEditCore\""))
        #expect(packageManifest.contains("name: \"SwiftEditUI\""))
        #expect(packageManifest.contains("name: \"SwiftEditTests\""))
        #expect(CodeModularityBudgets.default.maxFileLines == 800)
        #expect(CodeModularityBudgets.default.maxNominalBlockLines == 400)
        #expect(CodeModularityBudgets.default.maxNominalMembers == 25)
        #expect(CodeModularityBudgets().maxNominalBlockLines == 400)
        #expect(CodeModularityBudgets().maxNominalMembers == 25)
        #expect(violations.isEmpty, "Modularity violations:\n\(violations.map(\.description).joined(separator: "\n"))")
    }

    @Test("N1: Synthetic fixtures exceeding 800 file lines, 400 nominal block lines, or 25 attribute-annotated/private(set) members emit typed violations")
    func n1OversizedFileBlockOrMemberCountEmitsTypedViolations() {
        // GIVEN synthetic fixtures exceeding each tightened budget by 1 (801 file lines, 401 block lines, 26 members)
        let oversizedFile = Array(repeating: "// comment line", count: 801).joined(separator: "\n")
        let oversizedBlock = "struct GiantStruct {\n"
            + Array(repeating: "    // body line", count: 399).joined(separator: "\n")
            + "\n}"
        let attributedMembers = [
            "    init() {}",
            "    isolated deinit {}",
            "    @ObservationIgnored var hook: () -> Bool = { false }",
            "    @available(macOS 14.0, *) func gatedAction() {}",
            "    public private(set) var trackedState: Int = 0",
        ] + (1...21).map { "    var field\($0): Int = \($0)" }
        let oversizedMembers = "class GodClass {\n"
            + attributedMembers.joined(separator: "\n")
            + "\n}\n"

        // WHEN scanning each fixture
        let fileViolations = CodeModularityFitnessScanner.scanSource(content: oversizedFile, filePath: "Sources/Fake/File.swift")
        let blockViolations = CodeModularityFitnessScanner.scanSource(content: oversizedBlock, filePath: "Sources/Fake/Block.swift")
        let memberViolations = CodeModularityFitnessScanner.scanSource(content: oversizedMembers, filePath: "Sources/Fake/God.swift")

        // THEN each fixture reports the exact typed violation kind and observed count (401 block lines > 400, 26 members > 25)
        #expect(fileViolations.contains { $0.kind == .fileLineCount && $0.observed == 801 && $0.limit == 800 })
        #expect(blockViolations.contains { $0.kind == .nominalBlockLineCount && $0.symbolName == "GiantStruct" && $0.observed == 401 && $0.limit == 400 })
        #expect(memberViolations.contains { $0.kind == .nominalMemberCount && $0.symbolName == "GodClass" && $0.observed == 26 && $0.limit == 25 })
    }

    @Test("N2 [Security]: Symlinked .swift file escaping root, parent traversal, or file > 4 MiB fails closed with securityBoundaryViolation")
    func n2SymlinkEscapeAndOversizedPayloadFailClosed() throws {
        // GIVEN a temporary directory containing a symlink escaping the root and a > 4 MiB Swift file
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-modularity-sec-\(UUID().uuidString)", isDirectory: true)
        let outsideFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-outside-\(UUID().uuidString).swift")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "struct OutsideSecret {}\n".write(to: outsideFile, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
            try? FileManager.default.removeItem(at: outsideFile)
        }

        let symlinkURL = tempRoot.appendingPathComponent("Escape.swift")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideFile)
        let symlinkDirURL = tempRoot.appendingPathComponent("EscapeDir")
        try FileManager.default.createSymbolicLink(
            at: symlinkDirURL,
            withDestinationURL: outsideFile.deletingLastPathComponent()
        )

        let hugeURL = tempRoot.appendingPathComponent("Huge.swift")
        let hugeData = Data(repeating: 0x20, count: CodeModularityBudgets.default.maxFileBytes + 1)
        try hugeData.write(to: hugeURL)
        let traversalRoot = try #require(URL(string: tempRoot.absoluteString + "../"))

        // WHEN scanning the directory with modularity, acyclicity, and shared multi-directory preflight scanners and probing ../ parent traversal
        let violations = try CodeModularityFitnessScanner.scanDirectory(at: tempRoot, budgets: .default)
        let acyclicViolations = try CodeModularityFitnessScanner.verifyAcyclicFileGraph(at: [tempRoot], budgets: .default)
        let sharedPreflight = try CodeModularityFitnessScanner.collectValidatedDirectorySources(
            at: [tempRoot, traversalRoot],
            budgets: .default
        )
        let traversalScanViolations = try CodeModularityFitnessScanner.scanDirectory(at: traversalRoot, budgets: .default)
        let traversalAcyclicViolations = try CodeModularityFitnessScanner.verifyAcyclicFileGraph(at: [traversalRoot], budgets: .default)

        // THEN file/directory symlink escapes, > 4 MiB payload, and ../ traversal all fail closed with .securityBoundaryViolation without reading external bytes
        let securityViolations = violations.filter { $0.kind == .securityBoundaryViolation }
        let acyclicSecurityViolations = acyclicViolations.filter { $0.kind == .securityBoundaryViolation }
        #expect(securityViolations.count == 3)
        #expect(securityViolations.contains { $0.filePath.contains("Escape.swift") })
        #expect(securityViolations.contains { $0.filePath.contains("EscapeDir") })
        #expect(securityViolations.contains { $0.filePath.contains("Huge.swift") })
        #expect(acyclicSecurityViolations.count == 3)
        #expect(acyclicSecurityViolations.contains { $0.filePath.contains("Escape.swift") })
        #expect(acyclicSecurityViolations.contains { $0.filePath.contains("EscapeDir") })
        #expect(acyclicSecurityViolations.contains { $0.filePath.contains("Huge.swift") })
        #expect(sharedPreflight.sources.isEmpty)
        #expect(sharedPreflight.violations.filter { $0.kind == .securityBoundaryViolation }.count == 4)
        #expect(traversalScanViolations.contains { $0.kind == .securityBoundaryViolation })
        #expect(traversalAcyclicViolations.contains { $0.kind == .securityBoundaryViolation })
    }

    @Test("P6: Production file dependency graph across Sources/SwiftEditCore and Sources/SwiftEditUI is acyclic with MarkdownLineIndex.swift isolated as a leaf")
    func p6ProductionFileDependencyGraphIsAcyclicWithIsolatedLineIndex() throws {
        // GIVEN live Sources/SwiftEditCore and Sources/SwiftEditUI directories and expected MarkdownLineIndex.swift leaf file
        let lineIndexURL = Self.repoRoot.appendingPathComponent("Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLineIndex.swift")
        let directories = [
            Self.repoRoot.appendingPathComponent("Sources/SwiftEditCore"),
            Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI"),
        ]

        // WHEN verifying the file dependency graph for circular cycles and upward Core -> UI references
        let violations = try CodeModularityFitnessScanner.verifyAcyclicFileGraph(at: directories)

        // THEN MarkdownLineIndex.swift exists as an isolated leaf and zero circular file dependencies exist
        #expect(FileManager.default.fileExists(atPath: lineIndexURL.path), "Expected extracted leaf MarkdownLineIndex.swift")
        #expect(violations.isEmpty, "Circular or upward file dependency violations:\n\(violations.map(\.description).joined(separator: "\n"))")
    }

    @Test("N7: Synthetic 2-file cycle and upward SwiftEditCore -> SwiftEditUI reference emit circularFileDependency violations")
    func n7SyntheticFileCycleAndUpwardReferenceEmitViolations() {
        // GIVEN a synthetic 2-file mutual call cycle and an upward Core -> UI symbol reference
        let cyclicSources: [(filePath: String, content: String)] = [
            (
                filePath: "Sources/SwiftEditUI/FeatureA.swift",
                content: """
                enum FeatureA {
                    static func stepA() { FeatureB.stepB() }
                }
                """
            ),
            (
                filePath: "Sources/SwiftEditUI/FeatureB.swift",
                content: """
                enum FeatureB {
                    static func stepB() { FeatureA.stepA() }
                }
                """
            ),
        ]
        let upwardSources: [(filePath: String, content: String)] = [
            (
                filePath: "Sources/SwiftEditCore/Engine.swift",
                content: """
                enum CoreEngine {
                    static func run() { UIShellBridge.notifyUI() }
                }
                """
            ),
            (
                filePath: "Sources/SwiftEditUI/UIShellBridge.swift",
                content: """
                enum UIShellBridge {
                    static func notifyUI() {}
                }
                """
            ),
        ]

        // WHEN verifying acyclicity and inward layering
        let cycleViolations = CodeModularityFitnessScanner.verifyAcyclicFileGraph(sources: cyclicSources)
        let upwardViolations = CodeModularityFitnessScanner.verifyAcyclicFileGraph(sources: upwardSources)

        // THEN both fixtures are rejected with .circularFileDependency diagnostics
        #expect(cycleViolations.contains { $0.kind == .circularFileDependency && $0.reason.contains("FeatureA.swift") && $0.reason.contains("FeatureB.swift") })
        #expect(upwardViolations.contains { $0.kind == .circularFileDependency && $0.filePath.contains("SwiftEditCore/Engine.swift") })
    }

    @Test("P7: View/layer invalidation uses iterative worklists and wrapper adapters avoid intra-type self-call name collisions")
    @MainActor
    func p7IterativeViewLayerInvalidationAndWrapperCallDisambiguation() throws {
        // GIVEN nested NSView and CALayer hierarchies plus production source files targeted by REQ-007
        let hostWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        rootView.wantsLayer = true
        let childView = NSView(frame: NSRect(x: 0, y: 0, width: 50, height: 50))
        childView.wantsLayer = true
        let grandchildView = NSView(frame: NSRect(x: 0, y: 0, width: 25, height: 25))
        grandchildView.wantsLayer = true
        let childSublayer = CALayer()
        childView.addSubview(grandchildView)
        rootView.addSubview(childView)
        hostWindow.contentView?.addSubview(rootView)
        childView.layer?.addSublayer(childSublayer)
        rootView.needsDisplay = false
        childView.needsDisplay = false
        grandchildView.needsDisplay = false
        defer { rootView.removeFromSuperview() }

        let textViewSource = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI/Views/SwiftEditNSTextViewAndUndoRegistry.swift"),
            encoding: .utf8
        )
        let contextualSource = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+ContextualMenuAndShortcuts.swift"),
            encoding: .utf8
        )
        let desktopSource = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI/Workspace/DesktopWorkspaceIntegrating.swift"),
            encoding: .utf8
        )
        let settingsSource = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI/Views/SettingsView.swift"),
            encoding: .utf8
        )

        // WHEN marking subviews and layers iteratively and resolving a workspace terminal launch
        let visitedViews = SwiftEditNSTextView.markSubviewsAndLayersNeedsDisplay(rootView)
        let visitedLayers = SwiftEditNSTextView.markLayerTreeNeedsDisplay(childView.layer!)
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-term-p7-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let launch = try DesktopWorkspaceValidator.resolveTerminalLaunch(
            targetURL: tmpDir,
            withinScope: tmpDir,
            preferredTerminal: .terminal,
            isITerm2Installed: false
        )

        // THEN all views/layers are visited, terminal resolution succeeds, and zero recursive self-calls or mutual call cycles remain across Sources/
        let sourceDirs = [
            Self.repoRoot.appendingPathComponent("Sources/SwiftEditCore"),
            Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI"),
        ]
        let liveRecursionViolations = try CodeModularityFitnessScanner.verifyZeroCallGraphRecursion(at: sourceDirs)
        let syntheticMutualCycle: [(filePath: String, content: String)] = [(
            filePath: "Sources/SwiftEditUI/FakeWorker.swift",
            content: """
            final class FakeWorker {
                private func pollLocked() { armVnodeLocked() }
                private func armVnodeLocked() { self.pollLocked() }
            }
            """
        )]
        let syntheticSelfOverload: [(filePath: String, content: String)] = [(
            filePath: "Sources/SwiftEditCore/FakeTabs.swift",
            content: """
            struct FakeTabs {
                mutating func moveTab(id: Int) { moveTab(fromIndex: 0, toIndex: id) }
                private mutating func moveTab(fromIndex: Int, toIndex: Int) {}
            }
            """
        )]
        let mutualViolations = CodeModularityFitnessScanner.verifyZeroCallGraphRecursion(sources: syntheticMutualCycle)
        let overloadViolations = CodeModularityFitnessScanner.verifyZeroCallGraphRecursion(sources: syntheticSelfOverload)

        let typographySource = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI/Theme/AppTypography.swift"),
            encoding: .utf8
        )
        let logTailSource = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI/Workspace/LogTailController.swift"),
            encoding: .utf8
        )

        #expect(visitedViews == 3)
        #expect(visitedLayers >= 2)
        #expect(rootView.needsDisplay && childView.needsDisplay && grandchildView.needsDisplay)
        #expect(launch.bundleIdentifier == TerminalLaunchResolution.appleTerminalBundleIdentifier)
        #expect(liveRecursionViolations.isEmpty, "Live call-graph recursion violations:\n\(liveRecursionViolations.map(\.description).joined(separator: "\n"))")
        #expect(mutualViolations.contains { $0.kind == .callGraphRecursion })
        #expect(overloadViolations.contains { $0.kind == .callGraphRecursion })
        #expect(!typographySource.contains("openDyslexic.font("))
        #expect(!typographySource.contains("manager.font(withFamily:"))
        #expect(!logTailSource.contains("self.pollLocked(force: false)"))
        #expect(!textViewSource.contains("markSubviewsAndLayersNeedsDisplay(subview"))
        #expect(!textViewSource.contains("markLayerTreeNeedsDisplay(sub"))
        #expect(!contextualSource.contains("editableEditorTextView(in: child)"))
        #expect(!desktopSource.contains("return try resolveTerminalLaunch("))
        #expect(!settingsSource.contains("private func entries(for role:"))
    }

    @Test("N8 [Security]: View and CALayer invalidation traversals terminate deterministically at maxVisitedNodes = 4096 (CWE-674 / CWE-400)")
    @MainActor
    func n8BoundedTraversalCapsVisitationAt4096Nodes() {
        // GIVEN a CALayer tree and an NSView tree each exceeding 4,096 total nodes (1 + 65 + 4,225 = 4,291 nodes)
        let rootLayer = CALayer()
        let rootView = NSView(frame: .zero)
        for _ in 0..<65 {
            let branchLayer = CALayer()
            let branchView = NSView(frame: .zero)
            for _ in 0..<65 {
                branchLayer.addSublayer(CALayer())
                branchView.addSubview(NSView(frame: .zero))
            }
            rootLayer.addSublayer(branchLayer)
            rootView.addSubview(branchView)
        }

        // WHEN traversing with the default 4,096 security cap and a zero-budget boundary
        let visitedLayers = SwiftEditNSTextView.markLayerTreeNeedsDisplay(rootLayer)
        let visitedViews = SwiftEditNSTextView.markSubviewsAndLayersNeedsDisplay(rootView)
        let zeroBudgetLayers = SwiftEditNSTextView.markLayerTreeNeedsDisplay(rootLayer, maxVisitedNodes: 0)
        let zeroBudgetViews = SwiftEditNSTextView.markSubviewsAndLayersNeedsDisplay(rootView, maxVisitedNodes: 0)

        // THEN visitation halts strictly at 4,096 nodes without unbounded CPU/stack growth and fails closed on <= 0 limits
        #expect(SwiftEditNSTextView.maxTraversalVisitedNodes == 4_096)
        #expect(visitedLayers == 4_096)
        #expect(visitedViews == 4_096)
        #expect(zeroBudgetLayers == 0)
        #expect(zeroBudgetViews == 0)
    }
}

@Suite("CodeModularityComplexityAndDepthFitnessTests")
struct CodeModularityComplexityAndDepthFitnessTests {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    @Test("P8: All production methods in Sources/SwiftEditCore and Sources/SwiftEditUI satisfy cyclomatic <= 15 and cognitive <= 25")
    func p8AllProductionMethodsSatisfyComplexityCeilings() throws {
        // GIVEN live Sources/SwiftEditCore and Sources/SwiftEditUI plus synthetic boundary fixtures
        let sourceDirs = [
            Self.repoRoot.appendingPathComponent("Sources/SwiftEditCore"),
            Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI"),
        ]
        let syntheticOverBudget: [(filePath: String, content: String)] = [(
            filePath: "Sources/SwiftEditCore/OverComplex.swift",
            content: """
            enum OverComplex {
                static func giantSwitch(_ x: Int) -> Int {
                    if x == 1 { if x > 0 { if x < 9 { if x != 2 { if x != 3 { if x != 4 { if x != 5 { return 1 } } } } } } }
                    switch x {
                    case 1: return 1
                    case 2: return 2
                    case 3: return 3
                    case 4: return 4
                    case 5: return 5
                    case 6: return 6
                    case 7: return 7
                    case 8: return 8
                    case 9: return 9
                    case 10: return 10
                    default: return 0
                    }
                }
            }
            """
        )]

        // WHEN evaluating per-method cyclomatic (<= 15) and cognitive (<= 25) complexity budgets
        let liveViolations = try CodeModularityFitnessScanner.verifyMethodComplexityBudgets(
            at: sourceDirs,
            maxCyclomatic: 15,
            maxCognitive: 25
        )
        let syntheticViolations = CodeModularityFitnessScanner.verifyMethodComplexityBudgets(
            sources: syntheticOverBudget,
            maxCyclomatic: 15,
            maxCognitive: 25
        )

        // THEN live Sources/ have zero complexity violations and synthetic violations emit both typed kinds
        #expect(liveViolations.isEmpty, "Complexity budget violations (\(liveViolations.count)):\n\(liveViolations.map(\.description).joined(separator: "\n"))")
        #expect(syntheticViolations.contains { $0.kind == .methodCyclomaticComplexity })
        #expect(syntheticViolations.contains { $0.kind == .methodCognitiveComplexity })
    }

    @Test("P9 & N10: Production Sources/ have 0 dead private functions and max file dependency depth <= 10; synthetic 11-hop chain and unused private func fail closed")
    func p9AndN10ZeroDeadPrivateFunctionsAndMaxDependencyDepth10() throws {
        // GIVEN live Sources/SwiftEditCore and Sources/SwiftEditUI plus synthetic 11-hop chain and dead-private-func fixtures
        let sourceDirs = [
            Self.repoRoot.appendingPathComponent("Sources/SwiftEditCore"),
            Self.repoRoot.appendingPathComponent("Sources/SwiftEditUI"),
        ]
        var synthetic11Hop: [(filePath: String, content: String)] = []
        for step in 0...11 {
            let body = step < 11 ? "Step\(step + 1).hop\(step + 1)()" : "()"
            synthetic11Hop.append((
                filePath: "Sources/SwiftEditCore/Step\(step).swift",
                content: """
                enum Step\(step) {
                    static func hop\(step)() { \(body) }
                }
                """
            ))
        }
        let syntheticDeadPrivate: [(filePath: String, content: String)] = [(
            filePath: "Sources/SwiftEditCore/DeadHelperFixture.swift",
            content: """
            enum DeadHelperFixture {
                static func liveEntry() -> Int { activeHelper() }
                private static func activeHelper() -> Int { 42 }
                private static func unusedGhostHelper() -> Int { 0 }
            }
            """
        )]

        // WHEN running verifyDeadPrivateSymbolsAndDependencyDepth(maxDepth: 10)
        let liveViolations = try CodeModularityFitnessScanner.verifyDeadPrivateSymbolsAndDependencyDepth(
            at: sourceDirs,
            maxDepth: 10
        )
        let chainViolations = CodeModularityFitnessScanner.verifyDeadPrivateSymbolsAndDependencyDepth(
            sources: synthetic11Hop,
            maxDepth: 10
        )
        let deadViolations = CodeModularityFitnessScanner.verifyDeadPrivateSymbolsAndDependencyDepth(
            sources: syntheticDeadPrivate,
            maxDepth: 10
        )

        // THEN live Sources/ pass with 0 violations and synthetic fixtures emit .fileDependencyDepth and .deadPrivateSymbol
        #expect(liveViolations.isEmpty, "Dead-private or depth violations (\(liveViolations.count)):\n\(liveViolations.map(\.description).joined(separator: "\n"))")
        #expect(chainViolations.contains { $0.kind == .fileDependencyDepth && $0.observed == 11 })
        #expect(deadViolations.count == 1 && deadViolations.first?.kind == .deadPrivateSymbol && deadViolations.first?.symbolName == "unusedGhostHelper")
    }
}
