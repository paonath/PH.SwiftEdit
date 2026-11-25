import Foundation

/// Iterative `O(N)` parser and horizontal tidy-tree layout engine for `markmap` and Mermaid `mindmap` blocks (`REQ-004`, `CWE-400`, `CWE-674`).
enum MarkmapParserAndLayout {
    private struct RawTreeNode {
        let id: Int
        let parentID: Int?
        let label: String
        let depth: Int
        var children: [Int] = []
        var subtreeHeight: Double = 0
        var centerY: Double = 0
    }

    static func parse(source: String, isMermaidMindmap: Bool) -> MarkdownDiagramParseOutcome {
        let rawLines = source.components(separatedBy: .newlines)
        let startIndex = isMermaidMindmap ? skipMermaidMindmapHeader(in: rawLines) : 0
        var nodes: [RawTreeNode] = []
        var stack: [(level: Int, id: Int, depth: Int)] = []

        for idx in startIndex..<rawLines.count {
            guard let parsed = parseTreeLine(rawLines[idx], isMermaidMindmap: isMermaidMindmap) else { continue }
            while let top = stack.last, top.level >= parsed.level {
                stack.removeLast()
            }
            let depth = (stack.last?.depth ?? -1) + 1
            if depth >= MarkdownDiagramParser.maxDepth || nodes.count >= MarkdownDiagramParser.maxNodes {
                return .unsupportedOrOversized
            }
            let parentID = stack.last?.id
            let newID = nodes.count
            nodes.append(RawTreeNode(id: newID, parentID: parentID, label: parsed.label, depth: depth))
            if let parentID {
                nodes[parentID].children.append(newID)
            }
            stack.append((level: parsed.level, id: newID, depth: depth))
        }

        guard !nodes.isEmpty else { return .unsupportedOrOversized }
        return .diagram(layoutTidyMindmap(&nodes))
    }

    private static func skipMermaidMindmapHeader(in lines: [String]) -> Int {
        for (idx, raw) in lines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("%%") { continue }
            if trimmed.lowercased().hasPrefix("mindmap") { return idx + 1 }
            return idx
        }
        return lines.count
    }

    private static func parseTreeLine(_ line: String, isMermaidMindmap: Bool) -> (level: Int, label: String)? {
        let trimmedRight = line.trimmingCharacters(in: .newlines)
        let trimmed = trimmedRight.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("%%") { return nil }

        if !isMermaidMindmap, let heading = parseHeadingLine(trimmed) {
            return heading
        }
        let leadingSpaces = countLeadingIndentSpaces(trimmedRight)
        let stripped = stripListOrMindmapDecorators(trimmed)
        guard !stripped.isEmpty else { return nil }
        let computedLevel = isMermaidMindmap ? (leadingSpaces + 1) : (100 + leadingSpaces)
        return (computedLevel, String(stripped.prefix(120)))
    }

    private static func parseHeadingLine(_ trimmed: String) -> (level: Int, label: String)? {
        guard trimmed.hasPrefix("#") else { return nil }
        var hashes = 0
        for ch in trimmed {
            if ch == "#" { hashes += 1 } else { break }
        }
        guard (1...6).contains(hashes) else { return nil }
        let rest = trimmed.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return nil }
        return (hashes, String(rest.prefix(120)))
    }

    private static func countLeadingIndentSpaces(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 }
            else if ch == "\t" { count += 4 }
            else { break }
        }
        return count
    }

    private static func stripListOrMindmapDecorators(_ text: String) -> String {
        var working = text
        for bullet in ["- ", "* ", "+ "] where working.hasPrefix(bullet) {
            working = String(working.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            break
        }
        if let dotIdx = working.firstIndex(of: "."),
           working[..<dotIdx].allSatisfy(\.isNumber),
           working.index(after: dotIdx) < working.endIndex {
            let after = working[working.index(after: dotIdx)...]
            if after.hasPrefix(" ") {
                working = after.trimmingCharacters(in: .whitespaces)
            }
        }
        return unwrapMindmapNodeToken(working)
    }

    private static func unwrapMindmapNodeToken(_ raw: String) -> String {
        var text = raw
        for (open, close) in [("((", "))"), ("([", "])"), ("{{", "}}"), ("(", ")"), ("[", "]")] {
            if let range = text.range(of: open), text.hasSuffix(close) {
                let innerStart = range.upperBound
                let innerEnd = text.index(text.endIndex, offsetBy: -close.count)
                if innerStart < innerEnd {
                    text = String(text[innerStart..<innerEnd])
                    break
                }
            }
        }
        return text.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
    }

    private static func layoutTidyMindmap(_ nodes: inout [RawTreeNode]) -> MarkdownDiagramModel {
        let rowHeight = 38.0
        let colStep = 176.0
        // Bottom-up pass: higher node indices always follow parents in pre-order insertion.
        for idx in nodes.indices.reversed() {
            if nodes[idx].children.isEmpty {
                nodes[idx].subtreeHeight = rowHeight
            } else {
                nodes[idx].subtreeHeight = nodes[idx].children.reduce(0.0) { $0 + nodes[$1].subtreeHeight }
            }
        }
        assignMindmapVerticalCenters(&nodes, rowHeight: rowHeight)

        var maxRight = 240.0
        var maxBottom = 80.0
        var positioned: [MindmapPositionedNode] = []
        positioned.reserveCapacity(nodes.count)
        for node in nodes {
            let w = min(220.0, max(76.0, Double(node.label.count) * 7.6 + 24.0))
            let h = 28.0
            let x = 24.0 + Double(node.depth) * colStep
            let y = max(12.0, node.centerY - h * 0.5)
            maxRight = max(maxRight, x + w + 24.0)
            maxBottom = max(maxBottom, y + h + 20.0)
            positioned.append(MindmapPositionedNode(
                id: node.id, parentID: node.parentID, label: node.label,
                depth: node.depth, x: x, y: y, width: w, height: h
            ))
        }
        return .mindmap(nodes: positioned, canvasWidth: maxRight, canvasHeight: maxBottom)
    }

    private static func assignMindmapVerticalCenters(_ nodes: inout [RawTreeNode], rowHeight: Double) {
        var rootTop = 16.0
        for idx in nodes.indices where nodes[idx].parentID == nil {
            placeSubtreeBands(rootID: idx, topY: rootTop, nodes: &nodes)
            rootTop += max(rowHeight, nodes[idx].subtreeHeight) + 12.0
        }
    }

    private static func placeSubtreeBands(rootID: Int, topY: Double, nodes: inout [RawTreeNode]) {
        var worklist: [(id: Int, bandTop: Double)] = [(rootID, topY)]
        while let item = worklist.popLast() {
            let span = nodes[item.id].subtreeHeight
            nodes[item.id].centerY = item.bandTop + span * 0.5
            var childTop = item.bandTop
            var placedChildren: [(id: Int, top: Double)] = []
            placedChildren.reserveCapacity(nodes[item.id].children.count)
            for childID in nodes[item.id].children {
                placedChildren.append((childID, childTop))
                childTop += nodes[childID].subtreeHeight
            }
            for child in placedChildren.reversed() {
                worklist.append((child.id, child.top))
            }
        }
    }
}
