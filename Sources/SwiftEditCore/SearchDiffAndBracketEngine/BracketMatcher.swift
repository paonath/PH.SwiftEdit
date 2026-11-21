import Foundation

/// UTF-16 offset span pairing a matched opening delimiter (`(`, `[`, `{`) with its closing partner (`)`, `]`, `}`) (`AR-012`, `BC-006`).
public struct BracketPairSpan: Equatable, Sendable {
    public let openOffset: Int
    public let closeOffset: Int
    public let openSymbol: Character
    public let closeSymbol: Character
    /// 0-based nesting depth recorded when the opening delimiter was pushed onto the delimiter stack (`AR-012`).
    public let nestingDepth: Int

    public init(
        openOffset: Int,
        closeOffset: Int,
        openSymbol: Character,
        closeSymbol: Character,
        nestingDepth: Int = 0
    ) {
        self.openOffset = openOffset
        self.closeOffset = closeOffset
        self.openSymbol = openSymbol
        self.closeSymbol = closeSymbol
        self.nestingDepth = nestingDepth
    }
}

/// Unmatched opening or closing bracket delimiter recorded with its 0-based UTF-16 offset (`AR-012`).
public struct UnbalancedBracket: Equatable, Sendable {
    public let offset: Int
    public let symbol: Character

    public init(offset: Int, symbol: Character) {
        self.offset = offset
        self.symbol = symbol
    }
}

/// Revision-cached delimiter topology enabling `O(log N)` caret active-pair and enclosing-pair resolution without rescanning large buffers (`PERF-002`, `BC-006`).
public struct BracketTopology: Equatable, Sendable {
    public let documentID: DocumentID
    public let revision: BufferRevision
    public let matchedPairs: [BracketPairSpan]
    public let unbalancedBrackets: [UnbalancedBracket]
    /// Sorted-index parent pointer (`-1` for root pairs) for `O(depth)` enclosing/close-offset lookup.
    fileprivate let parentIndices: [Int]

    public init(
        documentID: DocumentID,
        revision: BufferRevision,
        matchedPairs: [BracketPairSpan],
        unbalancedBrackets: [UnbalancedBracket]
    ) {
        self.documentID = documentID
        self.revision = revision
        let sorted = matchedPairs.sorted { $0.openOffset < $1.openOffset }
        self.matchedPairs = sorted
        self.unbalancedBrackets = unbalancedBrackets.sorted { $0.offset < $1.offset }
        self.parentIndices = Self.computeParentIndices(sortedPairs: sorted)
    }

    fileprivate init(
        documentID: DocumentID,
        revision: BufferRevision,
        presortedMatchedPairs: [BracketPairSpan],
        presortedUnbalancedBrackets: [UnbalancedBracket],
        parentIndices: [Int]
    ) {
        self.documentID = documentID
        self.revision = revision
        self.matchedPairs = presortedMatchedPairs
        self.unbalancedBrackets = presortedUnbalancedBrackets
        self.parentIndices = parentIndices
    }

    fileprivate static func computeParentIndices(sortedPairs: [BracketPairSpan]) -> [Int] {
        var parents = Array(repeating: -1, count: sortedPairs.count)
        var ancestorStack: [Int] = []
        for idx in sortedPairs.indices {
            let open = sortedPairs[idx].openOffset
            while let top = ancestorStack.last, sortedPairs[top].closeOffset < open {
                ancestorStack.removeLast()
            }
            if let parent = ancestorStack.last {
                parents[idx] = parent
            }
            ancestorStack.append(idx)
        }
        return parents
    }
}

/// Revision-tagged bracket matching analysis for an immutable `DocumentSnapshot` (`AR-012`, `BC-006`).
public struct BracketBalanceResult: Equatable, Sendable {
    public let documentID: DocumentID
    public let revision: BufferRevision
    public let matchedPairs: [BracketPairSpan]
    public let unbalancedBrackets: [UnbalancedBracket]
    public let activePair: BracketPairSpan?
    /// Matched pairs enclosing `caretLocation`, sorted outer-to-inner by ascending `openOffset` (`AR-012`).
    public let enclosingPairs: [BracketPairSpan]

    public init(
        documentID: DocumentID,
        revision: BufferRevision,
        matchedPairs: [BracketPairSpan],
        unbalancedBrackets: [UnbalancedBracket],
        activePair: BracketPairSpan?,
        enclosingPairs: [BracketPairSpan] = []
    ) {
        self.documentID = documentID
        self.revision = revision
        self.matchedPairs = matchedPairs
        self.unbalancedBrackets = unbalancedBrackets
        self.activePair = activePair
        self.enclosingPairs = enclosingPairs
    }
}

