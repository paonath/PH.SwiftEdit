import Foundation

/// Bounded pure-`Foundation` diagram parser and iterative layout engine for `markmap`, `mindmap`, and core `mermaid` diagrams (`REQ-004`, `CWE-400`, `CWE-674`, `SEC-004`).
///
/// Enforces strict resource ceilings (`maxSourceUTF8Bytes = 64 KiB`, `maxNodes = 256`, `maxEdges = 512`, `maxDepth = 12`) and iterative Bellman-Ford rank relaxation (`CWE-674` cycle breaking) with zero `WebKit` or JavaScript execution (`SEC-004`).
public enum MarkdownDiagramParser {
    public static let maxSourceUTF8Bytes = 65_536
    public static let maxNodes = 256
    public static let maxEdges = 512
    public static let maxDepth = 12

    /// Parses a fenced `markmap`, `mindmap`, or `mermaid` block into a positioned `MarkdownDiagramModel`, returning `.unsupportedOrOversized` on unsupported syntax or exceeded safety bounds.
    public static func parse(language: String?, source: String) -> MarkdownDiagramParseOutcome {
        guard source.utf8.count <= maxSourceUTF8Bytes else { return .unsupportedOrOversized }
        let normalizedLang = (language ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedLang {
        case "markmap", "mindmap":
            return MarkmapParserAndLayout.parse(source: source, isMermaidMindmap: false)
        case "mermaid":
            return parseMermaidDiagram(source: source)
        default:
            return .unsupportedOrOversized
        }
    }

    private static func parseMermaidDiagram(source: String) -> MarkdownDiagramParseOutcome {
        let activeLines = nonCommentLines(from: source)
        guard let header = activeLines.first?.trimmingCharacters(in: .whitespaces).lowercased() else {
            return .unsupportedOrOversized
        }
        if header.hasPrefix("mindmap") {
            return MarkmapParserAndLayout.parse(source: source, isMermaidMindmap: true)
        }
        let body = Array(activeLines.dropFirst())
        if header.hasPrefix("sequencediagram") {
            return parseSequenceDiagram(body)
        }
        if header.hasPrefix("statediagram") {
            return parseStateDiagram(body)
        }
        if let direction = parseFlowchartHeader(header) {
            return parseFlowchartDiagram(body, direction: direction)
        }
        return .unsupportedOrOversized
    }

    private static func nonCommentLines(from source: String) -> [String] {
        source.components(separatedBy: .newlines).filter { raw in
            let t = raw.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && !t.hasPrefix("%%")
        }
    }

    private static func parseFlowchartHeader(_ lowerHeader: String) -> DiagramDirection? {
        let parts = lowerHeader.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let keyword = parts.first, keyword == "flowchart" || keyword == "graph" else { return nil }
        let dirToken = parts.count > 1 ? parts[1] : "td"
        switch dirToken {
        case "lr": return .leftToRight
        case "rl": return .rightToLeft
        case "bt": return .bottomToTop
        default: return .topToBottom
        }
    }
}

extension MarkdownDiagramParser {
    fileprivate struct ParsedGraphSpec {
        var order: [String] = []
        var labels: [String: String] = [:]
        var shapes: [String: FlowchartNodeShape] = [:]
        var subgraphs: [String: String] = [:]
        var edges: [(from: String, to: String, label: String?, style: DiagramEdgeStyle)] = []

        mutating func registerNode(id: String, label: String?, shape: FlowchartNodeShape?, activeSubgraph: String?) -> Bool {
            if labels[id] == nil {
                guard order.count < MarkdownDiagramParser.maxNodes else { return false }
                order.append(id)
                labels[id] = label ?? id
                shapes[id] = shape ?? .rect
            } else {
                if let label { labels[id] = label }
                if let shape { shapes[id] = shape }
            }
            if subgraphs[id] == nil, let activeSubgraph {
                subgraphs[id] = activeSubgraph
            }
            return true
        }
    }

