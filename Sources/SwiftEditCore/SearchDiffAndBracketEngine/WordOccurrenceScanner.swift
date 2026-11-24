import Foundation

/// Linear, zero-regex whole-word occurrence scanner for editor selection highlighting (`UI-002`, `CWE-400`, `SEC-012`).
///
/// When the user selects a single whole word (`2...128` UTF-16 units), returns all *other* whole-word occurrences in the
/// document; when the selection is any other single-line character group (a partial word, `->`, `a, b`), returns all
/// *other* case-sensitive literal occurrences instead (`REQ-020-05`). Results are sorted in ascending UTF-16 offset order,
/// never overlap the primary selection, and drive a softer, accessible secondary tint.
/// Whitespace-only and multi-line selections never highlight anything.
public enum WordOccurrenceScanner {
    public static let minWordUTF16Length = 2
    public static let maxWordUTF16Length = 128
    public static let defaultMaxMatches = 1_000

    /// Returns all other whole-word occurrences of the word selected by `selection` in `snapshot.text`,
    /// sorted by ascending UTF-16 location and excluding `selection` itself.
    public static func scan(
        selection: TextRange,
        in snapshot: DocumentSnapshot,
        maxMatches: Int = WordOccurrenceScanner.defaultMaxMatches
    ) -> [TextRange] {
        guard wordScanAllowsRequest(selection: selection, snapshot: snapshot, maxMatches: maxMatches) else {
            return []
        }

        let text = snapshot.text
        guard let (selStart, selEnd) = wordScanResolveSelectionIndices(selection: selection, in: text) else {
            return []
        }

        let wordSlice = text[selStart..<selEnd]
        guard let traits = wordScanClassifySelection(wordSlice, in: text, selStart: selStart, selEnd: selEnd) else {
            return []
        }

        guard traits.isWholeWord else {
            return scanLiteral(String(wordSlice), in: text, excluding: selection, maxMatches: maxMatches)
        }

        if traits.isAllASCII,
           let fast = scanASCIIWordUTF8(word: wordSlice, in: text, excluding: selection, maxMatches: maxMatches) {
            return fast
        }

        return scanUnicodeWord(
            word: String(wordSlice),
            in: text,
            excluding: selection,
            maxMatches: maxMatches
        )
    }

    @inline(__always)
    static func isWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.isASCII {
            return isASCIIWordByte(UInt8(scalar.value))
        }
        return scalar.properties.isAlphabetic || CharacterSet.decimalDigits.contains(scalar)
    }
}

private extension WordOccurrenceScanner {
    struct SelectionWordTraits {
        let isWholeWord: Bool
        let isAllASCII: Bool
    }

    @inline(__always)
    static func isASCIIWordByte(_ b: UInt8) -> Bool {
        (b >= 0x41 && b <= 0x5A)
            || (b >= 0x61 && b <= 0x7A)
            || (b >= 0x30 && b <= 0x39)
            || b == 0x5F
    }

    @inline(__always)
    static func wordScanUTF8Step(forLeadByte lead: UInt8) -> (bytes: Int, utf16: Int) {
        if lead < 0x80 { return (1, 1) }
        if lead < 0xE0 { return (2, 1) }
        if lead < 0xF0 { return (3, 1) }
        return (4, 2)
    }

    static func wordScanAllowsRequest(
        selection: TextRange,
        snapshot: DocumentSnapshot,
        maxMatches: Int
    ) -> Bool {
        !snapshot.isBinaryReadOnly
            && !snapshot.isDegradedPlainText
            && maxMatches > 0
            && selection.location >= 0
            && selection.length >= minWordUTF16Length
            && selection.length <= maxWordUTF16Length
    }

    static func wordScanResolveSelectionIndices(
        selection: TextRange,
        in text: String
    ) -> (String.Index, String.Index)? {
        let utf16 = text.utf16
        guard selection.upperBound <= utf16.count,
              let selStart = utf16.index(utf16.startIndex, offsetBy: selection.location, limitedBy: utf16.endIndex),
              let selEnd = utf16.index(selStart, offsetBy: selection.length, limitedBy: utf16.endIndex) else {
            return nil
        }
        return (selStart, selEnd)
    }

    static func wordScanClassifySelection(
        _ wordSlice: Substring,
        in text: String,
        selStart: String.Index,
        selEnd: String.Index
    ) -> SelectionWordTraits? {
        guard !wordSlice.isEmpty else { return nil }
        var isAllWordScalars = true
        var isAllASCII = true
        var hasVisibleScalar = false

        for scalar in wordSlice.unicodeScalars {
            if wordScanIsLineBreakScalar(scalar) { return nil }
            if !scalar.properties.isWhitespace { hasVisibleScalar = true }
            if !isWordScalar(scalar) { isAllWordScalars = false }
            if !scalar.isASCII { isAllASCII = false }
        }
        guard hasVisibleScalar else { return nil }

        let isWholeWord = isAllWordScalars && wordScanHasUnicodeWordBoundaries(in: text, start: selStart, end: selEnd)
        return SelectionWordTraits(isWholeWord: isWholeWord, isAllASCII: isAllASCII)
    }

