import Foundation

/// Immutable diagnostic describing a constitutional metadata, Bare-Bones budget, or security-floor violation (`SDD-004..009`, `SEC-003..004`).
public struct ConstitutionGovernanceViolation: Sendable, Equatable {
    public let filePath: String
    public let ruleID: String
    public let reason: String

    /// Creates a typed constitutional governance violation.
    /// - Parameters:
    ///   - filePath: Relative governance path within `openspec/` where the violation occurred.
    ///   - ruleID: Constitutional rule identifier (`SDD-004`, `SDD-006`, `SDD-007`, `SDD-009`, `UI-001`, `DATA-004`, `SEC-004`).
    ///   - reason: Actionable diagnostic explaining why the invariant failed.
    public init(filePath: String, ruleID: String, reason: String) {
        self.filePath = filePath
        self.ruleID = ruleID
        self.reason = reason
    }
}

/// Aggregated outcome of evaluating `openspec/Constitution.md` and its area mini-indexes (`SDD-004..009`).
public struct ConstitutionValidationSummary: Sendable, Equatable {
    public let version: String
    public let singleReferenceLock: Bool
    public let violations: [ConstitutionGovernanceViolation]

    /// Creates an immutable summary of constitutional root validation.
    /// - Parameters:
    ///   - version: Parsed SemVer string from `Constitution.md` frontmatter.
    ///   - singleReferenceLock: Whether `single_reference_lock: true` is active in frontmatter (`SDD-009`).
    ///   - violations: Ordered list of detected governance or security-floor violations.
    public init(version: String, singleReferenceLock: Bool, violations: [ConstitutionGovernanceViolation]) {
        self.version = version
        self.singleReferenceLock = singleReferenceLock
        self.violations = violations
    }
}

/// Pure `Foundation` static governance fitness analyzer enforcing `Constitution.md` `v1.5.0`, Bare-Bones token budgets, and active security floors (`AR-002`, `TEST-006`).
public enum ConstitutionGovernanceValidator {
    /// `1.5.0` amends `SEC-001` & `SEC-004` (MINOR): allow macOS `network.client` for manual GitHub Releases HTTPS check and expand allowlisted macOS terminals.
    private static let expectedConstitutionVersion = "1.5.0"
    private static let maxConstitutionLines = 45
    private static let maxMiniIndexLines = 25
    private static let maxMicroFileLines = 40
    private static let maxGovernanceFileBytes = 1_048_576
    private static let requiredMiniIndexRelativePaths = [
        "03-ui-ux/index.md",
        "04-data-persistence/index.md",
        "07-security-privacy/index.md",
    ]
    private static let mandatoryActiveAreas = [
        "06-testing-fitness/",
        "07-security-privacy/",
        "08-sdd-governance/",
    ]
    private static let requiredUI001Tokens = [
        "collapsed",
        "Open Folder",
        "EditorTabStrip",
        "LineNumberGutterView",
        "Character count",
    ]
    private static let requiredDATA004Tokens = [
        "LF",
        "CRLF",
        "`CR`",
        "10",
        "MRU",
    ]
    /// Mandatory `SEC-004` (`v1.3.0`) clauses preventing socket exfiltration, `Foundation.Process` spawning, and `CWE-78` `.command`/`.sh` script execution in Terminal/iTerm2.
    private static let requiredSEC004Tokens = [
        "100% offline",
        "zero socket",
        "zero subprocesses",
        "symlink-confined",
        "directory-only",
        "Finder",
        "com.googlecode.iterm2",
        "com.apple.Terminal",
    ]

