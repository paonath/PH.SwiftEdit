import Foundation

/// Linear, zero-regex whole-word occurrence scanner for editor selection highlighting (`UI-002`, `CWE-400`, `SEC-012`).
///
/// When the user selects (e.g. double-clicks) a single whole word (`2...128` UTF-16 units), returns all *other*
/// whole-word occurrences in the document (sorted in ascending UTF-16 offset order, excluding the primary selection)
/// so the editor can highlight them with a softer, accessible secondary tint.
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
        guard !snapshot.isBinaryReadOnly,
              !snapshot.isDegradedPlainText,
              maxMatches > 0,
              selection.location >= 0,
              selection.length >= minWordUTF16Length,
              selection.length <= maxWordUTF16Length else {
            return []
        }

        let text = snapshot.text
        let utf16 = text.utf16
        let totalUTF16 = utf16.count
        guard selection.upperBound <= totalUTF16 else { return [] }

        // Resolve selection boundaries in String.Index space.
        guard let selStart = utf16.index(utf16.startIndex, offsetBy: selection.location, limitedBy: utf16.endIndex),
              let selEnd = utf16.index(selStart, offsetBy: selection.length, limitedBy: utf16.endIndex) else {
            return []
        }

        // Verify selection is bounded on both sides as a whole word.
        if selStart > text.startIndex {
            let prev = text.unicodeScalars.index(before: selStart)
            if isWordScalar(text.unicodeScalars[prev]) { return [] }
        }
        if selEnd < text.endIndex {
            if isWordScalar(text.unicodeScalars[selEnd]) { return [] }
        }

        let wordSlice = text[selStart..<selEnd]
        guard !wordSlice.isEmpty else { return [] }

        var isAllASCII = true
        for scalar in wordSlice.unicodeScalars {
            if !isWordScalar(scalar) { return [] }
            if !scalar.isASCII { isAllASCII = false }
        }

        if isAllASCII {
            if let fast = scanASCIIWordUTF8(
                word: wordSlice,
                in: text,
                excluding: selection,
                maxMatches: maxMatches
            ) {
                return fast
            }
        }

        return scanUnicodeWord(
            word: String(wordSlice),
            in: text,
            excluding: selection,
            maxMatches: maxMatches
        )
    }

    @inline(__always)
    private static func isASCIIWordByte(_ b: UInt8) -> Bool {
        (b >= 0x41 && b <= 0x5A)
            || (b >= 0x61 && b <= 0x7A)
            || (b >= 0x30 && b <= 0x39)
            || b == 0x5F
    }

    @inline(__always)
    private static func isWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.isASCII {
            return isASCIIWordByte(UInt8(scalar.value))
        }
        return scalar.properties.isAlphabetic || CharacterSet.decimalDigits.contains(scalar)
    }

    /// Decodes the Unicode scalar ending immediately before byte index `pos` in a valid UTF-8 buffer.
    private static func previousScalar(in base: UnsafePointer<UInt8>, before pos: Int) -> Unicode.Scalar? {
        var start = pos - 1
        while start > 0 && (base[start] & 0xC0) == 0x80 {
            start -= 1
        }
        return decodeUTF8Scalar(in: base, at: start, limit: pos)
    }

    /// Decodes the Unicode scalar starting at byte index `pos` in a valid UTF-8 buffer.
    private static func decodeUTF8Scalar(in base: UnsafePointer<UInt8>, at pos: Int, limit: Int) -> Unicode.Scalar? {
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
    private static func scanASCIIWordUTF8(
        word: Substring,
        in text: String,
        excluding selection: TextRange,
        maxMatches: Int
    ) -> [TextRange]? {
        text.utf8.withContiguousStorageIfAvailable { buf -> [TextRange]? in
            let n = buf.count
            guard let base = buf.baseAddress else { return [] }
            let wordStart = word.startIndex.utf8Offset(in: text)
            let m = word.utf8.count
            guard m > 0, m <= n, wordStart + m <= n else { return [] }
            let wBase = base.advanced(by: wordStart)

            let firstByte = wBase[0]
            let lastByte = wBase[m - 1]
            let limit = n - m
            var matches: [TextRange] = []
            matches.reserveCapacity(min(32, maxMatches))
            var i = 0
            var utf16Pos = 0

            while i <= limit {
                let b = base[i]
                if b == firstByte {
                    if m == 1 || base[i + m - 1] == lastByte {
                        let leftOK: Bool
                        if i == 0 {
                            leftOK = true
                        } else {
                            let prev = base[i - 1]
                            if prev < 0x80 {
                                leftOK = !isASCIIWordByte(prev)
                            } else if let scalar = previousScalar(in: base, before: i) {
                                leftOK = !isWordScalar(scalar)
                            } else {
                                leftOK = false
                            }
                        }
                        if leftOK {
                            let rightPos = i + m
                            let rightOK: Bool
                            if rightPos == n {
                                rightOK = true
                            } else {
                                let next = base[rightPos]
                                if next < 0x80 {
                                    rightOK = !isASCIIWordByte(next)
                                } else if let scalar = decodeUTF8Scalar(in: base, at: rightPos, limit: n) {
                                    rightOK = !isWordScalar(scalar)
                                } else {
                                    rightOK = false
                                }
                            }
                            if rightOK && (m <= 2 || memcmp(base.advanced(by: i + 1), wBase.advanced(by: 1), m - 2) == 0) {
                                let range = TextRange(location: utf16Pos, length: m)
                                if range != selection {
                                    matches.append(range)
                                    if matches.count >= maxMatches {
                                        return matches
                                    }
                                }
                                i += m
                                utf16Pos += m
                                continue
                            }
                        }
                    }
                    // Skip remaining ASCII word characters of this non-matching identifier in one tight loop.
                    i += 1
                    utf16Pos += 1
                    while i <= limit && isASCIIWordByte(base[i]) {
                        i += 1
                        utf16Pos += 1
                    }
                } else if b < 0x80 {
                    i += 1
                    utf16Pos += 1
                } else if b < 0xE0 {
                    i += 2
                    utf16Pos += 1
                } else if b < 0xF0 {
                    i += 3
                    utf16Pos += 1
                } else {
                    i += 4
                    utf16Pos += 2
                }
            }
            return matches
        } ?? nil
    }

    /// Unicode-aware whole-word literal fallback for accented / non-ASCII identifiers.
    private static func scanUnicodeWord(
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

        while searchRange.length > 0 {
            let found = nsText.range(of: word, options: [.literal], range: searchRange)
            guard found.location != NSNotFound && found.length > 0 else { break }
            let candidate = TextRange(location: found.location, length: found.length)
            if candidate != selection,
               let startIdx = utf16.index(utf16.startIndex, offsetBy: candidate.location, limitedBy: utf16.endIndex),
               let endIdx = utf16.index(startIdx, offsetBy: candidate.length, limitedBy: utf16.endIndex) {
                let leftOK: Bool
                if startIdx > text.startIndex {
                    let prev = text.unicodeScalars.index(before: startIdx)
                    leftOK = !isWordScalar(text.unicodeScalars[prev])
                } else {
                    leftOK = true
                }
                let rightOK = endIdx == text.endIndex || !isWordScalar(text.unicodeScalars[endIdx])
                if leftOK && rightOK {
                    matches.append(candidate)
                    if matches.count >= maxMatches { break }
                }
            }
            let nextStart = found.location + found.length
            guard nextStart <= totalLength else { break }
            searchRange = NSRange(location: nextStart, length: totalLength - nextStart)
        }
        return matches
    }
}

private extension String.Index {
    @inline(__always)
    func utf8Offset(in string: String) -> Int {
        string.utf8.distance(from: string.utf8.startIndex, to: self)
    }
}
