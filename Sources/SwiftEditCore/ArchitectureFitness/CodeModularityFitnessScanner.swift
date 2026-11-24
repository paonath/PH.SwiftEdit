import Foundation

/// Immutable modularity budgets (`<= 800` file lines, `<= 400` nominal block lines, `<= 25` nominal members, `<= 4 MiB` file size) enforced across production Swift sources to prevent God Classes and God Files (`REQ-001`, `TEST-006`, `SEC-012`).
public struct CodeModularityBudgets: Equatable, Sendable {
    public let maxFileLines: Int
    public let maxNominalBlockLines: Int
    public let maxNominalMembers: Int
    public let maxFileBytes: Int

    public static let `default` = CodeModularityBudgets(
        maxFileLines: 800,
        maxNominalBlockLines: 400,
        maxNominalMembers: 25,
        maxFileBytes: 4 * 1024 * 1024
    )

    public init(
        maxFileLines: Int = 800,
        maxNominalBlockLines: Int = 400,
        maxNominalMembers: Int = 25,
        maxFileBytes: Int = 4 * 1024 * 1024
    ) {
        self.maxFileLines = maxFileLines
        self.maxNominalBlockLines = maxNominalBlockLines
        self.maxNominalMembers = maxNominalMembers
        self.maxFileBytes = maxFileBytes
    }
}

/// Typed modularity, complexity, graph, or security boundary violation emitted by `CodeModularityFitnessScanner` (`TEST-006`, `SEC-003`, `SEC-012`).
public struct CodeModularityViolation: Equatable, Sendable, CustomStringConvertible {
    public enum Kind: String, Equatable, Sendable {
        case fileLineCount
        case nominalBlockLineCount
        case nominalMemberCount
        case circularFileDependency
        case methodCyclomaticComplexity
        case methodCognitiveComplexity
        case callGraphRecursion
        case deadPrivateSymbol
        case fileDependencyDepth
        case securityBoundaryViolation
    }

    public let filePath: String
    public let symbolName: String?
    public let kind: Kind
    public let observed: Int
    public let limit: Int
    public let reason: String

    public init(
        filePath: String,
        symbolName: String? = nil,
        kind: Kind,
        observed: Int,
        limit: Int,
        reason: String
    ) {
        self.filePath = filePath
        self.symbolName = symbolName
        self.kind = kind
        self.observed = observed
        self.limit = limit
        self.reason = reason
    }

    public var description: String {
        if let symbolName {
            return "\(filePath) [\(symbolName)] (\(kind.rawValue)): \(reason) (observed \(observed), limit \(limit))"
        }
        return "\(filePath) (\(kind.rawValue)): \(reason) (observed \(observed), limit \(limit))"
    }
}

/// Pure-`Foundation` static Swift modularity and graph fitness scanner enforcing `<= 800` file lines, `<= 400` nominal block lines, attribute-aware `<= 25` nominal members, `<= 4 MiB` DoS byte caps (`CWE-400`), and canonical symlink confinement (`CWE-22`, `REQ-001`, `AR-006`, `TEST-006`, `SEC-003`, `SEC-012`).
public enum CodeModularityFitnessScanner {

    fileprivate struct ActiveNominalBlock {
        let name: String
        let startLine: Int
        let bodyDepth: Int
        var memberCount: Int
    }

    /// Scans multiple production source directories and returns all modularity and security boundary violations.
    public static func scanDirectories(
        at directoryURLs: [URL],
        budgets: CodeModularityBudgets = .default
    ) throws -> [CodeModularityViolation] {
        var violations: [CodeModularityViolation] = []
        for directoryURL in directoryURLs {
            violations.append(contentsOf: try scanDirectory(at: directoryURL, budgets: budgets))
        }
        return violations
    }

