import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("TypographyRoutingTests")
@MainActor
struct TypographyRoutingTests {

    @Test("P8: editor regular, bold, italic and YAML-key fonts and chrome fonts come from the chosen families")
    func p8EditorAndChromeFontsFollowChoices() {
        // GIVEN Avenir Next for the interface and OpenDyslexic for the editor
        let typography = AppTypography(interface: .system(family: "Avenir Next"), editor: .openDyslexic)
        // WHEN editor rendering fonts and a chrome font are derived
        let fonts = EditorRenderingFonts(fontSizePoints: 14, typography: typography)
        let chrome = typography.nsFont(.interface, size: AppTextStyle.callout.pointSize)
        // THEN every editor face is OpenDyslexic with matching traits and the chrome font is Avenir Next
        #expect([fonts.regular, fonts.bold, fonts.italic, fonts.yamlKey].allSatisfy { $0.familyName == "OpenDyslexic" })
        #expect(fonts.bold.fontDescriptor.symbolicTraits.contains(.bold))
        #expect(fonts.italic.fontDescriptor.symbolicTraits.contains(.italic))
        #expect(chrome.familyName == "Avenir Next")
    }

    @Test("N8: no SwiftEditUI source hard-codes a font outside AppTypography")
    func n8NoHardCodedFontCallSites() {
        // GIVEN the SwiftEditUI tree and a fixture containing a hard-coded font
        let root = AuditReportFitness.repositoryRoot.appendingPathComponent("Sources/SwiftEditUI")
        // WHEN TypographyFitness scans both
        let violations = TypographyFitness.scan(directory: root)
        let fixture = TypographyFitness.violations(in: "Text(\"x\")\n    .font(.caption)\n", path: "Fixture.swift")
        // THEN the tree is clean and the fixture is reported with path and line
        #expect(violations.isEmpty, "\(violations)")
        #expect(fixture == ["Fixture.swift:2: .font(.caption)"])
    }
}

/// Static scan forbidding direct font construction in `SwiftEditUI` outside `Theme/AppTypography.swift` (`REQ-008`, `TEST-005`).
enum TypographyFitness {
    /// `.font(.<SwiftUI style or system>` plus direct AppKit/SwiftUI font factories.
    static let stylePattern = #"\.font\(\.(system|largeTitle|title|title2|title3|headline|subheadline|body|callout|footnote|caption|caption2)\b"#
    static let forbiddenFactories = ["monospacedSystemFont(", "NSFont.systemFont(", "Font.system(", "NSFont(name:", ".title.bold()", ".title2.bold()", ".title3.bold()"]
    static let allowedFile = "AppTypography.swift"

    static func violations(in source: String, path: String) -> [String] {
        source.components(separatedBy: "\n").enumerated().compactMap { number, line in
            let code = line.components(separatedBy: "//").first ?? line
            if let range = code.range(of: stylePattern, options: .regularExpression) {
                return "\(path):\(number + 1): \(code[range]))"
            }
            guard let token = forbiddenFactories.first(where: { code.contains($0) }) else { return nil }
            return "\(path):\(number + 1): \(token)"
        }
    }

    static func scan(directory: URL) -> [String] {
        let enumerator = FileManager.default.enumerator(atPath: directory.path)
        let files = (enumerator?.allObjects as? [String] ?? []).filter { $0.hasSuffix(".swift") && !$0.hasSuffix(allowedFile) }
        return files.sorted().flatMap { file in
            violations(in: (try? String(contentsOf: directory.appendingPathComponent(file), encoding: .utf8)) ?? "", path: file)
        }
    }
}
