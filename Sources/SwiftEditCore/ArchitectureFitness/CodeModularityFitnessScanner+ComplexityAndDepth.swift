import Foundation

extension CodeModularityFitnessScanner {

    private static let cyclomaticBranchKeywords: Set<String> = [
        "if", "guard", "for", "while", "catch", "case",
    ]
    private static let cognitiveNestingKeywords: Set<String> = [
        "if", "for", "while", "repeat", "switch", "catch",
    ]

    /// Evaluates per-method cyclomatic (`<= maxCyclomatic`) and cognitive (`<= maxCognitive`) complexity budgets across `directoryURLs` while enforcing canonical root confinement (`CWE-22`) and `4 MiB` byte caps (`CWE-400`) (`REQ-008`, `SEC-003`, `SEC-012`).
    public static func verifyMethodComplexityBudgets(
        at directoryURLs: [URL],
        budgets: CodeModularityBudgets = .default,
        maxCyclomatic: Int = 15,
        maxCognitive: Int = 25
    ) throws -> [CodeModularityViolation] {
        let collected = try collectValidatedDirectorySources(at: directoryURLs, budgets: budgets)
        var violations = collected.violations
        violations.append(contentsOf: verifyMethodComplexityBudgets(
            sources: collected.sources,
            maxCyclomatic: maxCyclomatic,
            maxCognitive: maxCognitive
        ))
        return violations
    }

    /// Evaluates per-method cyclomatic (`<= maxCyclomatic`) and cognitive (`<= maxCognitive`) complexity budgets across `(filePath, content)` entries (`REQ-008`).
    public static func verifyMethodComplexityBudgets(
        sources: [(filePath: String, content: String)],
        maxCyclomatic: Int = 15,
        maxCognitive: Int = 25
    ) -> [CodeModularityViolation] {
        var violations: [CodeModularityViolation] = []
        for entry in sources {
            let stripped = stripCommentsAndStringsPreservingNewlines(from: entry.content)
            for method in extractScopedMethodBodies(from: stripped) {
                let metrics = measureMethodComplexity(body: method.body)
                let fqName = "\(method.typeName).\(method.name)"
                if metrics.cyclomatic > maxCyclomatic {
                    violations.append(CodeModularityViolation(
                        filePath: entry.filePath,
                        symbolName: fqName,
                        kind: .methodCyclomaticComplexity,
                        observed: metrics.cyclomatic,
                        limit: maxCyclomatic,
                        reason: "Method \(fqName) at line \(method.line) has cyclomatic complexity \(metrics.cyclomatic) > \(maxCyclomatic)"
                    ))
                }
                if metrics.cognitive > maxCognitive {
                    violations.append(CodeModularityViolation(
                        filePath: entry.filePath,
                        symbolName: fqName,
                        kind: .methodCognitiveComplexity,
                        observed: metrics.cognitive,
                        limit: maxCognitive,
                        reason: "Method \(fqName) at line \(method.line) has cognitive complexity \(metrics.cognitive) > \(maxCognitive)"
                    ))
                }
            }
        }
        return violations
    }

    private struct ComplexityState {
        var cyclomatic = 1
        var cognitive = 0
        var braceDepth = 0
        var nestingBraceDepths: [Int] = []
        var pendingNestingPush = false
        var afterElse = false
        var lastBoolOp: String?
    }

    private static func measureMethodComplexity(body: String) -> (cyclomatic: Int, cognitive: Int) {
        var state = ComplexityState()
        for token in tokenizeComplexityStream(body) {
            applyComplexityToken(token, state: &state)
        }
        return (state.cyclomatic, state.cognitive)
    }