/// Stateless analytical engine owning `() {} []` bracket balancing and two-snapshot Myers File Compare diffing (`AR-004`, `AR-012`, `BC-006`, `BC-011`, `SEC-012`).
public enum SearchDiffAndBracketEngine {
    /// Maximum UTF-16 code-unit length permitted on any single line before aborting delimiter scanning (`BC-011`, `SEC-012`).
    public static let maxBracketScanLineUTF16Length: Int = 4096

    /// Scans `()`, `{}`, and `[]` delimiters in a single raw UTF-8 pass per `(DocumentID, BufferRevision)` into a reusable `BracketTopology` (`PERF-002`, `BC-011`, `SEC-012`).
    public static func scanTopology(in snapshot: DocumentSnapshot) -> EngineEvaluationOutcome<BracketTopology> {
        if snapshot.isBinaryReadOnly {
            return .degradedOrTimedOut(.binarySnapshot)
        }

        var scanner = DelimiterStackScanner()
        if let overlong = scanner.scanCheckingLineLength(snapshot.text, limit: maxBracketScanLineUTF16Length) {
            return .degradedOrTimedOut(.lineLengthExceeded(line: overlong.line, utf16Length: overlong.utf16Length))
        }

        let (sortedPairs, parentIndices) = scanner.finalizedSortedMatchedPairsAndParents()
        return .completed(BracketTopology(
            documentID: snapshot.id,
            revision: snapshot.revision,
            presortedMatchedPairs: sortedPairs,
            presortedUnbalancedBrackets: scanner.finalizedSortedUnbalanced(),
            parentIndices: parentIndices
        ))
    }

    /// Resolves the active pair in `O(log N + depth)` from a cached `BracketTopology` (`PERF-002`).
    public static func resolveActivePair(in topology: BracketTopology, caretLocation: Int) -> BracketPairSpan? {
        resolveActiveAndEnclosing(
            at: caretLocation,
            in: topology.matchedPairs,
            parentIndices: topology.parentIndices,
            collectEnclosing: false
        ).active
    }

    /// Projects a complete `BracketBalanceResult` from a cached `BracketTopology` at `caretLocation` in one `O(log N + depth)` lookup without re-scanning text (`PERF-002`).
    public static func balanceResult(from topology: BracketTopology, caretLocation: Int?) -> BracketBalanceResult {
        let active: BracketPairSpan?
        let enclosing: [BracketPairSpan]
        if let caretLocation {
            let resolved = resolveActiveAndEnclosing(
                at: caretLocation,
                in: topology.matchedPairs,
                parentIndices: topology.parentIndices,
                collectEnclosing: true
            )
            active = resolved.active
            enclosing = resolved.enclosing
        } else {
            active = nil
            enclosing = []
        }
        return BracketBalanceResult(
            documentID: topology.documentID,
            revision: topology.revision,
            matchedPairs: topology.matchedPairs,
            unbalancedBrackets: topology.unbalancedBrackets,
            activePair: active,
            enclosingPairs: enclosing
        )
    }

    /// Scans `()`, `{}`, and `[]` delimiters in `snapshot`, returning matched pairs, unbalanced delimiters, and the active pair at `caretLocation`.
    ///
    /// Security & complexity invariants (`BC-011`, `SEC-012`):
    /// - Rejects binary read-only buffers immediately with `.degradedOrTimedOut(.binarySnapshot)`.
    /// - Enforces the `4096` UTF-16 code-unit per-line limit inline during the single UTF-8 pass and aborts with `.degradedOrTimedOut(.lineLengthExceeded)` on minified/overlong lines.
    public static func evaluateBrackets(
        in snapshot: DocumentSnapshot,
        caretLocation: Int? = nil
    ) -> EngineEvaluationOutcome<BracketBalanceResult> {
        switch scanTopology(in: snapshot) {
        case .completed(let topology):
            return .completed(balanceResult(from: topology, caretLocation: caretLocation))
        case .degradedOrTimedOut(let reason):
            return .degradedOrTimedOut(reason)
        }
    }