    /// Reads and validates `openspec/Constitution.md` and affected area mini-indexes from disk.
    /// - Parameter openspecRoot: Root `openspec/` directory URL.
    /// - Returns: Parsed `ConstitutionValidationSummary` containing version, lock state, and any violations.
    /// - Throws: `DomainError.fileTooLarge` above `1 MiB`, `DomainError.unsupportedEncoding` for non-UTF-8 bytes, or `DomainError.securityScopeViolation` on symlink escape.
    public static func validateConstitutionRoot(at openspecRoot: URL) throws -> ConstitutionValidationSummary {
        let canonicalRoot = openspecRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let constitutionURL = openspecRoot.appendingPathComponent("Constitution.md")
        let constitutionContent = try readConfinedUTF8File(at: constitutionURL, canonicalRootPath: canonicalRoot)

        var miniIndexes: [String: String] = [:]
        for relativePath in requiredMiniIndexRelativePaths {
            let indexURL = openspecRoot
                .appendingPathComponent("constitution")
                .appendingPathComponent(relativePath)
            miniIndexes[relativePath] = try readConfinedUTF8File(at: indexURL, canonicalRootPath: canonicalRoot)
        }

        return validateConstitutionManifest(content: constitutionContent, miniIndexes: miniIndexes)
    }

    /// Reads and validates the amended `UI-001`, `DATA-004`, and `SEC-004` Bare-Bones micro-files under `openspec/constitution/`.
    /// - Parameter openspecRoot: Root `openspec/` directory URL.
    /// - Returns: Violations for Bare-Bones formatting (`SDD-004`) or missing `v1.3.0` domain/security tokens.
    /// - Throws: `DomainError.securityScopeViolation` on symlink escape, `DomainError.fileTooLarge` above `1 MiB`, or `DomainError.unsupportedEncoding`.
    public static func validateAmendedMicroFiles(at openspecRoot: URL) throws -> [ConstitutionGovernanceViolation] {
        let canonicalRoot = openspecRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let constitutionDir = openspecRoot.appendingPathComponent("constitution")
        let uiTokens = try readConfinedUTF8File(
            at: constitutionDir.appendingPathComponent("03-ui-ux/design-system-and-tokens.md"),
            canonicalRootPath: canonicalRoot
        )
        let dataStorage = try readConfinedUTF8File(
            at: constitutionDir.appendingPathComponent("04-data-persistence/storage-and-migrations.md"),
            canonicalRootPath: canonicalRoot
        )
        let securityBoundaries = try readConfinedUTF8File(
            at: constitutionDir.appendingPathComponent("07-security-privacy/authn-authz-and-boundaries.md"),
            canonicalRootPath: canonicalRoot
        )
        return validateAmendedMicroFiles(
            uiDesignTokens: uiTokens,
            dataStorage: dataStorage,
            securityBoundaries: securityBoundaries
        )
    }

    /// Evaluates in-memory `UI-001`, `DATA-004`, and `SEC-004` micro-file Markdown payloads against Bare-Bones (`<= 40` lines, zero `>` blockquotes) and `v1.3.0` rule clauses.
    /// - Parameters:
    ///   - uiDesignTokens: UTF-8 text of `03-ui-ux/design-system-and-tokens.md`.
    ///   - dataStorage: UTF-8 text of `04-data-persistence/storage-and-migrations.md`.
    ///   - securityBoundaries: UTF-8 text of `07-security-privacy/authn-authz-and-boundaries.md`.
    /// - Returns: Ordered list of `ConstitutionGovernanceViolation` items (`empty` when compliant).
    public static func validateAmendedMicroFiles(
        uiDesignTokens: String,
        dataStorage: String,
        securityBoundaries: String
    ) -> [ConstitutionGovernanceViolation] {
        var violations: [ConstitutionGovernanceViolation] = []
        let uiPath = "03-ui-ux/design-system-and-tokens.md"
        let dataPath = "04-data-persistence/storage-and-migrations.md"
        let secPath = "07-security-privacy/authn-authz-and-boundaries.md"

        let uiLines = splitLines(uiDesignTokens)
        let dataLines = splitLines(dataStorage)
        let secLines = splitLines(securityBoundaries)

        validateMicroFileBareBones(lines: uiLines, filePath: uiPath, into: &violations)
        validateMicroFileBareBones(lines: dataLines, filePath: dataPath, into: &violations)
        validateMicroFileBareBones(lines: secLines, filePath: secPath, into: &violations)

        validateRuleTokens(
            ruleID: "UI-001",
            filePath: uiPath,
            lines: uiLines,
            requiredTokens: requiredUI001Tokens,
            into: &violations
        )
        validateRuleTokens(
            ruleID: "DATA-004",
            filePath: dataPath,
            lines: dataLines,
            requiredTokens: requiredDATA004Tokens,
            into: &violations
        )
        validateRuleTokens(
            ruleID: "SEC-004",
            filePath: secPath,
            lines: secLines,
            requiredTokens: requiredSEC004Tokens,
            into: &violations
        )

        return violations
    }