    static func wordScanIsLineBreakScalar(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "\n" || scalar == "\r" || scalar == "\u{2028}" || scalar == "\u{2029}"
    }

    static func wordScanHasUnicodeWordBoundaries(
        in text: String,
        start: String.Index,
        end: String.Index
    ) -> Bool {
        if start > text.startIndex {
            let prev = text.unicodeScalars.index(before: start)
            if isWordScalar(text.unicodeScalars[prev]) { return false }
        }
        if end < text.endIndex, isWordScalar(text.unicodeScalars[end]) {
            return false
        }
        return true
    }
}

private extension WordOccurrenceScanner {
    /// Decodes the Unicode scalar ending immediately before byte index `pos` in a valid UTF-8 buffer.
    static func previousScalar(in base: UnsafePointer<UInt8>, before pos: Int) -> Unicode.Scalar? {
        var start = pos - 1
        while start > 0 && (base[start] & 0xC0) == 0x80 {
            start -= 1
        }
        return decodeUTF8Scalar(in: base, at: start, limit: pos)
    }

    /// Decodes the Unicode scalar starting at byte index `pos` in a valid UTF-8 buffer.
    static func decodeUTF8Scalar(in base: UnsafePointer<UInt8>, at pos: Int, limit: Int) -> Unicode.Scalar? {
        guard pos < limit else { return nil }
        let b0 = UInt32(base[pos])
        if b0 < 0x80 { return Unicode.Scalar(b0) }
        if b0 < 0xE0, pos + 1 < limit {
            let v = ((b0 & 0x1F) << 6) | UInt32(base[pos + 1] & 0x3F)
            return Unicode.Scalar(v)
        }
        if b0 < 0xF0, pos + 2 < limit {
            let v = ((b0 & 0x0F) << 12) | (UInt32(base[pos + 1] & 0x3F) << 6) | UInt32(base[pos + 2] & 0x3F)
            return Unicode.Scalar(v)
        }
        if pos + 3 < limit {
            let v = ((b0 & 0x07) << 18)
                | (UInt32(base[pos + 1] & 0x3F) << 12)
                | (UInt32(base[pos + 2] & 0x3F) << 6)
                | UInt32(base[pos + 3] & 0x3F)
            return Unicode.Scalar(v)
        }
        return nil
    }

    /// Zero-bridging single-pass UTF-8 scan for ASCII whole words (supports arbitrary UTF-8 documents including Unicode punctuation boundaries like `“word”` and `—word`).
    static func scanASCIIWordUTF8(
        word: Substring,
        in text: String,
        excluding selection: TextRange,
        maxMatches: Int
    ) -> [TextRange]? {
        text.utf8.withContiguousStorageIfAvailable { buf -> [TextRange]? in
            wordScanContiguousASCII(buf, word: word, in: text, excluding: selection, maxMatches: maxMatches)
        } ?? nil
    }

    static func wordScanContiguousASCII(
        _ buf: UnsafeBufferPointer<UInt8>,
        word: Substring,
        in text: String,
        excluding selection: TextRange,
        maxMatches: Int
    ) -> [TextRange] {
        let n = buf.count
        guard let base = buf.baseAddress else { return [] }
        let wordStart = word.startIndex.utf8Offset(in: text)
        let m = word.utf8.count
        guard m > 0, m <= n, wordStart + m <= n else { return [] }
        let wBase = base.advanced(by: wordStart)

        let firstByte = wBase[0]
        let limit = n - m
        var matches: [TextRange] = []
        matches.reserveCapacity(min(32, maxMatches))
        var index = 0
        var utf16Pos = 0

        while index <= limit {
            let b = base[index]
            if b != firstByte {
                let step = wordScanUTF8Step(forLeadByte: b)
                index += step.bytes
                utf16Pos += step.utf16
            } else if wordScanMatchesWholeASCIIWord(at: index, base: base, textCount: n, wBase: wBase, wordLength: m) {
                let range = TextRange(location: utf16Pos, length: m)
                if range != selection {
                    matches.append(range)
                    if matches.count >= maxMatches { return matches }
                }
                index += m
                utf16Pos += m
            } else {
                wordScanSkipRemainingASCIIIdentifier(base: base, limit: limit, index: &index, utf16Pos: &utf16Pos)
            }
        }
        return matches
    }