    /// Scans every `.swift` file under `directoryURL`, rejecting parent-traversal URLs, symlinks escaping the canonical root, or files exceeding `budgets.maxFileBytes` fail-closed (`SEC-003`, `SEC-012`).
    public static func scanDirectory(
        at directoryURL: URL,
        budgets: CodeModularityBudgets = .default
    ) throws -> [CodeModularityViolation] {
        let collected = try collectValidatedSwiftSources(
            in: directoryURL,
            includeSourcePrefix: false,
            budgets: budgets
        )
        var violations = collected.violations
        for entry in collected.sources {
            violations.append(contentsOf: scanSource(content: entry.content, filePath: entry.filePath, budgets: budgets))
        }
        return violations
    }

    /// Shared multi-directory preflight collector enforcing canonical root confinement (`CWE-22`, `resolvingSymlinksInPath`), `../` parent-traversal rejection, and the `4 MiB` byte cap (`CWE-400`) before reading any UTF-8 bytes across modularity, acyclicity, recursion, complexity, and depth verifiers (`SEC-003`, `SEC-012`).
    public static func collectValidatedDirectorySources(
        at directoryURLs: [URL],
        budgets: CodeModularityBudgets = .default
    ) throws -> (sources: [(filePath: String, content: String)], violations: [CodeModularityViolation]) {
        var violations: [CodeModularityViolation] = []
        var sources: [(filePath: String, content: String)] = []
        for directoryURL in directoryURLs {
            let collected = try collectValidatedSwiftSources(
                in: directoryURL,
                includeSourcePrefix: true,
                budgets: budgets
            )
            violations.append(contentsOf: collected.violations)
            sources.append(contentsOf: collected.sources)
        }
        sources.sort { $0.filePath < $1.filePath }
        return (sources, violations)
    }

    /// Shared fail-closed directory enumeration enforcing `../` parent-traversal rejection, canonical root confinement (`resolvingSymlinksInPath`) for both file and directory symlinks, and the `4 MiB` byte cap before reading UTF-8 text (`SEC-003`, `SEC-012`).
    internal static func collectValidatedSwiftSources(
        in directoryURL: URL,
        includeSourcePrefix: Bool,
        budgets: CodeModularityBudgets
    ) throws -> (sources: [(filePath: String, content: String)], violations: [CodeModularityViolation]) {
        if let dirTraversalViolation = directoryRootTraversalCheck(directoryURL: directoryURL) {
            return ([], [dirTraversalViolation])
        }
        let canonicalRoot = directoryURL.resolvingSymlinksInPath().standardizedFileURL
        let rootPrefix = canonicalRoot.path.hasSuffix("/") ? canonicalRoot.path : canonicalRoot.path + "/"
        let targetPrefix = canonicalRoot.lastPathComponent
        var violations: [CodeModularityViolation] = []
        var sources: [(filePath: String, content: String)] = []

        guard let enumerator = FileManager.default.enumerator(
            at: canonicalRoot,
            includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ([], [])
        }

        for case let candidateURL as URL in enumerator {
            try modularityInspectEnumeratedCandidate(
                candidateURL,
                canonicalRoot: canonicalRoot,
                rootPrefix: rootPrefix,
                targetPrefix: targetPrefix,
                includeSourcePrefix: includeSourcePrefix,
                maxFileBytes: budgets.maxFileBytes,
                sources: &sources,
                violations: &violations
            )
        }
        return (sources, violations)
    }

    private static func modularityInspectEnumeratedCandidate(
        _ candidateURL: URL,
        canonicalRoot: URL,
        rootPrefix: String,
        targetPrefix: String,
        includeSourcePrefix: Bool,
        maxFileBytes: Int,
        sources: inout [(filePath: String, content: String)],
        violations: inout [CodeModularityViolation]
    ) throws {
        let reportedPath = modularityReportedPath(
            for: candidateURL,
            rootPrefix: rootPrefix,
            targetPrefix: targetPrefix,
            includeSourcePrefix: includeSourcePrefix
        )
        if let symlinkViolation = modularityEscapingSymlinkViolation(
            for: candidateURL,
            canonicalRoot: canonicalRoot,
            rootPrefix: rootPrefix,
            reportedPath: reportedPath
        ) {
            violations.append(symlinkViolation)
            return
        }
        guard candidateURL.pathExtension == "swift" else { return }

        if let boundaryViolation = preflightSecurityCheck(
            candidateURL: candidateURL,
            canonicalRoot: canonicalRoot,
            rootPrefix: rootPrefix,
            relativePath: reportedPath,
            maxFileBytes: maxFileBytes
        ) {
            violations.append(boundaryViolation)
            return
        }

        let resolvedURL = candidateURL.resolvingSymlinksInPath().standardizedFileURL
        let content = try String(contentsOf: resolvedURL, encoding: .utf8)
        sources.append((filePath: reportedPath, content: content))
    }