    fileprivate static func parseFlowchartDiagram(_ lines: [String], direction: DiagramDirection) -> MarkdownDiagramParseOutcome {
        var spec = ParsedGraphSpec()
        var subgraphStack: [String] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: ";"))
            if line.lowercased().hasPrefix("classdef ") || line.lowercased().hasPrefix("class ") || line.lowercased().hasPrefix("style ") || line.lowercased().hasPrefix("click ") {
                continue
            }
            if line.lowercased().hasPrefix("subgraph ") {
                guard subgraphStack.count < maxDepth else { return .unsupportedOrOversized }
                let title = String(line.dropFirst("subgraph ".count)).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
                subgraphStack.append(title.isEmpty ? "Group" : title)
                continue
            }
            if line.lowercased() == "end" {
                if !subgraphStack.isEmpty { subgraphStack.removeLast() }
                continue
            }
            if !consumeFlowchartStatement(line, activeSubgraph: subgraphStack.last, into: &spec) {
                return .unsupportedOrOversized
            }
        }
        guard !spec.order.isEmpty else { return .unsupportedOrOversized }
        return .diagram(layoutLayeredGraph(spec: spec, kind: .flowchart, direction: direction))
    }

    private static func consumeFlowchartStatement(_ line: String, activeSubgraph: String?, into spec: inout ParsedGraphSpec) -> Bool {
        if let edge = splitFlowchartEdge(line) {
            let lhs = parseNodeToken(edge.lhs)
            let rhs = parseNodeToken(edge.rhs)
            guard !lhs.id.isEmpty, !rhs.id.isEmpty else { return true }
            guard spec.edges.count < maxEdges,
                  spec.registerNode(id: lhs.id, label: lhs.label, shape: lhs.shape, activeSubgraph: activeSubgraph),
                  spec.registerNode(id: rhs.id, label: rhs.label, shape: rhs.shape, activeSubgraph: activeSubgraph) else {
                return false
            }
            spec.edges.append((from: lhs.id, to: rhs.id, label: edge.label, style: edge.style))
            return true
        }
        let single = parseNodeToken(line)
        guard !single.id.isEmpty else { return true }
        return spec.registerNode(id: single.id, label: single.label, shape: single.shape, activeSubgraph: activeSubgraph)
    }

    private static func splitFlowchartEdge(_ line: String) -> (lhs: String, rhs: String, label: String?, style: DiagramEdgeStyle)? {
        let operators: [(token: String, style: DiagramEdgeStyle)] = [
            ("-.->", .dotted), ("==>", .thick), ("-->", .solid), ("---", .solid),
        ]
        for op in operators {
            if let range = line.range(of: op.token) {
                let leftPart = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                var rightPart = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                var edgeLabel: String?
                if rightPart.hasPrefix("|"), let closePipe = rightPart.dropFirst().firstIndex(of: "|") {
                    edgeLabel = String(rightPart[rightPart.index(after: rightPart.startIndex)..<closePipe]).trimmingCharacters(in: .whitespaces)
                    rightPart = String(rightPart[rightPart.index(after: closePipe)...]).trimmingCharacters(in: .whitespaces)
                }
                return (leftPart, rightPart, edgeLabel, op.style)
            }
        }
        return nil
    }

    private static func parseNodeToken(_ raw: String) -> (id: String, label: String?, shape: FlowchartNodeShape?) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let delimiters: [(open: String, close: String, shape: FlowchartNodeShape)] = [
            ("([", "])", .stadium), ("((", "))", .circle), ("[", "]", .rect), ("(", ")", .rounded), ("{", "}", .diamond),
        ]
        for d in delimiters {
            if let openRange = trimmed.range(of: d.open), trimmed.hasSuffix(d.close) {
                let id = String(trimmed[..<openRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let labelStart = openRange.upperBound
                let labelEnd = trimmed.index(trimmed.endIndex, offsetBy: -d.close.count)
                if !id.isEmpty, labelStart <= labelEnd {
                    let clean = String(trimmed[labelStart..<labelEnd]).trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                    return (id, clean.isEmpty ? id : String(clean.prefix(96)), d.shape)
                }
            }
        }
        let simpleID = String(trimmed.prefix { !$0.isWhitespace })
        return (simpleID, nil, nil)
    }
}

