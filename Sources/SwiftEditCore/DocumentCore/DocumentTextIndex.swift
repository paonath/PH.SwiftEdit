import Foundation

/// Per-revision line-break table answering gutter and cursor queries in `O(log L)` instead of rescanning the buffer on
/// every caret move (`PERF-B2`, `UI-012`).
///
/// Built in one pass over native UTF-8 (UTF-16 offsets derived arithmetically). Each entry of `breakStarts` is the UTF-16
/// offset of a line break; a CRLF pair is one break whose start is the `\r`. Both historical caret semantics are
/// reproduced exactly, including their differing treatment of a caret placed between `\r` and `\n`.
public struct DocumentTextIndex: Sendable, Equatable {
    /// Sorted UTF-16 offsets of every line break start.
    public let breakStarts: [Int]
    /// `true` at `i` when `breakStarts[i]` begins a CRLF pair.
    public let isCRLF: [Bool]
    public let utf16Count: Int
    public let unicodeScalarCount: Int

    public init(text: String) {
        var starts: [Int] = []
        var crlf: [Bool] = []
        var hasCRLF = false
        var utf16 = 0
        var scalars = 0
        var native = text
        native.withUTF8 { buf in
            let count = buf.count
            starts.reserveCapacity(count / 40 + 1)
            guard let base = buf.baseAddress else { return }
            var i = 0
            while i < count {
                let b = base[i]
                if b == 0x0A {
                    starts.append(utf16)
                    if hasCRLF { crlf.append(false) }
                    utf16 += 1; scalars += 1; i += 1
                } else if b == 0x0D {
                    let pair = i + 1 < count && base[i + 1] == 0x0A
                    if pair && !hasCRLF {
                        hasCRLF = true
                        crlf.reserveCapacity(count / 40 + 1)
                        if !starts.isEmpty {
                            crlf.append(contentsOf: repeatElement(false, count: starts.count))
                        }
                    }
                    starts.append(utf16)
                    if hasCRLF { crlf.append(pair) }
                    let step = pair ? 2 : 1
                    utf16 += step; scalars += step; i += step
                } else if b < 0x80 {
                    utf16 += 1; scalars += 1; i += 1
                } else if b < 0xE0 {
                    utf16 += 1; scalars += 1; i += 2
                } else if b < 0xF0 {
                    utf16 += 1; scalars += 1; i += 3
                } else {
                    utf16 += 2; scalars += 1; i += 4
                }
            }
        }
        breakStarts = starts
        isCRLF = crlf
        utf16Count = utf16
        unicodeScalarCount = scalars
    }

    /// Total 1-based line count.
    public var lineCount: Int { breakStarts.count + 1 }

    /// Number of breaks starting strictly before `offset` (binary search).
    func breaksBefore(_ offset: Int) -> Int {
        var lo = 0, hi = breakStarts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if breakStarts[mid] < offset { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Gutter active line: a CRLF counts only once the caret is past its `\n` (matches `LineNumberGutterProjection.evaluate(text:)`).
    public func gutterActiveLine(caret: Int) -> Int {
        let c = min(max(0, caret), utf16Count)
        var k = breaksBefore(c)
        if k > 0, !isCRLF.isEmpty, isCRLF[k - 1], breakStarts[k - 1] + 1 >= c { k -= 1 }
        return k + 1
    }

    /// Cursor line and 1-based UTF-16 column (matches `CursorMetricsCalculator.metrics`); `nil` when `caret` is out of bounds.
    public func cursorLineAndColumn(caret: Int) -> (line: Int, column: Int)? {
        guard caret >= 0, caret <= utf16Count else { return nil }
        let k = breaksBefore(caret)
        guard k > 0 else { return (1, caret + 1) }
        let b = breakStarts[k - 1]
        let lineStart = (!isCRLF.isEmpty && isCRLF[k - 1] && b + 1 < caret) ? b + 2 : b + 1
        return (k + 1, caret - lineStart + 1)
    }

    /// Returns the UTF-16 content range (excluding trailing line break) of the line containing `caret` in `O(log L)` without `NSString` bridging.
    public func lineContentRange(atUTF16Offset caret: Int) -> TextRange {
        let clamped = min(max(0, caret), utf16Count)
        let k = breaksBefore(clamped)
        let lineStart: Int
        if k == 0 {
            lineStart = 0
        } else {
            let prevBreak = breakStarts[k - 1]
            let prevStep = (!isCRLF.isEmpty && isCRLF[k - 1]) ? 2 : 1
            if prevStep == 2 && clamped == prevBreak + 1 {
                // Caret between \r and \n belongs to the preceding line (matches NSString.lineRange semantics).
                if k == 1 {
                    lineStart = 0
                } else {
                    let prevPrev = breakStarts[k - 2]
                    let prevPrevStep = (!isCRLF.isEmpty && isCRLF[k - 2]) ? 2 : 1
                    lineStart = prevPrev + prevPrevStep
                }
                return TextRange(location: lineStart, length: max(0, prevBreak - lineStart))
            }
            lineStart = prevBreak + prevStep
        }
        let lineEnd = (k < breakStarts.count) ? breakStarts[k] : utf16Count
        return TextRange(location: lineStart, length: max(0, lineEnd - lineStart))
    }
}

/// Single-entry cache keyed strictly by `(DocumentID, BufferRevision)`: a same-length edit always produces a new
/// revision and therefore a new index, so no consumer can observe a stale break table (`N12`).
@MainActor
public final class DocumentTextIndexCache {
    private var entry: (id: DocumentID, revision: BufferRevision, index: DocumentTextIndex)?

    public init() {}

    public func index(for snapshot: DocumentSnapshot) -> DocumentTextIndex {
        if let entry, entry.id == snapshot.id, entry.revision == snapshot.revision { return entry.index }
        let index = DocumentTextIndex(text: snapshot.text)
        entry = (snapshot.id, snapshot.revision, index)
        return index
    }
}
