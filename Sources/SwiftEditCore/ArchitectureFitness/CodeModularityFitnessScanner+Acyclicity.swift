import Foundation

extension CodeModularityFitnessScanner {

    /// Evaluates cross-file nominal symbol references and call edges across `directoryURLs` to verify zero circular file dependencies while enforcing canonical root confinement (`CWE-22`, `resolvingSymlinksInPath`) and the `4 MiB` byte cap (`CWE-400`) fail-closed (`REQ-006`, `AR-006`, `SEC-003`, `SEC-012`).
    public static func verifyAcyclicFileGraph(
        at directoryURLs: [URL],
        budgets: CodeModularityBudgets = .default
    ) throws -> [CodeModularityViolation] {
        let collected = try collectValidatedDirectorySources(at: directoryURLs, budgets: budgets)
        var violations = collected.violations
        violations.append(contentsOf: verifyAcyclicFileGraph(sources: collected.sources))
        return violations
    }

    /// Evaluates cross-file nominal symbol references and unique-function call edges across `(filePath: content)` sources, reporting Tarjan SCC file cycles and upward `SwiftEditCore -> SwiftEditUI` violations (`REQ-006`, `AR-006`).
    public static func verifyAcyclicFileGraph(
        sources: [(filePath: String, content: String)]
    ) -> [CodeModularityViolation] {
        guard !sources.isEmpty else { return [] }

        let indexed = acyclicityIndexSymbolOwners(sources: sources)
        var violations: [CodeModularityViolation] = []
        var callGraph: [String: Set<String>] = [:]

        for entry in indexed.strippedByFile {
            acyclicityAnalyzeSourceEdges(
                entry: entry,
                uniqueNominalOwner: indexed.uniqueNominalOwner,
                uniqueFuncOwner: indexed.uniqueFuncOwner,
                callGraph: &callGraph,
                violations: &violations
            )
        }

        violations.append(contentsOf: acyclicityBuildSCCViolations(callGraph: callGraph))
        return violations
    }
}

extension CodeModularityFitnessScanner {
    struct AcyclicityIndexedSymbols {
        let strippedByFile: [(filePath: String, stripped: String)]
        let uniqueNominalOwner: [String: String]
        let uniqueFuncOwner: [String: String]
    }

    struct AcyclicityCallScanState {
        var prevWord: String?
        var precededByAt = false
        var precededByBareDot = false
    }

    static func acyclicityIndexSymbolOwners(
        sources: [(filePath: String, content: String)]
    ) -> AcyclicityIndexedSymbols {
        var strippedByFile: [(filePath: String, stripped: String)] = []
        strippedByFile.reserveCapacity(sources.count)
        var nominalOwners: [String: Set<String>] = [:]
        var funcOwners: [String: Set<String>] = [:]

        for entry in sources {
            let stripped = stripCommentsAndStringsPreservingNewlines(from: entry.content)
            strippedByFile.append((entry.filePath, stripped))
            acyclicityRecordLineDeclarations(
                stripped: stripped,
                filePath: entry.filePath,
                nominalOwners: &nominalOwners,
                funcOwners: &funcOwners
            )
        }

        return AcyclicityIndexedSymbols(
            strippedByFile: strippedByFile,
            uniqueNominalOwner: acyclicitySingleOwnerMap(from: nominalOwners),
            uniqueFuncOwner: acyclicitySingleOwnerMap(from: funcOwners)
        )
    }