    /// Verifies that a Bare-Bones single-line `- **<ruleID>**:` rule exists and contains every normative `v1.3.0` domain or `CWE-78` security token.
    private static func validateRuleTokens(
        ruleID: String,
        filePath: String,
        lines: [String],
        requiredTokens: [String],
        into violations: inout [ConstitutionGovernanceViolation]
    ) {
        guard let ruleLine = extractRuleLine(id: ruleID, from: lines) else {
            violations.append(ConstitutionGovernanceViolation(
                filePath: filePath,
                ruleID: ruleID,
                reason: "Missing single-line '- **\(ruleID)**:' declaration in '\(filePath)'"
            ))
            return
        }
        for token in requiredTokens where !ruleLine.contains(token) {
            violations.append(ConstitutionGovernanceViolation(
                filePath: filePath,
                ruleID: ruleID,
                reason: "\(ruleID) is missing required v1.3.0 normative token '\(token)'"
            ))
        }
    }

    private static func validateMicroFileBareBones(
        lines: [String],
        filePath: String,
        into violations: inout [ConstitutionGovernanceViolation]
    ) {
        validateLineBudget(lines: lines, maxLines: maxMicroFileLines, filePath: filePath, into: &violations)
        if lines.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(">") }) {
            violations.append(ConstitutionGovernanceViolation(
                filePath: filePath,
                ruleID: "SDD-004",
                reason: "Bare-Bones micro-file '\(filePath)' must not contain Markdown blockquotes ('>')"
            ))
        }
    }

    private static func extractRuleLine(id: String, from lines: [String]) -> String? {
        lines.first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- **\(id)**:") }
    }

    /// Evaluates in-memory `Constitution.md` and mini-index Markdown text against `v1.3.0` Bare-Bones and SemVer invariants.
    /// - Parameters:
    ///   - content: UTF-8 text of `openspec/Constitution.md`.
    ///   - miniIndexes: Map from relative area index path (e.g. `03-ui-ux/index.md`) to UTF-8 Markdown content.
    /// - Returns: Validation summary with all detected `SDD-004`..`SDD-009` violations.
    public static func validateConstitutionManifest(
        content: String,
        miniIndexes: [String: String]
    ) -> ConstitutionValidationSummary {
        var violations: [ConstitutionGovernanceViolation] = []
        let lines = splitLines(content)
        validateLineBudget(
            lines: lines,
            maxLines: maxConstitutionLines,
            filePath: "Constitution.md",
            into: &violations
        )

        let frontmatter = parseFrontmatterScalars(from: lines)
        let version = frontmatter["version"] ?? ""
        let singleReferenceLock = (frontmatter["single_reference_lock"] == "true")

        if !singleReferenceLock {
            violations.append(ConstitutionGovernanceViolation(
                filePath: "Constitution.md",
                ruleID: "SDD-009",
                reason: "Constitution.md must maintain single_reference_lock: true (SDD-009)"
            ))
        }

        if version != expectedConstitutionVersion {
            violations.append(ConstitutionGovernanceViolation(
                filePath: "Constitution.md",
                ruleID: "SDD-006",
                reason: "Expected version \(expectedConstitutionVersion) in Constitution.md frontmatter, found '\(version)'"
            ))
        }

        let areaStatuses = parseRoutingMatrixStatuses(from: lines)
        for requiredArea in mandatoryActiveAreas {
            if areaStatuses[requiredArea] != "active" {
                violations.append(ConstitutionGovernanceViolation(
                    filePath: "Constitution.md",
                    ruleID: "SDD-007",
                    reason: "Mandatory governance/security area '\(requiredArea)' must remain status: active (SDD-007)"
                ))
            }
        }

        let hasV130SyncRow = lines.contains { line in
            line.contains("| `1.3.0` |")
                && line.contains("UI-001")
                && line.contains("DATA-004")
                && line.contains("SEC-004")
        }
        if !hasV130SyncRow {
            violations.append(ConstitutionGovernanceViolation(
                filePath: "Constitution.md",
                ruleID: "SDD-006",
                reason: "Missing 1.3.0 Sync Impact Report row citing UI-001, DATA-004, and SEC-004"
            ))
        }

        let hasV140SyncRow = lines.contains { line in
            line.contains("| `1.4.0` |") && line.contains("UI-002")
        }
        if !hasV140SyncRow {
            violations.append(ConstitutionGovernanceViolation(
                filePath: "Constitution.md",
                ruleID: "SDD-006",
                reason: "Missing 1.4.0 Sync Impact Report row citing UI-002"
            ))
        }

        let hasV150SyncRow = lines.contains { line in
            line.contains("| `1.5.0` |") && line.contains("SEC-001") && line.contains("SEC-004")
        }
        if !hasV150SyncRow {
            violations.append(ConstitutionGovernanceViolation(
                filePath: "Constitution.md",
                ruleID: "SDD-006",
                reason: "Missing 1.5.0 Sync Impact Report row citing SEC-001 and SEC-004"
            ))
        }

        for (indexPath, indexContent) in miniIndexes.sorted(by: { $0.key < $1.key }) {
            validateLineBudget(
                lines: splitLines(indexContent),
                maxLines: maxMiniIndexLines,
                filePath: indexPath,
                into: &violations
            )
        }

        return ConstitutionValidationSummary(
            version: version,
            singleReferenceLock: singleReferenceLock,
            violations: violations
        )
    }

    private static func parseFrontmatterScalars(from lines: [String]) -> [String: String] {
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return [:]
        }
        var scalars: [String: String] = [:]
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                break
            }
            guard let colonIndex = trimmed.firstIndex(of: ":") else {
                continue
            }
            let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colonIndex)...])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            scalars[key] = value
        }
        return scalars
    }

    private static func validateLineBudget(
        lines: [String],
        maxLines: Int,
        filePath: String,
        into violations: inout [ConstitutionGovernanceViolation]
    ) {
        if lines.count > maxLines {
            violations.append(ConstitutionGovernanceViolation(
                filePath: filePath,
                ruleID: "SDD-004",
                reason: "'\(filePath)' has \(lines.count) lines, exceeding Bare-Bones cap of \(maxLines)"
            ))
        }
    }

    /// Parses the Markdown `Routing Matrix` table into an `[area: status]` map so `SDD-007` floor checks tolerate column-width edits without false positives.
    private static func parseRoutingMatrixStatuses(from lines: [String]) -> [String: String] {
        var statuses: [String: String] = [:]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("|") else { continue }
            let columns = trimmed
                .split(separator: "|", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "`")) }
            guard columns.count >= 3, columns[0].hasSuffix("/") else { continue }
            statuses[columns[0]] = columns[2]
        }
        return statuses
    }

    /// Reads UTF-8 Markdown while enforcing `resolvingSymlinksInPath()` confinement inside `canonicalRootPath` (`CWE-22`/`CWE-59`, `SEC-003`) and a `1 MiB` DoS size ceiling (`CWE-400`).
    private static func readConfinedUTF8File(at url: URL, canonicalRootPath: String) throws -> String {
        let resolvedPath = url.standardizedFileURL.resolvingSymlinksInPath().path
        let rootPrefix = canonicalRootPath.hasSuffix("/") ? canonicalRootPath : canonicalRootPath + "/"
        guard resolvedPath.hasPrefix(rootPrefix) else {
            throw DomainError.securityScopeViolation(path: url.path)
        }
        let data = try Data(contentsOf: url)
        guard data.count <= maxGovernanceFileBytes else {
            throw DomainError.fileTooLarge(byteCount: UInt64(data.count))
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw DomainError.unsupportedEncoding
        }
        return text
    }

    private static func splitLines(_ content: String) -> [String] {
        var lines = content.components(separatedBy: "\n")
        if lines.last == "" {
            lines.removeLast()
        }
        return lines
    }
}
