import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("NavigatorRevealScrollTests", .serialized)
@MainActor
struct NavigatorRevealScrollTests {

    private static func makeEditor(lines: Int) -> (NSWindow, NSScrollView, SwiftEditNSTextView) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        scrollView.hasVerticalScroller = true
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
        scrollView.documentView = textView
        window.contentView = scrollView
        textView.string = (1...lines).map { $0 % 50 == 0 ? "## Heading \($0)" : "line \($0)" }.joined(separator: "\n")
        textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
        return (window, scrollView, textView)
    }

    private static func lineRect(_ textView: NSTextView, offset: Int) -> NSRect? {
        guard let tlm = textView.textLayoutManager, let tcm = tlm.textContentManager,
              let loc = tcm.location(tcm.documentRange.location, offsetBy: offset),
              let fragment = tlm.textLayoutFragment(for: loc) else { return nil }
        return fragment.layoutFragmentFrame
    }

    @Test("P-NAV1: revealing a far heading scrolls the editor so the heading line is visible (down and back up)")
    func pRevealScrollsDownAndUp() throws {
        // GIVEN a 4000-line document scrolled to the top
        let (window, scrollView, textView) = Self.makeEditor(lines: 4000)
        defer { window.close() }
        let target = ((1..<3500).map { $0 % 50 == 0 ? "## Heading \($0)" : "line \($0)" }.joined(separator: "\n") as NSString).length + 1
        // WHEN the navigator jump reveals line 3500, then line 50
        TextKit2EditorView.Coordinator.revealSelection(NSRange(location: target, length: 0), in: textView)
        let farRect = try #require(Self.lineRect(textView, offset: target))
        let visibleAfterDown = scrollView.documentVisibleRect
        TextKit2EditorView.Coordinator.revealSelection(NSRange(location: 400, length: 0), in: textView)
        let nearRect = try #require(Self.lineRect(textView, offset: 400))
        let visibleAfterUp = scrollView.documentVisibleRect
        // THEN each target line lies inside the visible rect
        #expect(visibleAfterDown.intersects(farRect), "visible \(visibleAfterDown) target \(farRect)")
        #expect(visibleAfterUp.intersects(nearRect), "visible \(visibleAfterUp) target \(nearRect)")
        #expect(textView.selectedRange().location == 400)
    }

    @Test("N-NAV1: out-of-range targets are clamped and never crash")
    func nOutOfRangeClamped() {
        // GIVEN a short document
        let (window, _, textView) = Self.makeEditor(lines: 10)
        defer { window.close() }
        // WHEN a stale offset beyond the end is revealed
        TextKit2EditorView.Coordinator.revealSelection(NSRange(location: 10_000, length: 5), in: textView)
        // THEN the caret is clamped to the end
        #expect(textView.selectedRange() == NSRange(location: (textView.string as NSString).length, length: 0))
    }

    @Test("P-NAV2: clicking anywhere on a navigator row (not only its title glyphs) jumps to the heading")
    func pWholeRowIsClickable() {
        // GIVEN the navigator overlay source
        let source = AuditReportFitness.read("Sources/SwiftEditUI/Views/DocumentNavigatorOverlayView.swift")
        let tap = source.range(of: ".onTapGesture")
        let shape = source.range(of: ".contentShape(Rectangle())")
        // WHEN the row modifiers are located
        // THEN a full-row hit shape precedes the tap handler that selects and confirms
        #expect(shape != nil && tap != nil)
        #expect(shape!.lowerBound < tap!.lowerBound)
        #expect(source.contains("model.confirmDocumentNavigator()"))
    }
}