    static func firstOverlongLine(in text: String, limit: Int) -> (line: Int, utf16Length: Int)? {
        if let fast = text.utf8.withContiguousStorageIfAvailable({ buf -> (line: Int, utf16Length: Int)? in
            let count = buf.count
            guard let base = buf.baseAddress, count > 0 else { return nil }
            var lineNumber = 1
            var currentLineLength = 0
            var i = 0
            while i < count {
                let b = base[i]
                if b == 0x0A {
                    if currentLineLength > limit { return (lineNumber, currentLineLength) }
                    lineNumber += 1
                    currentLineLength = 0
                    i += 1
                } else if b == 0x0D {
                    if currentLineLength > limit { return (lineNumber, currentLineLength) }
                    lineNumber += 1
                    currentLineLength = 0
                    if i + 1 < count && base[i + 1] == 0x0A {
                        i += 2
                    } else {
                        i += 1
                    }
                } else if b < 0x80 {
                    currentLineLength += 1
                    i += 1
                } else if b < 0xE0 {
                    currentLineLength += 1
                    i += 2
                } else if b < 0xF0 {
                    currentLineLength += 1
                    i += 3
                } else {
                    currentLineLength += 2
                    i += 4
                }
            }
            if currentLineLength > limit { return (lineNumber, currentLineLength) }
            return nil
        }) {
            return fast
        }
        let units = text.utf16
        var index = units.startIndex
        var lineNumber = 1
        var currentLineLength = 0

        while index < units.endIndex {
            let unit = units[index]
            if unit == 0x0D || unit == 0x0A {
                if currentLineLength > limit {
                    return (lineNumber, currentLineLength)
                }
                lineNumber += 1
                currentLineLength = 0
                let nextIndex = units.index(after: index)
                if unit == 0x0D, nextIndex < units.endIndex, units[nextIndex] == 0x0A {
                    index = units.index(after: nextIndex)
                } else {
                    index = nextIndex
                }
            } else {
                currentLineLength += 1
                index = units.index(after: index)
            }
        }

        if currentLineLength > limit {
            return (lineNumber, currentLineLength)
        }
        return nil
    }

    private struct DelimiterStackScanner {
        private static let openParen: UInt8 = 0x28    // '('
        private static let closeParen: UInt8 = 0x29   // ')'
        private static let openBracket: UInt8 = 0x5B  // '['
        private static let closeBracket: UInt8 = 0x5D // ']'
        private static let openBrace: UInt8 = 0x7B    // '{'
        private static let closeBrace: UInt8 = 0x7D   // '}'

        private struct OpenEntry {
            let offset: Int
            let byte: UInt8
            let depth: Int
            let slotIndex: Int
        }

        private var stack: [OpenEntry] = []
        /// Slots allocated in strict ascending `openOffset` order; matched entries are filled in-place so compaction is `O(P)` without sorting.
        private var pairSlots: [BracketPairSpan?] = []
        private var matchedCount: Int = 0
        private var unbalancedClosers: [UnbalancedBracket] = []

        mutating func scanCheckingLineLength(_ text: String, limit: Int) -> (line: Int, utf16Length: Int)? {
            var contiguous = text
            contiguous.makeContiguousUTF8()
            return contiguous.utf8.withContiguousStorageIfAvailable { buf -> (line: Int, utf16Length: Int)? in
                let count = buf.count
                guard let base = buf.baseAddress, count > 0 else { return nil }
                var lineNumber = 1
                var currentLineLength = 0
                var utf16Offset = 0
                var i = 0
                while i < count {
                    let b = base[i]
                    if b < 0x80 {
                        if b == 0x0A {
                            if currentLineLength > limit { return (lineNumber, currentLineLength) }
                            lineNumber += 1
                            currentLineLength = 0
                            utf16Offset += 1
                            i += 1
                            continue
                        } else if b == 0x0D {
                            if currentLineLength > limit { return (lineNumber, currentLineLength) }
                            lineNumber += 1
                            currentLineLength = 0
                            if i + 1 < count && base[i + 1] == 0x0A {
                                utf16Offset += 2
                                i += 2
                            } else {
                                utf16Offset += 1
                                i += 1
                            }
                            continue
                        }
                        switch b {
                        case Self.openParen, Self.openBracket, Self.openBrace:
                            let slot = pairSlots.count
                            pairSlots.append(nil)
                            stack.append(OpenEntry(offset: utf16Offset, byte: b, depth: stack.count, slotIndex: slot))
                        case Self.closeParen, Self.closeBracket, Self.closeBrace:
                            let expectedOpen = Self.matchingOpenerByte(for: b)
                            if let top = stack.last, top.byte == expectedOpen {
                                _ = stack.popLast()
                                pairSlots[top.slotIndex] = BracketPairSpan(
                                    openOffset: top.offset,
                                    closeOffset: utf16Offset,
                                    openSymbol: Self.character(for: top.byte),
                                    closeSymbol: Self.character(for: b),
                                    nestingDepth: top.depth
                                )
                                matchedCount += 1
                            } else {
                                unbalancedClosers.append(UnbalancedBracket(offset: utf16Offset, symbol: Self.character(for: b)))
                            }
                        default:
                            break
                        }
                        currentLineLength += 1
                        utf16Offset += 1
                        i += 1
                    } else if b < 0xE0 {
                        currentLineLength += 1
                        utf16Offset += 1
                        i += 2
                    } else if b < 0xF0 {
                        currentLineLength += 1
                        utf16Offset += 1
                        i += 3
                    } else {
                        currentLineLength += 2
                        utf16Offset += 2
                        i += 4
                    }
                }
                if currentLineLength > limit {
                    return (lineNumber, currentLineLength)
                }
                return nil
            } ?? nil
        }