extension MarkdownDiagramParser {
    fileprivate static func parseStateDiagram(_ lines: [String]) -> MarkdownDiagramParseOutcome {
        var spec = ParsedGraphSpec()
        var starCounter = 0
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let arrowRange = line.range(of: "-->") else { continue }
            let rawLHS = String(line[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var rhsAndLabel = String(line[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            var label: String?
            if let colon = rhsAndLabel.firstIndex(of: ":") {
                label = String(rhsAndLabel[rhsAndLabel.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                rhsAndLabel = String(rhsAndLabel[..<colon]).trimmingCharacters(in: .whitespaces)
            }
            guard spec.edges.count < maxEdges,
                  let lhs = resolveStateEndpoint(rawLHS, isStart: true, starCounter: &starCounter, spec: &spec),
                  let rhs = resolveStateEndpoint(rhsAndLabel, isStart: false, starCounter: &starCounter, spec: &spec) else {
                return .unsupportedOrOversized
            }
            spec.edges.append((from: lhs, to: rhs, label: label, style: .solid))
        }
        guard !spec.order.isEmpty else { return .unsupportedOrOversized }
        return .diagram(layoutLayeredGraph(spec: spec, kind: .state, direction: .topToBottom))
    }

    private static func resolveStateEndpoint(
        _ token: String,
        isStart: Bool,
        starCounter: inout Int,
        spec: inout ParsedGraphSpec
    ) -> String? {
        guard !token.isEmpty else { return nil }
        if token == "[*]" {
            starCounter += 1
            let syntheticID = isStart ? "__start_\(starCounter)" : "__end_\(starCounter)"
            let marker = isStart ? "●" : "◉"
            guard spec.registerNode(id: syntheticID, label: marker, shape: .circle, activeSubgraph: nil) else { return nil }
            return syntheticID
        }
        guard spec.registerNode(id: token, label: token, shape: .rounded, activeSubgraph: nil) else { return nil }
        return token
    }

    fileprivate static func parseSequenceDiagram(_ lines: [String]) -> MarkdownDiagramParseOutcome {
        var participants: [String] = []
        var indexByName: [String: Int] = [:]
        var messages: [SequenceMessageLayout] = []

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.lowercased().hasPrefix("participant ") || line.lowercased().hasPrefix("actor ") {
                let name = line.split(maxSplits: 1, whereSeparator: \.isWhitespace).dropFirst().first.map(String.init) ?? ""
                if resolveSequenceLane(for: name, participants: &participants, indexByName: &indexByName) == nil {
                    return .unsupportedOrOversized
                }
                continue
            }
            if let msg = parseSequenceArrow(line) {
                guard let fromIdx = resolveSequenceLane(for: msg.from, participants: &participants, indexByName: &indexByName),
                      let toIdx = resolveSequenceLane(for: msg.to, participants: &participants, indexByName: &indexByName),
                      messages.count < maxNodes else {
                    return .unsupportedOrOversized
                }
                let y = 64.0 + Double(messages.count) * 42.0
                messages.append(SequenceMessageLayout(fromLane: fromIdx, toLane: toIdx, label: msg.label, isDashed: msg.dashed, rowY: y))
            }
        }
        guard !participants.isEmpty else { return .unsupportedOrOversized }
        let laneSpacing = 160.0
        let centers = participants.indices.map { 84.0 + Double($0) * laneSpacing }
        let width = max(240.0, Double(participants.count) * laneSpacing + 32.0)
        let height = max(120.0, 84.0 + Double(messages.count) * 42.0)
        return .diagram(.sequence(participants: participants, laneCenters: centers, messages: messages, canvasWidth: width, canvasHeight: height))
    }

    private static func resolveSequenceLane(
        for rawName: String,
        participants: inout [String],
        indexByName: inout [String: Int]
    ) -> Int? {
        let name = rawName.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        guard !name.isEmpty else { return nil }
        if let existing = indexByName[name] { return existing }
        guard participants.count < maxNodes else { return nil }
        let idx = participants.count
        participants.append(String(name.prefix(48)))
        indexByName[name] = idx
        return idx
    }

    private static func parseSequenceArrow(_ line: String) -> (from: String, to: String, label: String, dashed: Bool)? {
        let arrows: [(token: String, dashed: Bool)] = [("-->>", true), ("->>", false), ("-->", true), ("->", false)]
        for arrow in arrows {
            if let range = line.range(of: arrow.token) {
                let from = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rest = String(line[range.upperBound...])
                guard let colon = rest.firstIndex(of: ":") else { continue }
                let to = String(rest[..<colon]).trimmingCharacters(in: .whitespaces)
                let label = String(rest[rest.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                return (from, to, String(label.prefix(96)), arrow.dashed)
            }
        }
        return nil
    }

    fileprivate static func layoutLayeredGraph(spec: ParsedGraphSpec, kind: MarkdownDiagramKind, direction: DiagramDirection) -> MarkdownDiagramModel {
        let ranks = computeCycleSafeRanks(order: spec.order, edges: spec.edges)
        var buckets: [Int: [String]] = [:]
        var maxRank = 0
        for id in spec.order {
            let r = min(maxDepth - 1, ranks[id] ?? 0)
            maxRank = max(maxRank, r)
            buckets[r, default: []].append(id)
        }
        let isHorizontal = (direction == .leftToRight || direction == .rightToLeft)
        var nodeMap: [String: GraphPositionedNode] = [:]
        var maxX = 220.0
        var maxY = 100.0

        for r in 0...maxRank {
            let effectiveRank = (direction == .rightToLeft || direction == .bottomToTop) ? (maxRank - r) : r
            let group = buckets[r] ?? []
            for (slot, id) in group.enumerated() {
                let label = spec.labels[id] ?? id
                let w = min(200.0, max(72.0, Double(label.count) * 7.6 + 26.0))
                let h = 34.0
                let x = isHorizontal ? (28.0 + Double(effectiveRank) * 190.0) : (28.0 + Double(slot) * 176.0)
                let y = isHorizontal ? (28.0 + Double(slot) * 68.0) : (28.0 + Double(effectiveRank) * 78.0)
                maxX = max(maxX, x + w + 28.0)
                maxY = max(maxY, y + h + 28.0)
                nodeMap[id] = GraphPositionedNode(
                    id: id, label: label, shape: spec.shapes[id] ?? .rect,
                    subgraphTitle: spec.subgraphs[id], x: x, y: y, width: w, height: h
                )
            }
        }

        let orderedNodes = spec.order.compactMap { nodeMap[$0] }
        let positionedEdges: [GraphPositionedEdge] = spec.edges.compactMap { e in
            guard let src = nodeMap[e.from], let dst = nodeMap[e.to] else { return nil }
            let start = DiagramPoint(x: isHorizontal ? src.x + src.width : src.x + src.width * 0.5, y: isHorizontal ? src.y + src.height * 0.5 : src.y + src.height)
            let end = DiagramPoint(x: isHorizontal ? dst.x : dst.x + dst.width * 0.5, y: isHorizontal ? dst.y + dst.height * 0.5 : dst.y)
            return GraphPositionedEdge(fromID: e.from, toID: e.to, label: e.label, style: e.style, fromPoint: start, toPoint: end)
        }
        return .graph(kind: kind, direction: direction, nodes: orderedNodes, edges: positionedEdges, canvasWidth: maxX, canvasHeight: maxY)
    }

    private static func computeCycleSafeRanks(order: [String], edges: [(from: String, to: String, label: String?, style: DiagramEdgeStyle)]) -> [String: Int] {
        var ranks = Dictionary(uniqueKeysWithValues: order.map { ($0, 0) })
        let passLimit = min(maxDepth, max(1, order.count))
        // Bounded Bellman-Ford style relaxation capped at `maxDepth` passes: cycle-proof without recursion (`CWE-674`).
        for _ in 0..<passLimit {
            var changed = false
            for edge in edges where edge.from != edge.to {
                let candidate = min(maxDepth - 1, (ranks[edge.from] ?? 0) + 1)
                if candidate > (ranks[edge.to] ?? 0) {
                    ranks[edge.to] = candidate
                    changed = true
                }
            }
            if !changed { break }
        }
        return ranks
    }
}