    private static func modularityReportedPath(
        for candidateURL: URL,
        rootPrefix: String,
        targetPrefix: String,
        includeSourcePrefix: Bool
    ) -> String {
        let relativeSuffix = candidateURL.path.hasPrefix(rootPrefix)
            ? String(candidateURL.path.dropFirst(rootPrefix.count))
            : candidateURL.lastPathComponent
        return includeSourcePrefix ? "Sources/\(targetPrefix)/\(relativeSuffix)" : relativeSuffix
    }

    private static func modularityEscapingSymlinkViolation(
        for candidateURL: URL,
        canonicalRoot: URL,
        rootPrefix: String,
        reportedPath: String
    ) -> CodeModularityViolation? {
        let resourceValues = try? candidateURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard resourceValues?.isSymbolicLink == true else { return nil }
        let resolvedPath = candidateURL.resolvingSymlinksInPath().standardizedFileURL.path
        guard resolvedPath != canonicalRoot.path && !resolvedPath.hasPrefix(rootPrefix) else {
            return nil
        }
        return CodeModularityViolation(
            filePath: reportedPath,
            kind: .securityBoundaryViolation,
            observed: 1,
            limit: 0,
            reason: "Symbolic link escapes canonical root directory"
        )
    }

    internal static func directoryRootTraversalCheck(directoryURL: URL) -> CodeModularityViolation? {
        // Inspect raw path string before standardizedFileURL collapses `..` segments.
        let rawSegments = directoryURL.path.split(separator: "/")
        if rawSegments.contains("..") {
            return CodeModularityViolation(
                filePath: directoryURL.path,
                kind: .securityBoundaryViolation,
                observed: 1,
                limit: 0,
                reason: "Parent traversal segment rejected fail-closed"
            )
        }
        return nil
    }

    internal static func preflightSecurityCheck(
        candidateURL: URL,
        canonicalRoot: URL,
        rootPrefix: String,
        relativePath: String,
        maxFileBytes: Int
    ) -> CodeModularityViolation? {
        if candidateURL.pathComponents.contains("..") || candidateURL.path.split(separator: "/").contains("..") {
            return CodeModularityViolation(
                filePath: relativePath,
                kind: .securityBoundaryViolation,
                observed: 1,
                limit: 0,
                reason: "Parent traversal segment rejected fail-closed"
            )
        }

        let resourceValues = try? candidateURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
        if resourceValues?.isSymbolicLink == true {
            let resolvedPath = candidateURL.resolvingSymlinksInPath().standardizedFileURL.path
            if resolvedPath != canonicalRoot.path && !resolvedPath.hasPrefix(rootPrefix) {
                return CodeModularityViolation(
                    filePath: relativePath,
                    kind: .securityBoundaryViolation,
                    observed: 1,
                    limit: 0,
                    reason: "Symbolic link escapes canonical root directory"
                )
            }
        }

        let resolvedURL = candidateURL.resolvingSymlinksInPath().standardizedFileURL
        if resolvedURL.path != canonicalRoot.path && !resolvedURL.path.hasPrefix(rootPrefix) {
            return CodeModularityViolation(
                filePath: relativePath,
                kind: .securityBoundaryViolation,
                observed: 1,
                limit: 0,
                reason: "Resolved path escapes canonical root directory"
            )
        }

        let fileSize = resourceValues?.fileSize ?? ((try? FileManager.default.attributesOfItem(atPath: resolvedURL.path)[.size] as? Int) ?? 0)
        if fileSize > maxFileBytes {
            return CodeModularityViolation(
                filePath: relativePath,
                kind: .securityBoundaryViolation,
                observed: fileSize,
                limit: maxFileBytes,
                reason: "Source file exceeds maximum static scan size cap"
            )
        }
        return nil
    }

