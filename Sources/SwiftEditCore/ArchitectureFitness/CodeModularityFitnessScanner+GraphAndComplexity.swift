import Foundation

extension CodeModularityFitnessScanner {

    struct ScannedMethodBody {
        let typeName: String
        let name: String
        let isPrivate: Bool
        let line: Int
        let body: String
    }

    struct MethodExtractorState {
        var braceDepth = 0
        var typeStack: [(name: String, bodyDepth: Int)] = []
        var pendingType: String?
        var activeFn: (typeName: String, name: String, isPrivate: Bool, line: Int, bodyDepth: Int, buffer: String)?
        var pendingFn: (typeName: String, name: String, isPrivate: Bool, line: Int)?
        var result: [ScannedMethodBody] = []
    }

    /// Evaluates intra-type function/method call graphs across `directoryURLs` to verify zero call-graph recursion cycles while enforcing canonical root confinement (`CWE-22`) and `4 MiB` byte caps (`CWE-400`) (`REQ-007`, `SEC-003`, `SEC-012`).
    public static func verifyZeroCallGraphRecursion(
        at directoryURLs: [URL],
        budgets: CodeModularityBudgets = .default
    ) throws -> [CodeModularityViolation] {
        let collected = try collectValidatedDirectorySources(at: directoryURLs, budgets: budgets)
        var violations = collected.violations
        violations.append(contentsOf: verifyZeroCallGraphRecursion(sources: collected.sources))
        return violations
    }

    /// Evaluates intra-type function/method call graphs across `(filePath, content)` sources to detect direct self-recursion, private-overload self-loops, and mutual recursion cycles (`REQ-007`).
    public static func verifyZeroCallGraphRecursion(
        sources: [(filePath: String, content: String)]
    ) -> [CodeModularityViolation] {
        var methodsByFileAndType: [String: (filePath: String, methods: [ScannedMethodBody])] = [:]

        for entry in sources {
            let stripped = stripCommentsAndStringsPreservingNewlines(from: entry.content)
            for method in extractScopedMethodBodies(from: stripped) {
                let key = "\(entry.filePath)::\(method.typeName)"
                var bucket = methodsByFileAndType[key] ?? (entry.filePath, [])
                bucket.methods.append(method)
                methodsByFileAndType[key] = bucket
            }
        }

        var violations: [CodeModularityViolation] = []
        for (_, bucket) in methodsByFileAndType.sorted(by: { $0.key < $1.key }) {
            violations.append(contentsOf: evaluateIntraTypeRecursion(filePath: bucket.filePath, methods: bucket.methods))
        }
        return violations
    }

    private static func evaluateIntraTypeRecursion(
        filePath: String,
        methods: [ScannedMethodBody]
    ) -> [CodeModularityViolation] {
        var countsByName: [String: Int] = [:]
        var hasPrivateOverload: Set<String> = []
        for m in methods {
            countsByName[m.name, default: 0] += 1
            if m.isPrivate { hasPrivateOverload.insert(m.name) }
        }
        let declaredNames = Set(countsByName.keys)
        var adjacency: [String: Set<String>] = [:]
        var violations: [CodeModularityViolation] = []

        for m in methods {
            let callees = extractDirectOrSelfCallees(in: m.body, candidates: declaredNames)
            for callee in callees {
                if callee == m.name {
                    // Flag single-declaration self-recursion OR overload collision with a private helper (`REQ-007`).
                    if (countsByName[callee] ?? 0) == 1 || hasPrivateOverload.contains(callee) {
                        violations.append(CodeModularityViolation(
                            filePath: filePath,
                            symbolName: "\(m.typeName).\(m.name)",
                            kind: .callGraphRecursion,
                            observed: 1,
                            limit: 0,
                            reason: "Direct or private-overload self-recursion detected in \(m.typeName).\(m.name)"
                        ))
                    }
                } else {
                    adjacency[m.name, default: []].insert(callee)
                }
            }
        }

        for scc in findMutualCycles(adjacency: adjacency) {
            let sorted = scc.sorted()
            violations.append(CodeModularityViolation(
                filePath: filePath,
                symbolName: sorted.joined(separator: " <-> "),
                kind: .callGraphRecursion,
                observed: sorted.count,
                limit: 0,
                reason: "Mutual call-graph recursion cycle detected: \(sorted.joined(separator: " <-> "))"
            ))
        }
        return violations
    }