    private static func applyComplexityToken(_ token: String, state: inout ComplexityState) {
        if token == "{" {
            state.lastBoolOp = nil
            state.braceDepth += 1
            if state.pendingNestingPush {
                state.nestingBraceDepths.append(state.braceDepth)
                state.pendingNestingPush = false
            }
            return
        }
        if token == "}" {
            state.lastBoolOp = nil
            if state.nestingBraceDepths.last == state.braceDepth {
                state.nestingBraceDepths.removeLast()
            }
            state.braceDepth = max(0, state.braceDepth - 1)
            return
        }
        if token == "&&" || token == "||" {
            if state.lastBoolOp != token {
                state.cognitive += 1
                state.lastBoolOp = token
            }
            return
        }
        if token == "?:" {
            state.lastBoolOp = nil
            state.cyclomatic += 1
            state.cognitive += 1 + state.nestingBraceDepths.count
            return
        }
        state.lastBoolOp = nil
        applyKeywordComplexity(token, state: &state)
    }

    private static func applyKeywordComplexity(_ token: String, state: inout ComplexityState) {
        if cyclomaticBranchKeywords.contains(token) {
            state.cyclomatic += 1
        }
        if token == "else" {
            state.afterElse = true
            state.cognitive += 1
            return
        }
        if token == "if" && state.afterElse {
            state.afterElse = false
            state.pendingNestingPush = true
            return
        }
        state.afterElse = false
        if cognitiveNestingKeywords.contains(token) {
            state.cognitive += 1 + state.nestingBraceDepths.count
            state.pendingNestingPush = true
        } else if token == "guard" {
            state.cognitive += 1
        }
    }

    private static func tokenizeComplexityStream(_ body: String) -> [String] {
        let chars = Array(body)
        var tokens: [String] = []
        var idx = 0
        while idx < chars.count {
            idx = appendNextComplexityToken(chars: chars, index: idx, into: &tokens)
        }
        return tokens
    }

    private static func appendNextComplexityToken(chars: [Character], index: Int, into tokens: inout [String]) -> Int {
        let ch = chars[index]
        if ch.isLetter || ch == "_" {
            var end = index + 1
            while end < chars.count && (chars[end].isLetter || chars[end].isNumber || chars[end] == "_") { end += 1 }
            let prevIsDot = index > 0 && chars[index - 1] == "."
            if !prevIsDot { tokens.append(String(chars[index..<end])) }
            return end
        }
        if ch == "{" || ch == "}" {
            tokens.append(String(ch))
            return index + 1
        }
        if index + 1 < chars.count {
            let pair = String([ch, chars[index + 1]])
            if pair == "&&" || pair == "||" || pair == "??" {
                tokens.append(pair)
                return index + 2
            }
            if ch == "?" && chars[index + 1] == " " && index > 0 && chars[index - 1] == " " {
                tokens.append("?:")
                return index + 1
            }
        }
        return index + 1
    }
}

extension CodeModularityFitnessScanner {

    /// Evaluates file dependency chain depth (`<= maxDepth` hops) and dead `private func` symbols across `directoryURLs` while enforcing canonical root confinement (`CWE-22`) and `4 MiB` byte caps (`CWE-400`) (`REQ-009`, `AR-006`, `AR-007`, `SEC-003`, `SEC-012`).
    public static func verifyDeadPrivateSymbolsAndDependencyDepth(
        at directoryURLs: [URL],
        budgets: CodeModularityBudgets = .default,
        maxDepth: Int = 10
    ) throws -> [CodeModularityViolation] {
        let collected = try collectValidatedDirectorySources(at: directoryURLs, budgets: budgets)
        var violations = collected.violations
        violations.append(contentsOf: verifyDeadPrivateSymbolsAndDependencyDepth(
            sources: collected.sources,
            maxDepth: maxDepth
        ))
        return violations
    }