    /// Scans Swift source text for file line count, nominal declaration/extension block line count, and attribute-aware declared member count budgets (`REQ-001`).
    public static func scanSource(
        content: String,
        filePath: String,
        budgets: CodeModularityBudgets = .default
    ) -> [CodeModularityViolation] {
        let rawLines = content.components(separatedBy: "\n")
        var violations: [CodeModularityViolation] = []

        if rawLines.count > budgets.maxFileLines {
            violations.append(CodeModularityViolation(
                filePath: filePath,
                kind: .fileLineCount,
                observed: rawLines.count,
                limit: budgets.maxFileLines,
                reason: "Production Swift file exceeds \(budgets.maxFileLines)-line modularity budget"
            ))
        }

        let stripped = stripCommentsAndStringsPreservingNewlines(from: content)
        var braceDepth = 0
        var activeBlocks: [ActiveNominalBlock] = []
        var pendingNominal: (name: String, startLine: Int)?

        for (zeroIndex, line) in stripped.components(separatedBy: "\n").enumerated() {
            modularityProcessStrippedLine(
                line,
                lineNumber: zeroIndex + 1,
                filePath: filePath,
                budgets: budgets,
                braceDepth: &braceDepth,
                activeBlocks: &activeBlocks,
                pendingNominal: &pendingNominal,
                violations: &violations
            )
        }
        return violations
    }

    /// Strips single-line comments, nested block comments, and string literals while preserving `\n` count so line numbers remain exact.
    internal static func stripCommentsAndStringsPreservingNewlines(from source: String) -> String {
        let chars = Array(source)
        var out = ""
        out.reserveCapacity(chars.count)
        var index = 0
        var state = ModularityLexerState()

        while index < chars.count {
            modularityStepStripLexer(chars: chars, index: &index, state: &state, out: &out)
        }
        return out
    }
}

private extension CodeModularityFitnessScanner {
    static let memberDeclarationKeywords: Set<Substring> = [
        "func", "var", "let", "init", "deinit", "subscript",
    ]

    static let memberModifierParenthesizedTokens: Set<Substring> = [
        "unowned(safe)", "unowned(unsafe)", "nonisolated(unsafe)",
    ]

    static let memberInitializerPrefixes: [String] = [
        "init(", "init?(", "init!(", "init<", "deinit{", "subscript(", "subscript<",
    ]