        func finalizedSortedMatchedPairsAndParents() -> ([BracketPairSpan], [Int]) {
            guard matchedCount > 0 else { return ([], []) }
            var sorted: [BracketPairSpan] = []
            sorted.reserveCapacity(matchedCount)
            for slot in pairSlots {
                if let pair = slot {
                    sorted.append(pair)
                }
            }
            let parents = BracketTopology.computeParentIndices(sortedPairs: sorted)
            return (sorted, parents)
        }

        /// Merges already-sorted `unbalancedClosers` and already-sorted remaining `stack` openers in linear `O(U)` time.
        func finalizedSortedUnbalanced() -> [UnbalancedBracket] {
            let closerCount = unbalancedClosers.count
            let openerCount = stack.count
            if openerCount == 0 { return unbalancedClosers }
            var result: [UnbalancedBracket] = []
            result.reserveCapacity(closerCount + openerCount)
            var ci = 0
            var oi = 0
            while ci < closerCount && oi < openerCount {
                let closer = unbalancedClosers[ci]
                let opener = stack[oi]
                if closer.offset < opener.offset {
                    result.append(closer)
                    ci += 1
                } else {
                    result.append(UnbalancedBracket(offset: opener.offset, symbol: Self.character(for: opener.byte)))
                    oi += 1
                }
            }
            while ci < closerCount {
                result.append(unbalancedClosers[ci])
                ci += 1
            }
            while oi < openerCount {
                let opener = stack[oi]
                result.append(UnbalancedBracket(offset: opener.offset, symbol: Self.character(for: opener.byte)))
                oi += 1
            }
            return result
        }

        private static func matchingOpenerByte(for closer: UInt8) -> UInt8 {
            switch closer {
            case closeParen: return openParen
            case closeBracket: return openBracket
            case closeBrace: return openBrace
            default: return 0
            }
        }

        private static func character(for byte: UInt8) -> Character {
            switch byte {
            case openParen: return "("
            case closeParen: return ")"
            case openBracket: return "["
            case closeBracket: return "]"
            case openBrace: return "{"
            case closeBrace: return "}"
            default: return "?"
            }
        }
    }

    private static func lastOpenAtOrBefore(_ target: Int, in pairs: [BracketPairSpan]) -> Int? {
        guard !pairs.isEmpty else { return nil }
        var low = 0
        var high = pairs.count
        while low < high {
            let mid = low + (high - low) / 2
            if pairs[mid].openOffset <= target {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low > 0 ? low - 1 : nil
    }

    /// Fused `O(log N + depth)` resolution computing `activePair` and (optionally) `enclosingPairs` in a single binary search.
    private static func resolveActiveAndEnclosing(
        at caret: Int,
        in pairs: [BracketPairSpan],
        parentIndices: [Int],
        collectEnclosing: Bool
    ) -> (active: BracketPairSpan?, enclosing: [BracketPairSpan]) {
        guard let idx = lastOpenAtOrBefore(caret, in: pairs) else {
            return (nil, [])
        }

        var exactMatch: BracketPairSpan?
        var innerEnclosing: BracketPairSpan?
        var enclosing: [BracketPairSpan] = []

        var curr = idx
        while curr >= 0 {
            let p = pairs[curr]
            if exactMatch == nil && (p.openOffset == caret || p.closeOffset == caret) {
                exactMatch = p
            }
            if innerEnclosing == nil && p.openOffset < caret && caret < p.closeOffset {
                innerEnclosing = p
            }
            if collectEnclosing && p.openOffset <= caret && caret <= p.closeOffset {
                enclosing.append(p)
            }
            curr = parentIndices[curr]
        }

        if collectEnclosing && enclosing.count > 1 {
            enclosing.reverse()
        }

        if let exactMatch {
            return (exactMatch, enclosing)
        }

        // Check caret - 1 (caret immediately after an opener or closer) without a second binary search:
        // since `pairs` is sorted by strictly increasing `openOffset`, `lastOpenAtOrBefore(caret - 1)` is either `idx` (if `pairs[idx].openOffset < caret`) or `idx - 1` (if `pairs[idx].openOffset == caret`).
        if caret > 0 {
            let prevIdx = pairs[idx].openOffset < caret ? idx : (idx - 1)
            var prevCurr = prevIdx
            while prevCurr >= 0 {
                let p = pairs[prevCurr]
                if p.openOffset + 1 == caret || p.closeOffset + 1 == caret {
                    return (p, enclosing)
                }
                prevCurr = parentIndices[prevCurr]
            }
        }

        return (innerEnclosing, enclosing)
    }
}
