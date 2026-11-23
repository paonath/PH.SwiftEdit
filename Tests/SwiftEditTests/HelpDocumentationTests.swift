import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("HelpDocumentationTests")
@MainActor
struct HelpDocumentationTests {

    @Test("P-HELP1: the in-app help is the repository README, names the app SwiftEdit and projects to preview blocks")
    func pBundledReadmeMatchesRepository() throws {
        // GIVEN the bundled help README and the repository README
        let bundled = try #require(HelpDocumentation.readme())
        let repository = AuditReportFitness.read("README.md")
        // WHEN the bundled copy is projected for the help window
        let document = HelpDocumentation.document()
        // THEN both files are identical, the app is SwiftEdit, the quarantine command targets SwiftEdit.app, README links the User Guide, and the preview renders
        #expect(bundled == repository)
        #expect(bundled.contains("<h1 align=\"center\">SwiftEdit</h1>"))
        #expect(bundled.contains("docs/guide/00-index.md"))
        #expect(bundled.contains("xattr -dr com.apple.quarantine /Applications/SwiftEdit.app"))
        #expect(document?.blocks.isEmpty == false)
    }

    @Test("P-HELP2: every onboard User Guide chapter matches docs/guide/*.md, renders offline, and contains no third-party editor references")
    func pBundledUserGuideChaptersMatchRepositoryAndProject() throws {
        let guideChapters = HelpDocumentation.chapters.filter { $0.subdirectory == "Help/guide" }
        #expect(guideChapters.count == 6)
        let forbiddenPatterns = [
            #"\bzed\b"#, #"\bobsidian\b"#, #"\bvs\s?code\b"#, #"\bnotepad\+\+"#,
            #"\bsublime\b"#, #"\btypora\b"#, #"\balfred\b"#,
        ]
        for chapter in guideChapters {
            let bundled = try #require(HelpDocumentation.markdown(for: chapter), "Missing bundled chapter \(chapter.resourceName)")
            let repoPath = "docs/guide/\(chapter.resourceName).md"
            let repository = AuditReportFitness.read(repoPath)
            #expect(bundled == repository, "Bundled Help chapter \(chapter.resourceName) drifted from \(repoPath)")
            let projected = HelpDocumentation.document(for: chapter)
            #expect(projected?.blocks.isEmpty == false, "Chapter \(chapter.resourceName) failed to project")
            for pattern in forbiddenPatterns {
                #expect(
                    repository.range(of: pattern, options: [.regularExpression, .caseInsensitive]) == nil,
                    "Found forbidden third-party editor reference '\(pattern)' in \(repoPath)"
                )
            }
        }
    }

    @Test("N-HELP1: the README never names the app PH.SwiftEdit outside repository and release-archive references")
    func nNoLegacyAppName() {
        // GIVEN the README lines that mention PH.SwiftEdit
        let lines = AuditReportFitness.read("README.md").components(separatedBy: "\n").filter { $0.contains("PH.SwiftEdit") }
        // WHEN each mention is classified
        let illegitimate = lines.filter { !$0.contains("paonath/PH.SwiftEdit") && !$0.contains("PH.SwiftEdit-<") && !$0.contains("cd PH.SwiftEdit") }
        // THEN only the repository path, the release archive name and the clone folder remain
        #expect(illegitimate.isEmpty, "\(illegitimate)")
        #expect(!AuditReportFitness.read("README.md").contains("PH.SwiftEdit.app"))
    }
}
