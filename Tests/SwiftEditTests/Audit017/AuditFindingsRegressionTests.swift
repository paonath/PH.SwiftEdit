import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Regression tests for the P0–P2 findings of `docs/qa/debug-audit-report-017-baseline.md` (`REQ-002`).
@Suite("AuditFindingsRegressionTests", .serialized)
@MainActor
struct AuditFindingsRegressionTests {

    /// Icon-only `Button`s whose surrounding block lacks an accessibility label (same heuristic as the audit scan).
    private static func unlabeledIconButtons() -> [String] {
        let dir = AuditReportFitness.repositoryRoot.appendingPathComponent("Sources/SwiftEditUI/Views")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.filter { $0.hasSuffix(".swift") }.flatMap { name -> [String] in
            let lines = AuditReportFitness.read("Sources/SwiftEditUI/Views/\(name)").components(separatedBy: "\n")
            return lines.indices.filter { lines[$0].contains("AppIconView(") || lines[$0].contains("Image(systemName") }.compactMap { i in
                // `AppIconView` is decorative by default (or labelled via `label:`), so the owning Button's label may sit
                // further down its modifier chain: scan a wider window for it.
                let isAppIcon = lines[i].contains("AppIconView(")
                if isAppIcon && lines[i].contains("label:") { return nil }
                // An icon followed by visible text in the same label is not an icon-only button.
                if isAppIcon && lines[(i + 1)..<min(lines.count, i + 5)].contains(where: { $0.contains("Text(") }) { return nil }
                let context = lines[max(0, i - 6)..<min(lines.count, i + (isAppIcon ? 32 : 10))].joined(separator: "\n")
                let decorativeOK = !isAppIcon && context.contains("accessibilityHidden")
                guard context.contains("Button"), !context.contains("accessibilityLabel"), !decorativeOK, !context.contains("Label(") else { return nil }
                return "\(name):\(i + 1)"
            }
        }
    }

    @Test("F-017-01: gutter viewport metrics stay bounded when a large document is not yet laid out")
    func f01GutterViewportMetricsAreBoundedForUnlaidLargeDocument() {
        // GIVEN a 20k-line document in a TextKit 2 text view inside a small, never-displayed scroll view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        scrollView.documentView = textView
        textView.string = (0..<20_000).map { "line \($0)" }.joined(separator: "\n")
        // WHEN gutter metrics are captured before any viewport layout pass
        let metrics = TextKit2EditorView.Coordinator.captureGutterViewportMetrics(in: scrollView, textView: textView)
        // THEN only a viewport-sized slice is produced, never the whole document
        #expect(metrics.visibleLines.count <= 512, "captured \(metrics.visibleLines.count) gutter rows")
        #expect(metrics.visibleLines.count <= TextKit2EditorView.Coordinator.maxGutterLineMetrics)
        #expect(TextKit2EditorView.Coordinator.maxGutterLineMetrics <= 512)
    }

    @Test("F-017-02: link text in the editor meets WCAG AA contrast in Light and Black modes")
    func f02LinkForegroundMeetsContrastInBothModes() {
        // GIVEN both palettes and the editor font set
        let light = PurpleThemePalette.resolve(appearance: .light, systemPrefersDark: false)
        let black = PurpleThemePalette.resolve(appearance: .black, systemPrefersDark: true)
        let fonts = EditorRenderingFonts(fontSizePoints: 13)
        // WHEN link attributes and contrast are derived
        let blackLink = EditorRenderingAttributes.attributes(for: .link, palette: black, fonts: fonts)
        // THEN the dedicated link token is >= 4.5:1 on each canvas and is what the editor applies
        #expect(light.linkForeground.contrastRatio(against: light.editorCanvasBackground) >= 4.5)
        #expect(black.linkForeground.contrastRatio(against: black.editorCanvasBackground) >= 4.5)
        #expect(blackLink.contains { $0.key == .foregroundColor && ($0.value as? NSColor) == black.linkForeground.nsColor })
    }

    @Test("F-017-03: tab strip icon buttons use the 24 pt minimum hit target")
    func f03TabStripIconButtonsUseMinimumHitTarget() {
        // GIVEN the tab strip source
        let source = AuditReportFitness.read("Sources/SwiftEditUI/Views/SwiftEditRootView.swift")
        let start = source.range(of: "private var tabBar: some View")
        let tabBar = start.map { String(source[$0.lowerBound...].prefix(4000)) } ?? ""
        // WHEN icon buttons and hit-target modifiers are counted
        let closeGlyphs = tabBar.components(separatedBy: "AppIconView(.close").count - 1
        let hitTargets = tabBar.components(separatedBy: ".minimumHitTarget(").count - 1
        // THEN the single icon button of a flat tab (close / unsaved dot, redesign-020 R-03) applies the 24 pt target;
        // pin and reorder moved to the context menu and drag.
        #expect(closeGlyphs == 1)
        #expect(hitTargets >= closeGlyphs)
        #expect(!tabBar.contains("Image(systemName"))
        #expect(ChromeHitTarget.minimumPoints == 24)
    }

    @Test("F-017-04: every icon-only button exposes an accessibility label")
    func f04IconOnlyButtonsHaveAccessibilityLabels() {
        // GIVEN the SwiftUI view sources
        // WHEN icon-only buttons are scanned
        let unlabeled = Self.unlabeledIconButtons()
        // THEN none lacks a label
        #expect(unlabeled.isEmpty, "\(unlabeled)")
    }

    @Test("P2/N2: every P0–P2 baseline finding is resolved by an existing regression test and P3 findings are backlog")
    func p2n2BaselineFindingsAreRemediated() {
        // GIVEN the baseline report and every test source
        let report = AuditReportFitness.read("docs/qa/debug-audit-report-017-baseline.md")
        let testsDir = AuditReportFitness.repositoryRoot.appendingPathComponent("Tests/SwiftEditTests")
        let enumerator = FileManager.default.enumerator(atPath: testsDir.path)
        let sources = (enumerator?.allObjects as? [String] ?? []).filter { $0.hasSuffix(".swift") }
            .map { AuditReportFitness.read("Tests/SwiftEditTests/\($0)") }.joined(separator: "\n")
        // WHEN remediation is cross-checked
        let issues = AuditReportFitness.remediationIssues(report, testSources: sources)
        let fixture = "## Findings\n| ID | Severity | Title | Repro | Measured | Status |\n| F-017-99 | P1 | t | r | m | resolved: noSuchTest |\n"
        // THEN the live report is clean and a fabricated reference is rejected
        #expect(issues.isEmpty, "\(issues)")
        #expect(AuditReportFitness.remediationIssues(fixture, testSources: sources) == ["F-017-99: regression test 'noSuchTest' not found"])
    }
}
