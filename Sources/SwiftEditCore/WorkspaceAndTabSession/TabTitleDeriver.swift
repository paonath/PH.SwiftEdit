import Foundation

/// Derives dynamic, bounded display titles for unsaved (`fileURL == nil`) tabs from the first `N` words of document text (`BC-008`, `PERF-001`).
public enum TabTitleDeriver {
    public static let fallbackTitle = "Untitled"
    public static let defaultMaxWords = 4
    public static let defaultMaxCharacters = 36
    private static let maxScanScalars = 512

    /// Returns a human-readable tab title composed of the first `maxWords` space-separated words from `text`,
    /// stripping leading Markdown heading, list, task, and blockquote markers, or `"Untitled"` when no words exist.
    ///
    /// Scanning stops immediately once `maxWords` words are collected or `512` Unicode scalars have been inspected so
    /// per-keystroke updates stay `O(1)` regardless of document size.
    public static func untitledTitle(
        from text: String,
        maxWords: Int = defaultMaxWords,
        maxCharacters: Int = defaultMaxCharacters
    ) -> String {
        let wordLimit = max(1, maxWords)
        let charLimit = max(4, maxCharacters)

        var collected: [String] = []
        collected.reserveCapacity(wordLimit)

        // Work strictly on a small prefix so huge pastes remain O(1).
        let boundedPrefix: Substring
        if let cutIndex = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: maxScanScalars, limitedBy: text.unicodeScalars.endIndex) {
            boundedPrefix = text[..<cutIndex]
        } else {
            boundedPrefix = text[...]
        }

        let lines = boundedPrefix.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        for rawLine in lines {
            if collected.count >= wordLimit { break }
            let stripped = stripLeadingMarkdownMarkers(rawLine)
            if stripped.isEmpty { continue }

            for token in stripped.split(whereSeparator: \.isWhitespace) {
                let cleaned = cleanToken(token)
                guard !cleaned.isEmpty else { continue }
                collected.append(cleaned)
                if collected.count >= wordLimit { break }
            }
        }

        guard !collected.isEmpty else { return fallbackTitle }
        let joined = collected.joined(separator: " ")
        guard joined.count > charLimit else { return joined }

        let cutoff = joined.index(joined.startIndex, offsetBy: charLimit - 1)
        let truncated = String(joined[..<cutoff]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (truncated.isEmpty ? String(joined.prefix(charLimit - 1)) : truncated) + "…"
    }

    private static func stripLeadingMarkdownMarkers(_ rawLine: Substring) -> Substring {
        var slice = dropLeadingWhitespace(rawLine)

        // Repeatedly peel blockquote (`>`) or heading (`#`) prefixes.
        while let first = slice.first {
            if first == "#" {
                while slice.first == "#" { slice = slice.dropFirst() }
                slice = dropLeadingWhitespace(slice)
            } else if first == ">" {
                slice = dropLeadingWhitespace(slice.dropFirst())
            } else {
                break
            }
        }

        // Peel unordered bullet marker (`- `, `* `, `+ `) or horizontal/code fence lines (`---`, `***`, `___`, ```` ``` ````).
        if let first = slice.first, first == "-" || first == "*" || first == "+" || first == "_" || first == "`" {
            let afterMarker = slice.dropFirst()
            if afterMarker.first?.isWhitespace == true || afterMarker.isEmpty {
                slice = dropLeadingWhitespace(afterMarker)
            } else if first == "`" && slice.hasPrefix("```") {
                return Substring()
            } else if (first == "-" || first == "*" || first == "_"),
                      slice.allSatisfy({ $0 == first || $0.isWhitespace }) {
                return Substring()
            }
        }

        // Peel ordered list prefix (`1. `, `12) `).
        if slice.first?.isNumber == true {
            var cursor = slice.startIndex
            while cursor < slice.endIndex && slice[cursor].isNumber {
                cursor = slice.index(after: cursor)
            }
            if cursor < slice.endIndex && (slice[cursor] == "." || slice[cursor] == ")") {
                let next = slice.index(after: cursor)
                if next == slice.endIndex || slice[next].isWhitespace {
                    slice = dropLeadingWhitespace(slice[next...])
                }
            }
        }

        // Peel GFM task checkbox (`[ ] `, `[x] `, `[X] `).
        if slice.hasPrefix("[ ]") || slice.hasPrefix("[x]") || slice.hasPrefix("[X]") {
            let afterBox = slice.dropFirst(3)
            if afterBox.isEmpty || afterBox.first?.isWhitespace == true {
                slice = dropLeadingWhitespace(afterBox)
            }
        }

        return slice
    }

    private static func cleanToken(_ token: Substring) -> String {
        var s = token
        let trimChars: Set<Character> = ["`", "*", "_"]
        while let first = s.first, trimChars.contains(first) {
            s = s.dropFirst()
        }
        while let last = s.last, trimChars.contains(last) {
            s = s.dropLast()
        }
        if s.allSatisfy({ $0 == "#" || $0 == "-" || $0 == "*" || $0 == "=" || $0 == "_" }) {
            return ""
        }
        return String(s)
    }

    private static func dropLeadingWhitespace(_ s: Substring) -> Substring {
        var cursor = s.startIndex
        while cursor < s.endIndex && s[cursor].isWhitespace {
            cursor = s.index(after: cursor)
        }
        return s[cursor...]
    }
}