    static func modularityProcessStrippedLine(
        _ line: String,
        lineNumber: Int,
        filePath: String,
        budgets: CodeModularityBudgets,
        braceDepth: inout Int,
        activeBlocks: inout [ActiveNominalBlock],
        pendingNominal: inout (name: String, startLine: Int)?,
        violations: inout [CodeModularityViolation]
    ) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let top = activeBlocks.last, braceDepth == top.bodyDepth, isMemberDeclaration(trimmed) {
            activeBlocks[activeBlocks.count - 1].memberCount += 1
        }
        if pendingNominal == nil, let declaredName = parseNominalDeclarationName(trimmed) {
            pendingNominal = (declaredName, lineNumber)
        }
        for ch in trimmed {
            modularityProcessBraceCharacter(
                ch,
                lineNumber: lineNumber,
                filePath: filePath,
                budgets: budgets,
                braceDepth: &braceDepth,
                activeBlocks: &activeBlocks,
                pendingNominal: &pendingNominal,
                violations: &violations
            )
        }
    }

    static func modularityProcessBraceCharacter(
        _ ch: Character,
        lineNumber: Int,
        filePath: String,
        budgets: CodeModularityBudgets,
        braceDepth: inout Int,
        activeBlocks: inout [ActiveNominalBlock],
        pendingNominal: inout (name: String, startLine: Int)?,
        violations: inout [CodeModularityViolation]
    ) {
        if ch == "{" {
            braceDepth += 1
            if let pending = pendingNominal {
                activeBlocks.append(ActiveNominalBlock(
                    name: pending.name,
                    startLine: pending.startLine,
                    bodyDepth: braceDepth,
                    memberCount: 0
                ))
                pendingNominal = nil
            }
        } else if ch == "}" {
            if let top = activeBlocks.last, braceDepth == top.bodyDepth {
                let finished = activeBlocks.removeLast()
                modularityEvaluateFinishedBlock(
                    finished,
                    endLine: lineNumber,
                    filePath: filePath,
                    budgets: budgets,
                    violations: &violations
                )
            }
            braceDepth = max(0, braceDepth - 1)
        }
    }

    static func modularityEvaluateFinishedBlock(
        _ finished: ActiveNominalBlock,
        endLine: Int,
        filePath: String,
        budgets: CodeModularityBudgets,
        violations: inout [CodeModularityViolation]
    ) {
        let blockLines = endLine - finished.startLine + 1
        if blockLines > budgets.maxNominalBlockLines {
            violations.append(CodeModularityViolation(
                filePath: filePath,
                symbolName: finished.name,
                kind: .nominalBlockLineCount,
                observed: blockLines,
                limit: budgets.maxNominalBlockLines,
                reason: "Nominal block exceeds \(budgets.maxNominalBlockLines)-line modularity budget"
            ))
        }
        if finished.memberCount > budgets.maxNominalMembers {
            violations.append(CodeModularityViolation(
                filePath: filePath,
                symbolName: finished.name,
                kind: .nominalMemberCount,
                observed: finished.memberCount,
                limit: budgets.maxNominalMembers,
                reason: "Nominal block exceeds \(budgets.maxNominalMembers)-member modularity budget"
            ))
        }
    }

    static func parseNominalDeclarationName(_ trimmed: String) -> String? {
        guard !trimmed.isEmpty, !trimmed.hasPrefix("return "), !trimmed.hasPrefix("let "), !trimmed.hasPrefix("var ") else {
            return nil
        }
        let nominalKeywords: Set<Substring> = ["class", "struct", "enum", "extension", "actor"]
        let tokens = trimmed.split(whereSeparator: modularityIsHorizontalWhitespace)
        for (idx, tok) in tokens.enumerated() where nominalKeywords.contains(tok) {
            guard idx + 1 < tokens.count else { return nil }
            let rawName = String(tokens[idx + 1])
            let cleaned = rawName.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
            return cleaned.isEmpty ? nil : String(cleaned)
        }
        return nil
    }

    static func isMemberDeclaration(_ trimmed: String) -> Bool {
        let strippedAttrs = stripLeadingAttributes(trimmed)
        guard !strippedAttrs.isEmpty else { return false }
        for tok in strippedAttrs.split(whereSeparator: modularityIsHorizontalWhitespace) {
            if let decision = modularityClassifyMemberToken(tok) {
                return decision
            }
        }
        return false
    }

    static func modularityClassifyMemberToken(_ tok: Substring) -> Bool? {
        if memberDeclarationKeywords.contains(tok) || modularityHasMemberPrefix(tok) {
            return true
        }
        if tok.hasSuffix("(set)") || memberModifierParenthesizedTokens.contains(tok) {
            return nil
        }
        if modularityContainsExpressionDelimiter(tok) {
            return false
        }
        return nil
    }

    static func modularityHasMemberPrefix(_ tok: Substring) -> Bool {
        memberInitializerPrefixes.contains { tok.hasPrefix($0) }
    }

    static func modularityContainsExpressionDelimiter(_ tok: Substring) -> Bool {
        tok.contains("{") || tok.contains("=") || tok.contains("(")
    }

    static func modularityIsHorizontalWhitespace(_ ch: Character) -> Bool {
        ch == " " || ch == "\t"
    }
}

