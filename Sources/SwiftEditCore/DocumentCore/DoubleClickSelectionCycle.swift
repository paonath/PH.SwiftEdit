import Foundation

/// Repeated double-click selection cycle (`REQ-022-05`): word -> whitespace-free token -> no selection.
///
/// The token is the run of non-whitespace characters around the word, with wrapping quotes/brackets trimmed from its
/// start and closing quotes/brackets plus trailing punctuation trimmed from its end, so `(contextual-menu).` yields
/// `contextual-menu`. Pure and UTF-16 based so it can be unit-tested without AppKit.
public enum DoubleClickSelectionCycle {
    /// Characters trimmed from the token start.
    static let leadingTrim: Set<unichar> = Set("([{<\"'`“‘«".utf16)
    /// Characters trimmed from the token end.
    static let trailingTrim: Set<unichar> = Set(")]}>\"'`”’».,;:!?".utf16)
    /// Longest token considered (guards pathological single-line blobs, `CWE-400`).
    public static let maxTokenUTF16Length = 4_096

    public enum Outcome: Equatable, Sendable {
        /// Let the system select the word under the pointer.
        case selectWord
        /// Select the whole token.
        case selectToken(TextRange)
        /// Clear the selection, leaving the caret at `caret`.
        case deselect(caret: Int)
    }

    /// Decides what a double-click does given the selection that existed before it.
    /// - Parameters:
    ///   - previous: selection before the double-click started.
    ///   - word: word range the system would select under the pointer.
    ///   - token: `token(around: word, in:)` for that word.
    public static func outcome(previous: TextRange, word: TextRange, token: TextRange) -> Outcome {
        guard word.length > 0 else { return .selectWord }
        if previous == token {
            return .deselect(caret: word.location)
        }
        if previous == word {
            return token == word ? .deselect(caret: word.location) : .selectToken(token)
        }
        return .selectWord
    }

    /// Whitespace-free token containing `word`, trimmed of wrapping brackets/quotes and trailing punctuation.
    public static func token(around word: TextRange, in text: NSString) -> TextRange {
        let length = text.length
        guard word.location >= 0, word.length > 0, word.upperBound <= length else { return word }
        var start = word.location
        var end = word.upperBound
        while start > 0, isWhitespace(text.character(at: start - 1)) == false, word.upperBound - (start - 1) <= maxTokenUTF16Length {
            start -= 1
        }
        while end < length, isWhitespace(text.character(at: end)) == false, (end + 1) - start <= maxTokenUTF16Length {
            end += 1
        }
        while start < word.location, isLeadingTrim(text.character(at: start)) {
            start += 1
        }
        while end > word.upperBound, isTrailingTrim(text.character(at: end - 1)) {
            end -= 1
        }
        return TextRange(location: start, length: end - start)
    }

    @inline(__always)
    private static func isLeadingTrim(_ unit: unichar) -> Bool {
        switch unit {
        case 0x28, 0x5B, 0x7B, 0x3C, 0x22, 0x27, 0x60, 0x201C, 0x2018, 0x00AB:
            return true // ( [ { < " ' ` “ ‘ «
        default:
            return false
        }
    }

    @inline(__always)
    private static func isTrailingTrim(_ unit: unichar) -> Bool {
        switch unit {
        case 0x29, 0x5D, 0x7D, 0x3E, 0x22, 0x27, 0x60, 0x201D, 0x2019, 0x00BB,
             0x2E, 0x2C, 0x3B, 0x3A, 0x21, 0x3F:
            return true // ) ] } > " ' ` ” ’ » . , ; : ! ?
        default:
            return false
        }
    }

    @inline(__always)
    private static func isWhitespace(_ unit: unichar) -> Bool {
        if unit < 0x80 {
            return unit == 0x20 || (unit >= 0x09 && unit <= 0x0D)
        }
        guard let scalar = Unicode.Scalar(unit) else { return false }
        return scalar.properties.isWhitespace
    }
}
