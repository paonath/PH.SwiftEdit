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

        let boundedPrefix = tabTitleBoundedPrefix(of: text)
        let collected = tabTitleCollectWords(from: boundedPrefix, wordLimit: wordLimit)

        guard !collected.isEmpty else { return fallbackTitle }
        let joined = collected.joined(separator: " ")
        guard joined.count > charLimit else { return joined }

        let cutoff = joined.index(joined.startIndex, offsetBy: charLimit - 1)
        let truncated = String(joined[..<cutoff]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (truncated.isEmpty ? String(joined.prefix(charLimit - 1)) : truncated) + "…"
    }
}

private extension TabTitleDeriver {
    static let bulletOrFenceMarkers: Set<Character> = ["-", "*", "+", "_", "`"]
    static let thematicBreakMarkers: Set<Character> = ["-", "*", "_"]
    static let inlineTrimCharacters: Set<Character> = ["`", "*", "_"]
    static let ruleOnlyTokenCharacters: Set<Character> = ["#", "-", "*", "=", "_"]

    static func tabTitleBoundedPrefix(of text: String) -> Substring {
        if let cutIndex = text.unicodeScalars.index(
            text.unicodeScalars.startIndex,
            offsetBy: maxScanScalars,
            limitedBy: text.unicodeScalars.endIndex
        ) {
            return text[..<cutIndex]
        }
        return text[...]
    }

    static func tabTitleCollectWords(from prefix: Substring, wordLimit: Int) -> [String] {
        var collected: [String] = []
        collected.reserveCapacity(wordLimit)
        for rawLine in prefix.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            if collected.count >= wordLimit { break }
            tabTitleAppendLineWords(from: rawLine, wordLimit: wordLimit, into: &collected)
        }
        return collected
    }

    static func tabTitleAppendLineWords(
        from rawLine: Substring,
        wordLimit: Int,
        into collected: inout [String]
    ) {
        let stripped = stripLeadingMarkdownMarkers(rawLine)
        guard !stripped.isEmpty else { return }
        for token in stripped.split(whereSeparator: \.isWhitespace) {
            let cleaned = cleanToken(token)
            if !cleaned.isEmpty {
                collected.append(cleaned)
                if collected.count >= wordLimit { return }
            }
        }
    }

    static func stripLeadingMarkdownMarkers(_ rawLine: Substring) -> Substring {
        let afterBlocks = tabTitlePeelHeadingsAndBlockquotes(dropLeadingWhitespace(rawLine))
        guard let afterBullets = tabTitlePeelBulletOrRuleLine(afterBlocks) else {
            return Substring()
        }
        let afterOrdered = tabTitlePeelOrderedListPrefix(afterBullets)
        return tabTitlePeelTaskCheckbox(afterOrdered)
    }

    static func tabTitlePeelHeadingsAndBlockquotes(_ initial: Substring) -> Substring {
        var slice = initial
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
        return slice
    }

    static func tabTitlePeelBulletOrRuleLine(_ slice: Substring) -> Substring? {
        guard let first = slice.first, bulletOrFenceMarkers.contains(first) else {
            return slice
        }
        let afterMarker = slice.dropFirst()
        if afterMarker.isEmpty || afterMarker.first?.isWhitespace == true {
            return dropLeadingWhitespace(afterMarker)
        }
        if first == "`" && slice.hasPrefix("```") {
            return nil
        }
        if thematicBreakMarkers.contains(first) && tabTitleIsThematicBreak(slice, marker: first) {
            return nil
        }
        return slice
    }

    static func tabTitleIsThematicBreak(_ slice: Substring, marker: Character) -> Bool {
        slice.allSatisfy { $0 == marker || $0.isWhitespace }
    }

    static func tabTitlePeelOrderedListPrefix(_ slice: Substring) -> Substring {
        guard slice.first?.isNumber == true else { return slice }
        var cursor = slice.startIndex
        while cursor < slice.endIndex && slice[cursor].isNumber {
            cursor = slice.index(after: cursor)
        }
        guard cursor < slice.endIndex, slice[cursor] == "." || slice[cursor] == ")" else {
            return slice
        }
        let next = slice.index(after: cursor)
        guard next == slice.endIndex || slice[next].isWhitespace else {
            return slice
        }
        return dropLeadingWhitespace(slice[next...])
    }

    static func tabTitlePeelTaskCheckbox(_ slice: Substring) -> Substring {
        guard tabTitleHasTaskCheckboxPrefix(slice) else { return slice }
        let afterBox = slice.dropFirst(3)
        guard afterBox.isEmpty || afterBox.first?.isWhitespace == true else { return slice }
        return dropLeadingWhitespace(afterBox)
    }

    static func tabTitleHasTaskCheckboxPrefix(_ slice: Substring) -> Bool {
        slice.hasPrefix("[ ]") || slice.hasPrefix("[x]") || slice.hasPrefix("[X]")
    }

    static func cleanToken(_ token: Substring) -> String {
        var s = token
        while let first = s.first, inlineTrimCharacters.contains(first) {
            s = s.dropFirst()
        }
        while let last = s.last, inlineTrimCharacters.contains(last) {
            s = s.dropLast()
        }
        if s.allSatisfy({ ruleOnlyTokenCharacters.contains($0) }) {
            return ""
        }
        return String(s)
    }

    static func dropLeadingWhitespace(_ s: Substring) -> Substring {
        var cursor = s.startIndex
        while cursor < s.endIndex && s[cursor].isWhitespace {
            cursor = s.index(after: cursor)
        }
        return s[cursor...]
    }
}