private extension CodeModularityFitnessScanner {
    struct ModularityLexerState {
        var blockCommentDepth = 0
        var inLineComment = false
        var inString = false
    }

    /// Strips leading Swift `@Attribute` and `@Attribute(...)` prefixes on a single line so member declaration scanning is never short-circuited by attribute arguments (`REQ-001`).
    static func stripLeadingAttributes(_ line: String) -> String {
        let chars = Array(line)
        var index = 0
        while modularityConsumeNextLeadingAttribute(chars: chars, index: &index) {}
        guard index < chars.count else { return "" }
        return String(chars[index..<chars.count]).trimmingCharacters(in: .whitespaces)
    }

    static func modularityConsumeNextLeadingAttribute(chars: [Character], index: inout Int) -> Bool {
        modularitySkipHorizontalSpaces(chars: chars, index: &index)
        guard index < chars.count, chars[index] == "@" else { return false }
        index += 1
        while index < chars.count, modularityIsAttributeNameChar(chars[index]) {
            index += 1
        }
        modularitySkipHorizontalSpaces(chars: chars, index: &index)
        if index < chars.count, chars[index] == "(" {
            modularitySkipBalancedParens(chars: chars, index: &index)
        }
        return true
    }

    static func modularitySkipHorizontalSpaces(chars: [Character], index: inout Int) {
        while index < chars.count, modularityIsHorizontalWhitespace(chars[index]) {
            index += 1
        }
    }

    static func modularityIsAttributeNameChar(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "_" || ch == "."
    }

    static func modularitySkipBalancedParens(chars: [Character], index: inout Int) {
        var depth = 1
        index += 1
        while index < chars.count, depth > 0 {
            if chars[index] == "(" {
                depth += 1
            } else if chars[index] == ")" {
                depth -= 1
            }
            index += 1
        }
    }

    static func modularityStepStripLexer(
        chars: [Character],
        index: inout Int,
        state: inout ModularityLexerState,
        out: inout String
    ) {
        let c = chars[index]
        let next: Character? = (index + 1 < chars.count) ? chars[index + 1] : nil
        if state.inLineComment {
            if c == "\n" { state.inLineComment = false; out.append("\n") }
            index += 1
            return
        }
        if state.blockCommentDepth > 0 {
            modularityStepBlockComment(c: c, next: next, index: &index, depth: &state.blockCommentDepth, out: &out)
            return
        }
        if state.inString {
            modularityStepStringLiteral(c: c, next: next, index: &index, inString: &state.inString, out: &out)
            return
        }
        modularityStepNormalCode(c: c, next: next, index: &index, state: &state, out: &out)
    }

    static func modularityStepBlockComment(
        c: Character,
        next: Character?,
        index: inout Int,
        depth: inout Int,
        out: inout String
    ) {
        if c == "/" && next == "*" { depth += 1; index += 2; return }
        if c == "*" && next == "/" { depth -= 1; index += 2; return }
        if c == "\n" { out.append("\n") }
        index += 1
    }

    static func modularityStepStringLiteral(
        c: Character,
        next: Character?,
        index: inout Int,
        inString: inout Bool,
        out: inout String
    ) {
        if c == "\\" && next != nil { index += 2; return }
        if c == "\"" { inString = false }
        if c == "\n" { out.append("\n") }
        index += 1
    }

    static func modularityStepNormalCode(
        c: Character,
        next: Character?,
        index: inout Int,
        state: inout ModularityLexerState,
        out: inout String
    ) {
        if c == "/" && next == "/" { state.inLineComment = true; index += 2; return }
        if c == "/" && next == "*" { state.blockCommentDepth = 1; index += 2; return }
        if c == "\"" { state.inString = true; index += 1; return }
        out.append(c)
        index += 1
    }
}