    static func wordScanMatchesWholeASCIIWord(
        at index: Int,
        base: UnsafePointer<UInt8>,
        textCount: Int,
        wBase: UnsafePointer<UInt8>,
        wordLength m: Int
    ) -> Bool {
        guard m == 1 || base[index + m - 1] == wBase[m - 1] else { return false }
        guard wordScanHasLeftUTF8Boundary(in: base, at: index),
              wordScanHasRightUTF8Boundary(in: base, at: index + m, count: textCount) else {
            return false
        }
        return m <= 2 || memcmp(base.advanced(by: index + 1), wBase.advanced(by: 1), m - 2) == 0
    }

    static func wordScanHasLeftUTF8Boundary(in base: UnsafePointer<UInt8>, at pos: Int) -> Bool {
        guard pos > 0 else { return true }
        let prev = base[pos - 1]
        if prev < 0x80 { return !isASCIIWordByte(prev) }
        guard let scalar = previousScalar(in: base, before: pos) else { return false }
        return !isWordScalar(scalar)
    }

    static func wordScanHasRightUTF8Boundary(in base: UnsafePointer<UInt8>, at pos: Int, count: Int) -> Bool {
        guard pos < count else { return true }
        let next = base[pos]
        if next < 0x80 { return !isASCIIWordByte(next) }
        guard let scalar = decodeUTF8Scalar(in: base, at: pos, limit: count) else { return false }
        return !isWordScalar(scalar)
    }

    static func wordScanSkipRemainingASCIIIdentifier(
        base: UnsafePointer<UInt8>,
        limit: Int,
        index: inout Int,
        utf16Pos: inout Int
    ) {
        index += 1
        utf16Pos += 1
        while index <= limit && isASCIIWordByte(base[index]) {
            index += 1
            utf16Pos += 1
        }
    }

    /// Case-sensitive, non-overlapping literal occurrences of an arbitrary character group, skipping any match that
    /// overlaps the primary selection (`REQ-020-05`). Uses `NSString` literal search (no regex, `CWE-400`).
    static func scanLiteral(
        _ needle: String,
        in text: String,
        excluding selection: TextRange,
        maxMatches: Int
    ) -> [TextRange] {
        let nsText = text as NSString
        let totalLength = nsText.length
        var searchRange = NSRange(location: 0, length: totalLength)
        var matches: [TextRange] = []
        while searchRange.length > 0 {
            let found = nsText.range(of: needle, options: [.literal], range: searchRange)
            guard found.location != NSNotFound, found.length > 0 else { break }
            let candidate = TextRange(location: found.location, length: found.length)
            let overlapsSelection = candidate.location < selection.upperBound && selection.location < candidate.upperBound
            if !overlapsSelection {
                matches.append(candidate)
                if matches.count >= maxMatches { break }
            }
            let nextStart = found.location + found.length
            searchRange = NSRange(location: nextStart, length: totalLength - nextStart)
        }
        return matches
    }

    /// Unicode-aware whole-word literal fallback for accented / non-ASCII identifiers.
    static func scanUnicodeWord(
        word: String,
        in text: String,
        excluding selection: TextRange,
        maxMatches: Int
    ) -> [TextRange] {
        let nsText = text as NSString
        let totalLength = nsText.length
        var searchRange = NSRange(location: 0, length: totalLength)
        var matches: [TextRange] = []
        let utf16 = text.utf16
        var cursorIdx = utf16.startIndex
        var cursorOffset = 0

        while searchRange.length > 0 {
            let found = nsText.range(of: word, options: [.literal], range: searchRange)
            guard found.location != NSNotFound && found.length > 0 else { break }
            let candidate = TextRange(location: found.location, length: found.length)
            if wordScanAcceptsUnicodeCandidate(
                candidate,
                excluding: selection,
                in: text,
                utf16: utf16,
                cursorIdx: &cursorIdx,
                cursorOffset: &cursorOffset
            ) {
                matches.append(candidate)
                if matches.count >= maxMatches { break }
            }
            let nextStart = found.location + found.length
            guard nextStart <= totalLength else { break }
            searchRange = NSRange(location: nextStart, length: totalLength - nextStart)
        }
        return matches
    }

    static func wordScanAcceptsUnicodeCandidate(
        _ candidate: TextRange,
        excluding selection: TextRange,
        in text: String,
        utf16: String.UTF16View,
        cursorIdx: inout String.UTF16View.Index,
        cursorOffset: inout Int
    ) -> Bool {
        guard candidate != selection,
              let startIdx = utf16.index(cursorIdx, offsetBy: candidate.location - cursorOffset, limitedBy: utf16.endIndex),
              let endIdx = utf16.index(startIdx, offsetBy: candidate.length, limitedBy: utf16.endIndex) else {
            return false
        }
        cursorIdx = endIdx
        cursorOffset = candidate.upperBound
        return wordScanHasUnicodeWordBoundaries(in: text, start: startIdx, end: endIdx)
    }
}

private extension String.Index {
    @inline(__always)
    func utf8Offset(in string: String) -> Int {
        string.utf8.distance(from: string.utf8.startIndex, to: self)
    }
}
