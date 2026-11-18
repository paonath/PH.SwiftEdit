import Foundation

/// UTF-16 offset span pairing a matched opening delimiter (`(`, `[`, `{`) with its closing partner (`)`, `]`, `}`) (`AR-012`, `BC-006`).
public struct BracketPairSpan: Equatable, Sendable {
    public let openOffset: Int
    public let closeOffset: Int
    public let openSymbol: Character
    public let closeSymbol: Character

    public init(openOffset: Int, closeOffset: Int, openSymbol: Character, closeSymbol: Character) {
        self.openOffset = openOffset
        self.closeOffset = closeOffset
        self.openSymbol = openSymbol
        self.closeSymbol = closeSymbol
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

/// Revision-tagged bracket matching analysis for an immutable `DocumentSnapshot` (`AR-012`, `BC-006`).
public struct BracketBalanceResult: Equatable, Sendable {
    public let documentID: DocumentID
    public let revision: BufferRevision
    public let matchedPairs: [BracketPairSpan]
    public let unbalancedBrackets: [UnbalancedBracket]
    public let activePair: BracketPairSpan?

    public init(
        documentID: DocumentID,
        revision: BufferRevision,
        matchedPairs: [BracketPairSpan],
        unbalancedBrackets: [UnbalancedBracket],
        activePair: BracketPairSpan?
    ) {
        self.documentID = documentID
        self.revision = revision
        self.matchedPairs = matchedPairs
        self.unbalancedBrackets = unbalancedBrackets
        self.activePair = activePair
    }
}

/// Stateless analytical engine owning `() {} []` bracket balancing and two-snapshot Myers File Compare diffing (`AR-004`, `AR-012`, `BC-006`, `BC-011`, `SEC-012`).
public enum SearchDiffAndBracketEngine {
    /// Maximum UTF-16 code-unit length permitted on any single line before aborting delimiter scanning (`BC-011`, `SEC-012`).
    public static let maxBracketScanLineUTF16Length: Int = 4096

    /// Scans `()`, `{}`, and `[]` delimiters in `snapshot`, returning matched pairs, unbalanced delimiters, and the active pair at `caretLocation`.
    ///
    /// Security & complexity invariants (`BC-011`, `SEC-012`):
    /// - Rejects binary read-only buffers immediately with `.degradedOrTimedOut(.binarySnapshot)`.
    /// - Pre-scans UTF-16 code units per line without substring allocations and aborts with `.degradedOrTimedOut(.lineLengthExceeded)` if any line exceeds `4096` UTF-16 code units (e.g., minified single-line payloads).
    public static func evaluateBrackets(
        in snapshot: DocumentSnapshot,
        caretLocation: Int? = nil
    ) -> EngineEvaluationOutcome<BracketBalanceResult> {
        if snapshot.isBinaryReadOnly {
            return .degradedOrTimedOut(.binarySnapshot)
        }
        if let overlong = firstOverlongLine(in: snapshot.text, limit: maxBracketScanLineUTF16Length) {
            return .degradedOrTimedOut(.lineLengthExceeded(line: overlong.line, utf16Length: overlong.utf16Length))
        }

        var scanner = DelimiterStackScanner()
        scanner.scan(snapshot.text)

        let sortedPairs = scanner.matchedPairs.sorted { $0.openOffset < $1.openOffset }
        let sortedUnbalanced = scanner.finalizedUnbalanced().sorted { $0.offset < $1.offset }
        let active = caretLocation.flatMap { resolveActivePair(at: $0, in: sortedPairs) }

        return .completed(BracketBalanceResult(
            documentID: snapshot.id,
            revision: snapshot.revision,
            matchedPairs: sortedPairs,
            unbalancedBrackets: sortedUnbalanced,
            activePair: active
        ))
    }

    private static func firstOverlongLine(in text: String, limit: Int) -> (line: Int, utf16Length: Int)? {
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
        private var stack: [(offset: Int, symbol: Character)] = []
        private(set) var matchedPairs: [BracketPairSpan] = []
        private var unbalanced: [UnbalancedBracket] = []

        mutating func scan(_ text: String) {
            var utf16Offset = 0
            for character in text {
                consume(character: character, at: utf16Offset)
                utf16Offset += character.utf16.count
            }
        }

        func finalizedUnbalanced() -> [UnbalancedBracket] {
            unbalanced + stack.map { UnbalancedBracket(offset: $0.offset, symbol: $0.symbol) }
        }

        private mutating func consume(character: Character, at offset: Int) {
            switch character {
            case "(", "[", "{":
                stack.append((offset: offset, symbol: character))
            case ")", "]", "}":
                let expectedOpen = Self.matchingOpener(for: character)
                if let top = stack.last, top.symbol == expectedOpen {
                    _ = stack.popLast()
                    matchedPairs.append(BracketPairSpan(
                        openOffset: top.offset,
                        closeOffset: offset,
                        openSymbol: top.symbol,
                        closeSymbol: character
                    ))
                } else {
                    unbalanced.append(UnbalancedBracket(offset: offset, symbol: character))
                }
            default:
                break
            }
        }

        private static func matchingOpener(for closer: Character) -> Character? {
            switch closer {
            case ")": return "("
            case "]": return "["
            case "}": return "{"
            default: return nil
            }
        }
    }

    private static func resolveActivePair(at caret: Int, in pairs: [BracketPairSpan]) -> BracketPairSpan? {
        if let exact = pairs.first(where: { $0.openOffset == caret || $0.closeOffset == caret }) {
            return exact
        }
        if let trailing = pairs.last(where: { $0.openOffset + 1 == caret || $0.closeOffset + 1 == caret }) {
            return trailing
        }
        return pairs
            .filter { $0.openOffset < caret && caret < $0.closeOffset }
            .max(by: { $0.openOffset < $1.openOffset })
    }
}