    static func acyclicityRecordLineDeclarations(
        stripped: String,
        filePath: String,
        nominalOwners: inout [String: Set<String>],
        funcOwners: inout [String: Set<String>]
    ) {
        for line in stripped.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let typeName = parsePrimaryNominalTypeName(trimmed) {
                nominalOwners[typeName, default: []].insert(filePath)
            }
            if let fnName = parseDeclaredFunctionName(trimmed) {
                funcOwners[fnName, default: []].insert(filePath)
            }
        }
    }

    static func acyclicitySingleOwnerMap(from ownersBySymbol: [String: Set<String>]) -> [String: String] {
        var unique: [String: String] = [:]
        for (symbol, owners) in ownersBySymbol where owners.count == 1 {
            if let owner = owners.first {
                unique[symbol] = owner
            }
        }
        return unique
    }

    static func acyclicityAnalyzeSourceEdges(
        entry: (filePath: String, stripped: String),
        uniqueNominalOwner: [String: String],
        uniqueFuncOwner: [String: String],
        callGraph: inout [String: Set<String>],
        violations: inout [CodeModularityViolation]
    ) {
        let srcFile = entry.filePath
        let isCoreSource = srcFile.contains("SwiftEditCore/")
        acyclicityRecordCallEdges(
            srcFile: srcFile,
            stripped: entry.stripped,
            isCoreSource: isCoreSource,
            uniqueFuncOwner: uniqueFuncOwner,
            callGraph: &callGraph,
            violations: &violations
        )
        if isCoreSource {
            acyclicityCheckUpwardNominalReferences(
                srcFile: srcFile,
                stripped: entry.stripped,
                uniqueNominalOwner: uniqueNominalOwner,
                violations: &violations
            )
        }
        acyclicityCheckLeafModuleEdges(srcFile: srcFile, callGraph: callGraph, violations: &violations)
    }

    static func acyclicityRecordCallEdges(
        srcFile: String,
        stripped: String,
        isCoreSource: Bool,
        uniqueFuncOwner: [String: String],
        callGraph: inout [String: Set<String>],
        violations: inout [CodeModularityViolation]
    ) {
        for calledFunc in extractInvokedFunctionNames(in: stripped) {
            guard let dstFile = uniqueFuncOwner[calledFunc], dstFile != srcFile else { continue }
            callGraph[srcFile, default: []].insert(dstFile)
            if isCoreSource && dstFile.contains("SwiftEditUI/") {
                violations.append(CodeModularityViolation(
                    filePath: srcFile,
                    symbolName: calledFunc,
                    kind: .circularFileDependency,
                    observed: 1,
                    limit: 0,
                    reason: "Upward call edge from SwiftEditCore (\(srcFile)) to SwiftEditUI (\(dstFile)) via \(calledFunc)"
                ))
            }
        }
    }

    static func acyclicityCheckUpwardNominalReferences(
        srcFile: String,
        stripped: String,
        uniqueNominalOwner: [String: String],
        violations: inout [CodeModularityViolation]
    ) {
        for ident in extractIdentifierTokens(in: stripped) {
            guard let dstFile = uniqueNominalOwner[ident],
                  dstFile != srcFile,
                  dstFile.contains("SwiftEditUI/") else {
                continue
            }
            violations.append(CodeModularityViolation(
                filePath: srcFile,
                symbolName: ident,
                kind: .circularFileDependency,
                observed: 1,
                limit: 0,
                reason: "Upward nominal reference from SwiftEditCore (\(srcFile)) to SwiftEditUI (\(dstFile)) via \(ident)"
            ))
        }
    }

    static func acyclicityCheckLeafModuleEdges(
        srcFile: String,
        callGraph: [String: Set<String>],
        violations: inout [CodeModularityViolation]
    ) {
        guard srcFile.hasSuffix("/MarkdownLineIndex.swift"),
              let outgoing = callGraph[srcFile],
              !outgoing.isEmpty else {
            return
        }
        let targets = outgoing.sorted().joined(separator: ", ")
        violations.append(CodeModularityViolation(
            filePath: srcFile,
            symbolName: "MarkdownLineIndex",
            kind: .circularFileDependency,
            observed: outgoing.count,
            limit: 0,
            reason: "Leaf module MarkdownLineIndex.swift has outgoing file call edges: \(targets)"
        ))
    }

    static func acyclicityBuildSCCViolations(callGraph: [String: Set<String>]) -> [CodeModularityViolation] {
        computeNonTrivialSCCs(adjacency: callGraph).map { scc in
            let sortedSCC = scc.sorted()
            return CodeModularityViolation(
                filePath: sortedSCC[0],
                kind: .circularFileDependency,
                observed: sortedSCC.count,
                limit: 1,
                reason: "Circular file dependency cycle across \(sortedSCC.count) files: \(sortedSCC.joined(separator: " <-> "))"
            )
        }
    }

    static func parsePrimaryNominalTypeName(_ trimmed: String) -> String? {
        guard !trimmed.isEmpty, !trimmed.hasPrefix("return "), !trimmed.hasPrefix("let "), !trimmed.hasPrefix("var ") else {
            return nil
        }
        let primaryKeywords: Set<Substring> = ["class", "struct", "enum", "actor", "protocol"]
        let tokens = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
        for (idx, tok) in tokens.enumerated() where primaryKeywords.contains(tok) {
            guard idx + 1 < tokens.count else { return nil }
            let rawName = String(tokens[idx + 1])
            let cleaned = rawName.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            return cleaned.isEmpty ? nil : String(cleaned)
        }
        return nil
    }

    static func parseDeclaredFunctionName(_ trimmed: String) -> String? {
        guard !trimmed.isEmpty else { return nil }
        let tokens = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
        for (idx, tok) in tokens.enumerated() where tok == "func" {
            guard idx + 1 < tokens.count else { return nil }
            let rawName = String(tokens[idx + 1])
            let cleaned = rawName.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            guard !cleaned.isEmpty else { return nil }
            return String(cleaned)
        }
        return nil
    }
}

