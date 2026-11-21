import AppKit
import Foundation
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Golden fingerprints for change `017`: the `016` groups plus preview, typography and zoom metrics (`REQ-010`, `N10`).
enum PerfGolden017 {
    static let recorded: [String: UInt64] = [
        "frontmatter": 3855822002301108325,
        "gutter": 11860002414274336196,
        "lint.markdown": 17751757224689353408,
        "lint.yaml": 675868731199239589,
        "navigator.outline.yaml+md": 2439797187907292134,
        "outline.markdown": 3888972219280982894,
        "outline.yaml": 2668794176289243962,
        "preview.markdown": 11456593429136828558,
        "smartEdits": 4867229877339570063,
        "spans.markdown": 6899874283710100662,
        "spans.yaml": 16993897896420750088,
        "statusbar": 6560422114123526740,
        "typography": 3596096720916323827,
        "zoom.metrics": 11415995017675595665,
    ]

    @MainActor
    static func current() -> [String: UInt64] {
        var groups = PerfGolden016.current()
        let md = DocumentSession(text: PerfGolden016.markdown).snapshot
        let preview = MarkdownPreviewProjector.project(snapshot: md, showPreview: true)
        groups["preview.markdown"] = PerfBench016.fingerprint(preview as Any)
        let typography = AppTypography(interface: .system(family: "Helvetica Neue"), editor: .system(family: "Menlo"))
        let faces = [typography.nsFont(.interface, size: 13), typography.nsFont(.editor, size: 14, weight: .bold), typography.nsFont(.editor, size: 14, italic: true)]
        groups["typography"] = PerfBench016.fingerprint(faces.map { "\($0.familyName ?? "") \($0.pointSize) \($0.fontDescriptor.symbolicTraits.rawValue)" })
        groups["zoom.metrics"] = PerfBench016.fingerprint([50, 100, 150, 200, 300].map { ZoomedChromeMetrics(zoomPercent: $0).scaledValues })
        groups["navigator.outline.yaml+md"] = PerfBench016.fingerprint([MarkdownHeadingOutlineEngine.outline(for: PerfGolden016.markdown).count, YAMLOutlineEngine.outline(index: MarkdownLineIndex(text: PerfGolden016.yaml)).count])
        return groups
    }
}