    static func extractScopedMethodBodies(from stripped: String) -> [ScannedMethodBody] {
        var state = MethodExtractorState()
        for (zeroIdx, line) in stripped.components(separatedBy: "\n").enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            updatePendingHeaderState(&state, trimmed: trimmed, lineNo: zeroIdx + 1)
            for ch in line {
                advanceExtractorBrace(ch, state: &state)
            }
            if state.activeFn != nil { state.activeFn?.buffer.append("\n") }
        }
        return state.result
    }

    private static func updatePendingHeaderState(_ state: inout MethodExtractorState, trimmed: String, lineNo: Int) {
        if state.activeFn == nil, state.pendingFn == nil, let topType = state.typeStack.last, state.braceDepth == topType.bodyDepth,
           let parsedFn = parseMethodHeader(trimmed) {
            state.pendingFn = (topType.name, parsedFn.name, parsedFn.isPrivate, lineNo)
        } else if state.pendingType == nil, state.activeFn == nil, let typeName = parseScopeTypeName(trimmed) {
            state.pendingType = typeName
        }
    }

    private static func advanceExtractorBrace(_ ch: Character, state: inout MethodExtractorState) {
        if ch == "{" {
            state.activeFn?.buffer.append(ch)
            state.braceDepth += 1
            if let fn = state.pendingFn {
                state.activeFn = (fn.typeName, fn.name, fn.isPrivate, fn.line, state.braceDepth, "")
                state.pendingFn = nil
            } else if let tName = state.pendingType {
                state.typeStack.append((tName, state.braceDepth))
                state.pendingType = nil
            }
            return
        }
        guard ch == "}" else {
            state.activeFn?.buffer.append(ch)
            return
        }
        if let fn = state.activeFn, state.braceDepth == fn.bodyDepth {
            state.result.append(ScannedMethodBody(typeName: fn.typeName, name: fn.name, isPrivate: fn.isPrivate, line: fn.line, body: fn.buffer))
            state.activeFn = nil
        } else {
            state.activeFn?.buffer.append(ch)
            if let topType = state.typeStack.last, state.braceDepth == topType.bodyDepth {
                state.typeStack.removeLast()
            }
        }
        state.braceDepth = max(0, state.braceDepth - 1)
    }

    private static func parseScopeTypeName(_ trimmed: String) -> String? {
        guard !trimmed.isEmpty, !trimmed.hasPrefix("return "), !trimmed.hasPrefix("let "), !trimmed.hasPrefix("var ") else {
            return nil
        }
        let tokens = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
        for (idx, tok) in tokens.enumerated() {
            if tok == "class" || tok == "struct" || tok == "enum" || tok == "extension" || tok == "actor" {
                guard idx + 1 < tokens.count else { return nil }
                let raw = String(tokens[idx + 1]).prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
                return raw.isEmpty ? nil : String(raw)
            }
        }
        return nil
    }

    private static func parseMethodHeader(_ trimmed: String) -> (name: String, isPrivate: Bool)? {
        let tokens = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
        let isPriv = tokens.contains("private") || tokens.contains("fileprivate")
        for (idx, tok) in tokens.enumerated() where tok == "func" && idx + 1 < tokens.count {
            let raw = String(tokens[idx + 1]).prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            return raw.isEmpty ? nil : (String(raw), isPriv)
        }
        return nil
    }

    private static func extractDirectOrSelfCallees(in body: String, candidates: Set<String>) -> Set<String> {
        let chars = Array(body)
        var out: Set<String> = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isLetter || c == "_" {
                let start = i
                i += 1
                while i < chars.count && (chars[i].isLetter || chars[i].isNumber || chars[i] == "_") { i += 1 }
                let ident = String(chars[start..<i])
                var j = i
                while j < chars.count && (chars[j] == " " || chars[j] == "\t") { j += 1 }
                guard j < chars.count && chars[j] == "(" && candidates.contains(ident) else { continue }
                if isBareOrSelfReceiver(chars: chars, tokenStart: start) {
                    out.insert(ident)
                }
            } else {
                i += 1
            }
        }
        return out
    }

    private static func isBareOrSelfReceiver(chars: [Character], tokenStart: Int) -> Bool {
        var p = tokenStart - 1
        while p >= 0 && (chars[p] == " " || chars[p] == "\t") { p -= 1 }
        guard p >= 0 && chars[p] == "." else { return true }
        var rEnd = p - 1
        if rEnd >= 0 && chars[rEnd] == "?" { rEnd -= 1 }
        while rEnd >= 0 && (chars[rEnd] == " " || chars[rEnd] == "\t") { rEnd -= 1 }
        guard rEnd >= 0 else { return false }
        var rStart = rEnd
        while rStart >= 0 && (chars[rStart].isLetter || chars[rStart].isNumber || chars[rStart] == "_") { rStart -= 1 }
        guard rStart < rEnd else { return false }
        let receiver = String(chars[(rStart + 1)...rEnd])
        return receiver == "self" || receiver == "Self"
    }

    private static func findMutualCycles(adjacency: [String: Set<String>]) -> [[String]] {
        var index = 0
        var indices: [String: Int] = [:]
        var lowlink: [String: Int] = [:]
        var stack: [String] = []
        var onStack: Set<String> = []
        var sccs: [[String]] = []

        func strongConnect(_ node: String) {
            indices[node] = index
            lowlink[node] = index
            index += 1
            stack.append(node)
            onStack.insert(node)
            for neighbor in (adjacency[node] ?? []).sorted() {
                if indices[neighbor] == nil {
                    strongConnect(neighbor)
                    lowlink[node] = min(lowlink[node]!, lowlink[neighbor]!)
                } else if onStack.contains(neighbor) {
                    lowlink[node] = min(lowlink[node]!, indices[neighbor]!)
                }
            }
            if lowlink[node] == indices[node] {
                var comp: [String] = []
                while let popped = stack.popLast() {
                    onStack.remove(popped)
                    comp.append(popped)
                    if popped == node { break }
                }
                if comp.count >= 2 { sccs.append(comp) }
            }
        }

        for node in adjacency.keys.sorted() where indices[node] == nil {
            strongConnect(node)
        }
        return sccs
    }
}