extension CodeModularityFitnessScanner {
    struct AcyclicityTarjanState {
        var nextIndex = 0
        var indices: [String: Int] = [:]
        var lowlink: [String: Int] = [:]
        var tarjanStack: [String] = []
        var onStack: Set<String> = []
        var sccs: [[String]] = []
        let sortedNeighbors: [String: [String]]

        mutating func visitVertex(_ vertex: String) {
            indices[vertex] = nextIndex
            lowlink[vertex] = nextIndex
            nextIndex += 1
            tarjanStack.append(vertex)
            onStack.insert(vertex)
        }
    }

    static func extractInvokedFunctionNames(in stripped: String) -> Set<String> {
        var invoked: Set<String> = []
        let chars = Array(stripped)
        var index = 0
        var state = AcyclicityCallScanState()

        while index < chars.count {
            let ch = chars[index]
            if ch.isLetter || ch == "_" {
                acyclicityConsumeIdentifierToken(chars: chars, index: &index, state: &state, invoked: &invoked)
            } else {
                acyclicityConsumePunctuation(ch, state: &state)
                index += 1
            }
        }
        return invoked
    }

    static func acyclicityConsumeIdentifierToken(
        chars: [Character],
        index: inout Int,
        state: inout AcyclicityCallScanState,
        invoked: inout Set<String>
    ) {
        let start = index
        index += 1
        while index < chars.count, acyclicityIsIdentifierContinuation(chars[index]) {
            index += 1
        }
        let word = String(chars[start..<index])
        if acyclicityIsFollowedByOpenParen(chars: chars, from: index),
           acyclicityAllowsInvocation(state: state) {
            invoked.insert(word)
        }
        state.prevWord = word
        state.precededByAt = false
        state.precededByBareDot = false
    }

    static func acyclicityIsIdentifierContinuation(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "_"
    }

    static func acyclicityIsFollowedByOpenParen(chars: [Character], from start: Int) -> Bool {
        var lookahead = start
        while lookahead < chars.count && (chars[lookahead] == " " || chars[lookahead] == "\t") {
            lookahead += 1
        }
        return lookahead < chars.count && chars[lookahead] == "("
    }

    static func acyclicityAllowsInvocation(state: AcyclicityCallScanState) -> Bool {
        !state.precededByAt
            && !state.precededByBareDot
            && state.prevWord != "func"
            && state.prevWord != "case"
    }