    /// Evaluates file dependency chain depth (`<= maxDepth` hops) and unreferenced `private func` symbols across `(filePath, content)` entries (`REQ-009`).
    public static func verifyDeadPrivateSymbolsAndDependencyDepth(
        sources: [(filePath: String, content: String)],
        maxDepth: Int = 10
    ) -> [CodeModularityViolation] {
        guard !sources.isEmpty else { return [] }
        let indexed = acyclicityIndexSymbolOwners(sources: sources)
        var callGraph: [String: Set<String>] = [:]
        var violations: [CodeModularityViolation] = []

        for entry in indexed.strippedByFile {
            for calledFunc in extractInvokedFunctionNames(in: entry.stripped) {
                if let dst = indexed.uniqueFuncOwner[calledFunc], dst != entry.filePath {
                    callGraph[entry.filePath, default: []].insert(dst)
                }
            }
            violations.append(contentsOf: detectDeadPrivateFunctions(filePath: entry.filePath, stripped: entry.stripped))
        }

        let depths = computeMaxSimpleChainDepths(callGraph: callGraph)
        for (filePath, depth) in depths.sorted(by: { $0.key < $1.key }) where depth > maxDepth {
            violations.append(CodeModularityViolation(
                filePath: filePath,
                kind: .fileDependencyDepth,
                observed: depth,
                limit: maxDepth,
                reason: "File dependency chain starting at \(filePath) reaches depth \(depth) > \(maxDepth)"
            ))
        }
        return violations
    }

    private static func detectDeadPrivateFunctions(filePath: String, stripped: String) -> [CodeModularityViolation] {
        let lines = stripped.components(separatedBy: "\n")
        var privateDecls: [(name: String, line: Int)] = []
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.contains("@objc") else { continue }
            let tokens = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if tokens.contains("private"), let fnName = parseDeclaredFunctionName(trimmed) {
                privateDecls.append((fnName, idx + 1))
            }
        }
        guard !privateDecls.isEmpty else { return [] }

        var allCallTokens: [String: Int] = [:]
        for line in lines {
            for ident in extractInvokedFunctionNames(in: line) {
                allCallTokens[ident, default: 0] += 1
            }
        }

        var violations: [CodeModularityViolation] = []
        for decl in privateDecls {
            // In stripped Swift, `func foo(` counts as 0 in `extractInvokedFunctionNames` because `state.prevWord == "func"` is excluded!
            if (allCallTokens[decl.name] ?? 0) == 0 {
                violations.append(CodeModularityViolation(
                    filePath: filePath,
                    symbolName: decl.name,
                    kind: .deadPrivateSymbol,
                    observed: 0,
                    limit: 1,
                    reason: "Unreferenced private func '\(decl.name)' at line \(decl.line)"
                ))
            }
        }
        return violations
    }

    private static func computeMaxSimpleChainDepths(callGraph: [String: Set<String>]) -> [String: Int] {
        var nodes = Set(callGraph.keys)
        for targets in callGraph.values { nodes.formUnion(targets) }
        let sortedNodes = nodes.sorted()
        var bestDepth: [String: Int] = Dictionary(uniqueKeysWithValues: sortedNodes.map { ($0, 0) })
        guard !sortedNodes.isEmpty else { return bestDepth }

        // Iterative longest-path relaxation capped at |V| passes (acyclic DAG exact, cycle-safe without stack recursion).
        for _ in 0..<sortedNodes.count {
            var changed = false
            if relaxDepthPass(sortedNodes: sortedNodes, callGraph: callGraph, bestDepth: &bestDepth) {
                changed = true
            }
            if !changed { break }
        }
        return bestDepth
    }

    private static func relaxDepthPass(
        sortedNodes: [String],
        callGraph: [String: Set<String>],
        bestDepth: inout [String: Int]
    ) -> Bool {
        var anyUpdated = false
        for node in sortedNodes {
            var candidate = bestDepth[node] ?? 0
            for dst in (callGraph[node] ?? []) {
                let nextVal = 1 + (bestDepth[dst] ?? 0)
                if nextVal > candidate { candidate = nextVal }
            }
            if candidate > (bestDepth[node] ?? 0) {
                bestDepth[node] = candidate
                anyUpdated = true
            }
        }
        return anyUpdated
    }
}
