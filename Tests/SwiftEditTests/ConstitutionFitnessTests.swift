import Foundation
import Testing
@testable import SwiftEditCore

/// Verifies `openspec/Constitution.md` (`v1.4.0`, `UI-002` amendment on top of the `v1.3.0` invariants), Bare-Bones token budgets (`SDD-004`), `SDD-007` security floors, and `UI-001`/`DATA-004`/`SEC-004` (`CWE-78` directory-only Terminal confinement) invariants.
@Suite("ConstitutionFitnessTests")
struct ConstitutionFitnessTests {

    private static var openspecRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("openspec")
    }

    @Test("P3: openspec/Constitution.md v1.5.0 with SEC-001/SEC-004 amendment and area mini-indexes satisfy SemVer, Single-Reference Lock, line caps, and Sync Impact Report")
    func p3ConstitutionRootV140AndMiniIndexesPassFitness() throws {
        // GIVEN the live repository openspec/ directory
        let openspecRoot = Self.openspecRootURL

        // WHEN validating the constitutional root manifest and area mini-indexes
        let summary = try ConstitutionGovernanceValidator.validateConstitutionRoot(at: openspecRoot)

        // THEN version is 1.6.0, Single-Reference Lock is enabled, and zero governance violations exist
        #expect(summary.version == "1.6.0")
        #expect(summary.singleReferenceLock == true)
        #expect(summary.violations.isEmpty)
    }

    @Test("N5: validateConstitutionManifest rejects stale v1.3.0 version, missing 1.4.0 UI-002 / 1.5.0 SEC Sync Impact rows, and Bare-Bones line-cap overflows")
    func n5StaleVersionMissingUI002RowOrLineCapOverflowFailsValidation() {
        // GIVEN a stale v1.3.0 Constitution.md without the 1.4.0 UI-002 row, exceeding 45 lines, and a mini-index exceeding 25 lines
        let paddedTrailingLines = Array(repeating: "", count: 40).joined(separator: "\n")
        let staleManifest = """
        ---
        project_name: "PH.SwiftEdit"
        version: "1.3.0"
        single_reference_lock: true
        ---
        # Constitution: PH.SwiftEdit
        ## Routing Matrix
        | Area | Prefix | Status | Index | Owners | Scope & Core Tenet |
        | :--- | :--- | :--- | :--- | :--- | :--- |
        | `06-testing-fitness/` | `TEST` | `active` | `constitution/06-testing-fitness/index.md` | `swift-macos-expert` | TDD |
        | `07-security-privacy/` | `SEC` | `active` | `constitution/07-security-privacy/index.md` | `cyber-security-expert` | Sandbox |
        | `08-sdd-governance/` | `SDD` | `active` | `constitution/08-sdd-governance/index.md` | `spec-sdlc-expert` | SDD |
        ## Sync Impact Report
        | Version | Date | Touched Rules | Sync Status |
        | :--- | :--- | :--- | :--- |
        | `1.3.0` | `2026-11-18` | `UI-001, DATA-004, SEC-004` | `index.yml synced` |
        \(paddedTrailingLines)
        """
        let oversizedMiniIndex = Array(repeating: "# line", count: 27).joined(separator: "\n")

        // WHEN validating the stale manifest and oversized mini-index
        let summary = ConstitutionGovernanceValidator.validateConstitutionManifest(
            content: staleManifest,
            miniIndexes: ["03-ui-ux/index.md": oversizedMiniIndex]
        )

        // THEN violations flag stale version (SDD-006), missing 1.4.0/1.5.0 sync rows (SDD-006), and line-cap overflows (SDD-004)
        #expect(summary.version == "1.3.0")
        #expect(summary.violations.count >= 5)
        #expect(summary.violations.contains { $0.ruleID == "SDD-006" && $0.reason.contains("Expected version 1.6.0") })
        #expect(summary.violations.contains { $0.ruleID == "SDD-006" && $0.reason.contains("1.4.0 Sync Impact Report row citing UI-002") })
        #expect(summary.violations.contains { $0.ruleID == "SDD-006" && $0.reason.contains("1.5.0 Sync Impact Report row citing SEC-001") })
        #expect(summary.violations.contains { $0.ruleID == "SDD-004" && $0.filePath == "Constitution.md" })
        #expect(summary.violations.contains { $0.ruleID == "SDD-004" && $0.filePath == "03-ui-ux/index.md" })
    }

    @Test("N2 [Security]: validateConstitutionManifest and validateConstitutionRoot reject downgraded SDD-007 security/governance areas, disabled Single-Reference Lock, and escaping symlinks")
    func n2SecurityActiveGovernanceAndSecurityAreasCannotBeDowngraded() throws {
        // GIVEN a tampered v1.3.0 Constitution.md disabling single_reference_lock and downgrading 06/07/08 areas, plus a symlinked openspec root
        let tamperedManifest = """
        ---
        project_name: "PH.SwiftEdit"
        version: "1.3.0"
        single_reference_lock: false
        ---
        # Constitution: PH.SwiftEdit
        ## Routing Matrix
        | Area | Prefix | Status | Index | Owners | Scope & Core Tenet |
        | :--- | :--- | :--- | :--- | :--- | :--- |
        | `06-testing-fitness/` | `TEST` | `not-applicable` | `constitution/06-testing-fitness/index.md` | `swift-macos-expert` | TDD |
        | `07-security-privacy/` | `SEC` | `not-applicable` | `constitution/07-security-privacy/index.md` | `cyber-security-expert` | Sandbox |
        | `08-sdd-governance/` | `SDD` | `not-applicable` | `constitution/08-sdd-governance/index.md` | `spec-sdlc-expert` | SDD |
        ## Sync Impact Report
        | Version | Date | Touched Rules | Sync Status |
        | :--- | :--- | :--- | :--- |
        | `1.3.0` | `2026-11-18` | `UI-001, DATA-004, SEC-004` | `index.yml synced` |
        """
        let scratchBase = Self.openspecRootURL
            .deletingLastPathComponent()
            .appendingPathComponent(".tmp/test-results/constitution-sec-\(UUID().uuidString)")
        let fakeOpenspec = scratchBase.appendingPathComponent("openspec")
        let outsideFile = scratchBase.appendingPathComponent("outside-secret.md")
        try FileManager.default.createDirectory(at: fakeOpenspec, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratchBase) }
        try Data("outside".utf8).write(to: outsideFile)
        let symlinkConstitution = fakeOpenspec.appendingPathComponent("Constitution.md")
        try FileManager.default.createSymbolicLink(
            at: symlinkConstitution,
            withDestinationURL: outsideFile
        )

        // WHEN evaluating the tampered manifest and the symlinked openspec directory
        let summary = ConstitutionGovernanceValidator.validateConstitutionManifest(
            content: tamperedManifest,
            miniIndexes: [:]
        )

        // THEN SDD-009 and three SDD-007 security-floor violations are returned and symlink escape throws securityScopeViolation
        #expect(summary.singleReferenceLock == false)
        #expect(summary.violations.contains { $0.ruleID == "SDD-009" })
        #expect(summary.violations.filter { $0.ruleID == "SDD-007" }.count == 3)
        #expect(throws: DomainError.securityScopeViolation(path: symlinkConstitution.path)) {
            _ = try ConstitutionGovernanceValidator.validateConstitutionRoot(at: fakeOpenspec)
        }
    }

    @Test("P2: Amended v1.3.0 Bare-Bones micro-files UI-001, DATA-004, and SEC-004 pass line-cap, zero-blockquote, and domain invariant checks")
    func p2AmendedMicroFilesPassBareBonesAndV130Invariants() throws {
        // GIVEN the live repository openspec/ directory containing v1.3.0 micro-files
        let openspecRoot = Self.openspecRootURL

        // WHEN validating the amended UI-001, DATA-004, and SEC-004 micro-files
        let violations = try ConstitutionGovernanceValidator.validateAmendedMicroFiles(at: openspecRoot)

        // THEN zero Bare-Bones or v1.3.0 invariant violations are reported
        #expect(violations.isEmpty)
    }

    @Test("N3: validateAmendedMicroFiles rejects missing UI-001/DATA-004 v1.3.0 clauses, Markdown blockquotes, and > 40-line micro-files")
    func n3MissingV130ClausesBlockquoteOr40LineOverflowFailsCheck() {
        // GIVEN micro-files where UI-001 omits LineNumberGutterView/collapsed sidebar with a blockquote, DATA-004 omits CR and 10 MRU, and storage exceeds 40 lines
        let legacyUI = """
        ---
        area: "03-ui-ux"
        ---
        > Forbidden prose blockquote
        ## Rules
        - **UI-001**: The SwiftEditUI workspace shell SHALL render Purple chrome across Light, Black, and Auto modes.
        """
        let paddedDataLines = Array(repeating: "", count: 38).joined(separator: "\n")
        let legacyData = """
        ---
        area: "04-data-persistence"
        ---
        ## Rules
        - **DATA-004**: WHEN saving, the writer SHALL preserve LF or CRLF line endings.
        \(paddedDataLines)
        """
        let compliantSec = """
        ---
        area: "07-security-privacy"
        ---
        ## Rules
        - **SEC-004**: The application runtime on macOS and iOS SHALL execute 100% offline with zero socket connections and zero subprocesses while restricting external handoffs to user-confirmed https, http, or mailto URIs and symlink-confined NSWorkspace Finder reveals or verified directory-only Terminal launches (com.googlecode.iterm2, com.apple.Terminal).
        """

        // WHEN validating the legacy/malformed micro-file fixtures
        let violations = ConstitutionGovernanceValidator.validateAmendedMicroFiles(
            uiDesignTokens: legacyUI,
            dataStorage: legacyData,
            securityBoundaries: compliantSec
        )

        // THEN violations flag UI-001, DATA-004, and SDD-004 blockquote + >40-line infractions
        #expect(violations.contains { $0.ruleID == "UI-001" })
        #expect(violations.contains { $0.ruleID == "DATA-004" })
        #expect(violations.filter { $0.ruleID == "SDD-004" }.count >= 2)
    }

    @Test(
        "N4 [Security]: validateAmendedMicroFiles rejects SEC-004 rules omitting offline, zero-subprocess, symlink, or directory-only Terminal allowlist guards",
        arguments: [
            "100% offline",
            "zero socket",
            "zero subprocesses",
            "symlink-confined",
            "directory-only",
            "Finder",
            "com.googlecode.iterm2",
            "com.apple.Terminal",
        ]
    )
    func n4SecuritySEC004RejectsMissingZeroSubprocessOrDirectoryOnlyTerminalGuards(omittedGuardToken: String) {
        // GIVEN compliant UI-001 and DATA-004 fixtures alongside a weakened SEC-004 fixture omitting a mandatory CWE-78/SEC-004 guard token
        let compliantUI = "- **UI-001**: collapsed until Open Folder, EditorTabStrip, LineNumberGutterView, Character count SHALL render."
        let compliantData = "- **DATA-004**: SHALL preserve LF, CRLF, `CR`, and 10 MRU bookmarks."
        let fullSec004 = "- **SEC-004**: SHALL execute 100% offline with zero socket connections and zero subprocesses via symlink-confined Finder or directory-only Terminal (com.googlecode.iterm2, com.apple.Terminal)."
        let weakenedSec = fullSec004.replacingOccurrences(of: omittedGuardToken, with: "REDACTED")

        // WHEN validating the micro-files with the weakened SEC-004 rule
        let violations = ConstitutionGovernanceValidator.validateAmendedMicroFiles(
            uiDesignTokens: compliantUI,
            dataStorage: compliantData,
            securityBoundaries: weakenedSec
        )

        // THEN validation fails closed with a SEC-004 violation identifying the omitted security token
        #expect(violations.count == 1)
        #expect(violations.first?.ruleID == "SEC-004")
        #expect(violations.first?.reason.contains(omittedGuardToken) == true)
    }
}