    static func acyclicityConsumePunctuation(_ ch: Character, state: inout AcyclicityCallScanState) {
        if ch == "@" {
            state.precededByAt = true
            state.precededByBareDot = false
            state.prevWord = nil
        } else if ch == "." {
            state.precededByBareDot = (state.prevWord == nil)
        } else if ch == ")" || ch == "]" || ch == "?" || ch == "!" {
            state.prevWord = "<expr>"
            state.precededByAt = false
            state.precededByBareDot = false
        } else if ch != " " && ch != "\t" {
            state.precededByAt = false
            state.precededByBareDot = false
            state.prevWord = nil
        }
    }

    static func extractIdentifierTokens(in stripped: String) -> Set<String> {
        var identifiers: Set<String> = []
        let chars = Array(stripped)
        let count = chars.count
        var i = 0
        while i < count {
            let c = chars[i]
            if c.isLetter || c == "_" {
                let start = i
                i += 1
                while i < count, acyclicityIsIdentifierContinuation(chars[i]) {
                    i += 1
                }
                identifiers.insert(String(chars[start..<i]))
            } else {
                i += 1
            }
        }
        return identifiers
    }

    /// Iterative Tarjan Strongly Connected Components computation avoiding call-stack recursion (`REQ-006`, `REQ-007`).
    static func computeNonTrivialSCCs(adjacency: [String: Set<String>]) -> [[String]] {
        let allVertices = Set(adjacency.keys).union(adjacency.values.flatMap { $0 }).sorted()
        var state = AcyclicityTarjanState(sortedNeighbors: adjacency.mapValues { $0.sorted() })

        for root in allVertices where state.indices[root] == nil {
            acyclicityRunTarjanFromRoot(root, state: &state)
        }
        return state.sccs
    }

    static func acyclicityRunTarjanFromRoot(_ root: String, state: inout AcyclicityTarjanState) {
        var callStack: [(vertex: String, neighborCursor: Int)] = [(root, 0)]
        state.visitVertex(root)

        while let frame = callStack.last {
            let neighbors = state.sortedNeighbors[frame.vertex] ?? []
            if frame.neighborCursor < neighbors.count {
                acyclicityAdvanceTarjanEdge(frame: frame, neighbors: neighbors, callStack: &callStack, state: &state)
            } else {
                acyclicityFinishTarjanVertex(frame.vertex, callStack: &callStack, state: &state)
            }
        }
    }

    static func acyclicityAdvanceTarjanEdge(
        frame: (vertex: String, neighborCursor: Int),
        neighbors: [String],
        callStack: inout [(vertex: String, neighborCursor: Int)],
        state: inout AcyclicityTarjanState
    ) {
        let target = neighbors[frame.neighborCursor]
        callStack[callStack.count - 1].neighborCursor += 1
        if state.indices[target] == nil {
            state.visitVertex(target)
            callStack.append((target, 0))
        } else if state.onStack.contains(target) {
            state.lowlink[frame.vertex] = min(state.lowlink[frame.vertex]!, state.indices[target]!)
        }
    }

    static func acyclicityFinishTarjanVertex(
        _ vertex: String,
        callStack: inout [(vertex: String, neighborCursor: Int)],
        state: inout AcyclicityTarjanState
    ) {
        _ = callStack.removeLast()
        if let parent = callStack.last?.vertex {
            state.lowlink[parent] = min(state.lowlink[parent]!, state.lowlink[vertex]!)
        }
        guard state.lowlink[vertex] == state.indices[vertex] else { return }
        let component = acyclicityPopSCCComponent(upTo: vertex, state: &state)
        if component.count > 1 {
            state.sccs.append(component)
        }
    }

    static func acyclicityPopSCCComponent(upTo rootVertex: String, state: inout AcyclicityTarjanState) -> [String] {
        var component: [String] = []
        while let popped = state.tarjanStack.popLast() {
            state.onStack.remove(popped)
            component.append(popped)
            if popped == rootVertex { break }
        }
        return component
    }
}
