import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("SwiftEditRootViewDecompositionTests")
struct SwiftEditRootViewDecompositionTests {

    private static let viewsDir: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/SwiftEditUI/Views")

    @Test("P3: Decomposed SwiftEditRootView files stay <= 800 lines and preserve toolbarBar and tabBar anchors")
    func p3DecomposedRootViewFilesStayWithinBudgetAndPreserveAnchors() throws {
        // GIVEN the SwiftEditRootView core file and its extracted extension files under Sources/SwiftEditUI/Views/
        let expectedFiles = [
            "SwiftEditRootView.swift",
            "SwiftEditRootView+SidebarAndContextMenus.swift",
            "SwiftEditRootView+PanelsCompareAndStatusBar.swift",
            "SwiftEditRootView+LifecycleSheetsAlertsAndKeyMonitor.swift",
        ]

        // WHEN checking existence, line counts, and static anchors
        for fileName in expectedFiles {
            let fileURL = Self.viewsDir.appendingPathComponent(fileName)
            #expect(FileManager.default.fileExists(atPath: fileURL.path), "Missing extracted view file \(fileName)")
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let lineCount = source.components(separatedBy: "\n").count
            #expect(lineCount <= 800, "\(fileName) has \(lineCount) lines (> 800)")
            #expect(!source.contains(".milliseconds(20)"))
        }

        // THEN SwiftEditRootView.swift retains the toolbarBar and tabBar anchors verified by regression suites
        let rootSource = try String(contentsOf: Self.viewsDir.appendingPathComponent("SwiftEditRootView.swift"), encoding: .utf8)
        #expect(rootSource.contains("private var toolbarBar: some View"))
        #expect(rootSource.contains("private var tabBar: some View"))
    }

    @Test("N4: Theme token audit catches forbidden system color literals in extracted view snippets")
    func n4ThemeTokenAuditRejectsForbiddenLiteralsInViewFixture() {
        // GIVEN a view snippet using a forbidden system color literal
        let rogueSnippet = """
        import SwiftUI
        struct RogueRootExtensionView: View {
            var body: some View { Text("Bad").foregroundStyle(Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)) }
        }
        """

        // WHEN scanning with ArchitectureImportScanner.scanSwiftEditUIThemeTokens
        let violations = ArchitectureImportScanner.scanSwiftEditUIThemeTokens(
            content: rogueSnippet,
            filePath: "Sources/SwiftEditUI/Views/RogueRootExtensionView.swift"
        )

        // THEN at least one semantic theme token violation is flagged
        #expect(!violations.isEmpty)
    }
}
