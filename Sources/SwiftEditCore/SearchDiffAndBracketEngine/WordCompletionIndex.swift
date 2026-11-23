import Foundation

/// Immutable, in-memory per-document word cache powering inline ghost-text completion (`REQ-020-01`, `UI-012`).
///
/// - Indexes only words longer than 3 UTF-16 units (`4...64`), built in one linear scalar pass with no regex (`CWE-400`).
/// - Stores unique words sorted ascending with their frequencies, so a lookup is one binary search plus a bounded scan.
/// - Never persisted: it lives only as long as the open document (`SEC-012`, privacy by design).
public struct WordCompletionIndex: Sendable, Equatable {
    /// Words shorter than this (UTF-16 units) are never indexed ("above 3 characters").
    public static let minIndexedWordUTF16Length = 4
    /// Longest indexed word; longer runs (hashes, base64 blobs) are skipped.
    public static let maxIndexedWordUTF16Length = 64
    /// Minimum typed prefix before a suggestion is offered.
    public static let minPrefixUTF16Length = 2
    /// Upper bound of candidates inspected per lookup so worst-case latency stays flat (`UI-012`).
    public static let maxScannedCandidates = 512
    /// Documents above this size are not indexed (completion silently disabled) to protect memory (`CWE-400`).
    public static let maxIndexedDocumentUTF16Length = 8 * 1024 * 1024

    public static let empty = WordCompletionIndex(words: [], counts: [])

    /// Sorted unique words.
    public let words: [String]
    /// Frequency of `words[i]`.
    public let counts: [Int]

    init(words: [String], counts: [Int]) {
        self.words = words
        self.counts = counts
    }

    /// Builds the index from `text`, ignoring any word that intersects `excluding` (the word being typed).
    public static func build(from text: String, excluding: TextRange? = nil) -> WordCompletionIndex {
        guard !text.isEmpty, text.utf16.count <= maxIndexedDocumentUTF16Length else { return .empty }
        var frequencies: [Substring: Int] = [:]
        let scalars = text.unicodeScalars
        var index = scalars.startIndex
        var utf16Offset = 0
        var runStart: String.Index?
        var runStartOffset = 0

        func closeRun(at end: String.Index, endOffset: Int) {
            guard let start = runStart else { return }
            runStart = nil
            let length = endOffset - runStartOffset
            guard length >= minIndexedWordUTF16Length, length <= maxIndexedWordUTF16Length else { return }
            if let excluding, runStartOffset <= excluding.upperBound, excluding.location <= endOffset {
                return
            }
            frequencies[text[start..<end], default: 0] += 1
        }

        while index < scalars.endIndex {
            let scalar = scalars[index]
            if WordOccurrenceScanner.isWordScalar(scalar) {
                if runStart == nil {
                    runStart = index
                    runStartOffset = utf16Offset
                }
            } else {
                closeRun(at: index, endOffset: utf16Offset)
            }
            utf16Offset += scalar.utf16.count
            index = scalars.index(after: index)
        }
        closeRun(at: scalars.endIndex, endOffset: utf16Offset)

        let sorted = frequencies.map { (String($0.key), $0.value) }.sorted { $0.0 < $1.0 }
        return WordCompletionIndex(words: sorted.map(\.0), counts: sorted.map(\.1))
    }

    /// Returns the remaining characters of the best indexed word starting with `prefix` (case-sensitive), or `nil`.
    ///
    /// Ranking: highest frequency, then shortest word, then alphabetical. A word equal to `prefix` is never suggested.
    public func completionSuffix(forPrefix prefix: String) -> String? {
        let prefixLength = prefix.utf16.count
        guard prefixLength >= Self.minPrefixUTF16Length, !words.isEmpty else { return nil }
        var lo = 0
        var hi = words.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if words[mid] < prefix { lo = mid + 1 } else { hi = mid }
        }
        var best: Int?
        var bestUTF16Length = 0
        var scanned = 0
        var idx = lo
        while idx < words.count, scanned < Self.maxScannedCandidates, words[idx].hasPrefix(prefix) {
            let word = words[idx]
            let wordLength = word.utf16.count
            if wordLength > prefixLength {
                if let current = best {
                    let candidateCount = counts[idx]
                    let currentCount = counts[current]
                    if candidateCount > currentCount
                        || (candidateCount == currentCount && wordLength < bestUTF16Length) {
                        best = idx
                        bestUTF16Length = wordLength
                    }
                } else {
                    best = idx
                    bestUTF16Length = wordLength
                }
            }
            scanned += 1
            idx += 1
        }
        guard let best else { return nil }
        let suffix = String(words[best].utf16.dropFirst(prefixLength))
        return suffix?.isEmpty == false ? suffix : nil
    }

    /// Word prefix ending exactly at `caret` (UTF-16), or `nil` when the caret is not at the end of a word run.
    ///
    /// The character right after the caret must not be a word character, so completion only triggers at a word end.
    public static func wordPrefix(endingAt caret: Int, in text: NSString) -> (range: TextRange, prefix: String)? {
        let length = text.length
        guard caret > 0, caret <= length else { return nil }
        if caret < length, isWordUnit(in: text, at: caret) { return nil }
        var start = caret
        while start > 0 {
            let unit = text.character(at: start - 1)
            if unit < 0x80 {
                guard isASCIIWordUnit(unit) else { break }
                start -= 1
            } else {
                let previous = text.rangeOfComposedCharacterSequence(at: start - 1)
                guard isWordComposedCharacter(in: text, range: previous) else { break }
                start = previous.location
            }
            if caret - start > maxIndexedWordUTF16Length { return nil }
        }
        guard caret - start >= minPrefixUTF16Length else { return nil }
        let range = NSRange(location: start, length: caret - start)
        return (TextRange(location: start, length: caret - start), text.substring(with: range))
    }

    @inline(__always)
    private static func isASCIIWordUnit(_ u: unichar) -> Bool {
        (u >= 0x41 && u <= 0x5A)
            || (u >= 0x61 && u <= 0x7A)
            || (u >= 0x30 && u <= 0x39)
            || u == 0x5F
    }

    @inline(__always)
    private static func isWordUnit(in text: NSString, at location: Int) -> Bool {
        let unit = text.character(at: location)
        if unit < 0x80 {
            return isASCIIWordUnit(unit)
        }
        let composed = text.rangeOfComposedCharacterSequence(at: location)
        return isWordComposedCharacter(in: text, range: composed)
    }

    private static func isWordComposedCharacter(in text: NSString, range composed: NSRange) -> Bool {
        guard let scalar = text.substring(with: composed).unicodeScalars.first else { return false }
        return WordOccurrenceScanner.isWordScalar(scalar)
    }
}
