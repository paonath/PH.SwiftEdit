import Foundation

/// Single-pass line scanner implementing the `.allConstructs` rule catalog on a shared `MarkdownLineIndex` (`BC-004`, `SEC-004`, `SEC-012`).
///
/// Frontmatter lines are skipped, fenced interiors only receive fence rules, lines over `4096` UTF-16 units are opaque, and every fixable finding carries a minimal `TextEdit`. Security rules (`.unsafeLinkScheme`, `.unsafeImagePath`, `.emptyLinkTarget`) never carry a fix.
enum MarkdownAllConstructsLinter {
    static let allowedSchemes = MarkdownLintAndFormatEngine.allowedLinkSchemes

    static func diagnostics(index: MarkdownLineIndex, deadlineExceeded: () -> Bool) -> (diagnostics: [MarkdownLintDiagnostic], maskedLines: Int)? {
        runConstructLintPasses(index: index, securityOnly: false, deadlineExceeded: deadlineExceeded)
    }

    /// Bounded linear scanner retaining only security URI/image rules (`.unsafeLinkScheme`, `.unsafeImagePath`, `.emptyLinkTarget`) for large non-degraded documents (`PERF-006`, `N11`).
    static func securityOnlyDiagnostics(index: MarkdownLineIndex, deadlineExceeded: () -> Bool) -> (diagnostics: [MarkdownLintDiagnostic], maskedLines: Int)? {
        runConstructLintPasses(index: index, securityOnly: true, deadlineExceeded: deadlineExceeded)
    }

    /// Zero-index single-pass UTF-8 byte streamer for `securityOnly` URI scanning (`< 5 ms` on `~1 MB` Debug buffers without allocating `MarkdownLineIndex`) (`PERF-006`, `N11`, `SEC-004`).
    static func securityOnlyDiagnostics(text: String, deadlineExceeded: () -> Bool) -> [MarkdownLintDiagnostic]? {
        var mutableText = text
        return mutableText.withUTF8 { buffer in
            scanSecurityUTF8(buffer, deadlineExceeded: deadlineExceeded)
        }
    }

    private static func scanSecurityUTF8(
        _ buffer: UnsafeBufferPointer<UInt8>,
        deadlineExceeded: () -> Bool
    ) -> [MarkdownLintDiagnostic]? {
        guard !buffer.isEmpty else { return [] }
        let maxLine = MarkdownLineIndex.maxLineUTF16
        let maskedLines = detectYAMLFrontmatterMaskedLinesUTF8(buffer)

        var out: [MarkdownLintDiagnostic] = []
        var openFence: (char: UInt8, count: Int)?
        var scratch = InlineScanScratch()
        var lineIndex = 0
        var pos = 0
        var utf16Cursor = 0

        while pos < buffer.count {
            if lineIndex % 256 == 0, deadlineExceeded() { return nil }
            let lineStartUTF16 = utf16Cursor
            let scanned = readNextUTF8SecurityLine(in: buffer, from: pos, utf16Start: utf16Cursor)
            pos = scanned.nextPos
            utf16Cursor = scanned.nextUTF16

            if lineIndex >= maskedLines {
                inspectUTF8SecurityLine(
                    scanned,
                    lineIndex: lineIndex,
                    lineStartUTF16: lineStartUTF16,
                    maxLine: maxLine,
                    openFence: &openFence,
                    scratch: &scratch,
                    into: &out
                )
            }
            lineIndex += 1
        }
        return out
    }

    private static func utf8LineBounds(
        in buffer: UnsafeBufferPointer<UInt8>,
        from start: Int
    ) -> (slice: UnsafeBufferPointer<UInt8>, nextStart: Int)? {
        guard start < buffer.count else { return nil }
        var end = start
        while end < buffer.count && buffer[end] != 0x0A { end += 1 }
        let next = end < buffer.count ? end + 1 : end
        return (UnsafeBufferPointer(rebasing: buffer[start..<end]), next)
    }

    private static func isYAMLDelimiterUTF8(_ slice: UnsafeBufferPointer<UInt8>, opening: Bool) -> Bool {
        var end = slice.count
        while end > 0 && (slice[end - 1] == 0x20 || slice[end - 1] == 0x0D) { end -= 1 }
        guard end == 3 else { return false }
        if slice[0] == 0x2D && slice[1] == 0x2D && slice[2] == 0x2D { return true }
        return !opening && slice[0] == 0x2E && slice[1] == 0x2E && slice[2] == 0x2E
    }

    private static func detectYAMLFrontmatterMaskedLinesUTF8(_ buffer: UnsafeBufferPointer<UInt8>) -> Int {
        guard let first = utf8LineBounds(in: buffer, from: 0),
              first.nextStart < buffer.count,
              isYAMLDelimiterUTF8(first.slice, opening: true) else {
            return 0
        }
        var cursor = first.nextStart
        var line = 1
        while line <= YAMLFrontmatterScanner.maxLines, let nextLine = utf8LineBounds(in: buffer, from: cursor) {
            if isYAMLDelimiterUTF8(nextLine.slice, opening: false) {
                return line + 1
            }
            if nextLine.nextStart == cursor { break }
            cursor = nextLine.nextStart
            line += 1
        }
        return 0
    }

    private static func fenceOpeningUTF8(_ slice: UnsafeBufferPointer<UInt8>) -> (char: UInt8, count: Int)? {
        var idx = 0
        var spaces = 0
        while idx < slice.count && slice[idx] == 0x20 && spaces < 4 { idx += 1; spaces += 1 }
        guard spaces < 4, idx < slice.count, slice[idx] == 0x60 || slice[idx] == 0x7E else { return nil }
        let ch = slice[idx]
        var count = 0
        while idx < slice.count && slice[idx] == ch { idx += 1; count += 1 }
        guard count >= 3 else { return nil }
        if ch == 0x60 {
            var scan = idx
            while scan < slice.count {
                if slice[scan] == 0x60 { return nil }
                scan += 1
            }
        }
        return (ch, count)
    }

    private static func isClosingFenceUTF8(_ slice: UnsafeBufferPointer<UInt8>, char: UInt8, minCount: Int) -> Bool {
        var idx = 0
        var spaces = 0
        while idx < slice.count && slice[idx] == 0x20 && spaces < 4 { idx += 1; spaces += 1 }
        guard spaces < 4 else { return false }
        var count = 0
        while idx < slice.count && slice[idx] == char { idx += 1; count += 1 }
        guard count >= minCount else { return false }
        while idx < slice.count {
            if slice[idx] != 0x20 { return false }
            idx += 1
        }
        return true
    }

    /// Orchestrates Markdown linting by dispatching each line to modular rule-family passes
    /// in `MarkdownLinterRuleFamilyPasses` while enforcing fail-closed deadline checks every 256 lines.
    private static func runConstructLintPasses(index: MarkdownLineIndex, securityOnly: Bool, deadlineExceeded: () -> Bool) -> (diagnostics: [MarkdownLintDiagnostic], maskedLines: Int)? {
        let masked = YAMLFrontmatterScanner.maskedLineCount(in: index)
        var context = MarkdownLinterPassContext(index: index, masked: masked, securityOnly: securityOnly)
        let count = index.lineCount
        let maxLine = MarkdownLineIndex.maxLineUTF16
        var line = masked

        while line < count {
            if (line == masked || line % 256 == 0), deadlineExceeded() { return nil }
            let range = index.lineRange(line)
            let slice = index.lineSlice(line)
            if securityOnly {
                line = evaluateSecurityOnlyLine(at: line, range: range, slice: slice, maxLine: maxLine, context: &context)
                continue
            }
            line = evaluateFullRuleLine(at: line, range: range, slice: slice, maxLine: maxLine, context: &context)
        }
        return (context.out, masked)
    }

    /// Evaluates a single line during `securityOnly` passes, skipping fenced code blocks in O(1) amortized time.
    private static func evaluateSecurityOnlyLine(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        maxLine: Int,
        context: inout MarkdownLinterPassContext
    ) -> Int {
        if let fence = context.currentFence(at: line) {
            return fence.close + 1
        }
        if range.length <= maxLine, hasSecurityRelevantInlineUnits(slice) {
            scanInline(slice, base: range.location, line: line, securityOnly: true, scratch: &context.scratch, into: &context.out)
        }
        return line + 1
    }

    /// Dispatches a single non-masked line through fence, whitespace, table, heading, blockquote, list, and paragraph passes.
    private static func evaluateFullRuleLine(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        maxLine: Int,
        context: inout MarkdownLinterPassContext
    ) -> Int {
        if let fence = context.currentFence(at: line) {
            return MarkdownLinterRuleFamilyPasses.evaluateFenceBlock(at: line, range: range, slice: slice, fence: fence, context: &context)
        }
        guard range.length <= maxLine else {
            context.prevBlank = false
            return line + 1
        }
        let isBlankLine = context.isBlank(line)
        if MarkdownLinterRuleFamilyPasses.evaluateWhitespaceAndBlankLine(at: line, range: range, slice: slice, isBlankLine: isBlankLine, context: &context) {
            return line + 1
        }
        let wasBlank = context.prevBlank
        context.prevBlank = false
        let lead = leadingIndentAndUnit(in: slice)
        if let nextLine = MarkdownLinterRuleFamilyPasses.evaluateTableBlock(at: line, range: range, slice: slice, first: lead.first, indent: lead.indent, context: &context) {
            return nextLine
        }
        evaluateSingleLineConstruct(at: line, range: range, slice: slice, lead: lead, wasBlank: wasBlank, context: &context)
        return line + 1
    }

    private static func leadingIndentAndUnit(
        in slice: ArraySlice<UInt16>
    ) -> (idx: ArraySlice<UInt16>.Index, indent: Int, first: UInt16) {
        var idx = slice.startIndex
        while idx < slice.endIndex, slice[idx] == 0x20 { idx += 1 }
        let indent = idx - slice.startIndex
        let first = idx < slice.endIndex ? slice[idx] : 0
        return (idx, indent, first)
    }

    private static func evaluateSingleLineConstruct(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        lead: (idx: ArraySlice<UInt16>.Index, indent: Int, first: UInt16),
        wasBlank: Bool,
        context: inout MarkdownLinterPassContext
    ) {
        let handled =
            MarkdownLinterRuleFamilyPasses.evaluateHeadingLine(at: line, range: range, slice: slice, first: lead.first, indent: lead.indent, idx: lead.idx, context: &context)
            || MarkdownLinterRuleFamilyPasses.evaluateBlockquoteLine(at: line, range: range, slice: slice, first: lead.first, indent: lead.indent, idx: lead.idx, context: &context)
            || MarkdownLinterRuleFamilyPasses.evaluateListItemLine(at: line, range: range, slice: slice, wasBlank: wasBlank, context: &context)
        if !handled {
            MarkdownLinterRuleFamilyPasses.evaluateParagraphLine(at: line, range: range, slice: slice, indent: lead.indent, wasBlank: wasBlank, context: &context)
        }
    }
}

extension MarkdownAllConstructsLinter {
    private struct UTF8ScannedSecurityLine {
        let slice: UnsafeBufferPointer<UInt8>
        let nextPos: Int
        let nextUTF16: Int
        let utf16Length: Int
        let isASCII: Bool
        let hasInlineTrigger: Bool
    }

    private static func readNextUTF8SecurityLine(
        in buffer: UnsafeBufferPointer<UInt8>,
        from startPos: Int,
        utf16Start: Int
    ) -> UTF8ScannedSecurityLine {
        var pos = startPos
        var utf16Cursor = utf16Start
        var sawBracket = false
        var sawParen = false
        var sawBiDiLeadByte = false
        var isASCII = true

        while pos < buffer.count {
            let b = buffer[pos]
            if b == 0x0A { break }
            if b < 0x80 {
                if b == 0x5B { sawBracket = true }
                else if b == 0x28 { sawParen = true }
                utf16Cursor += 1
            } else {
                isASCII = false
                if b == 0xE2 || b == 0xD8 { sawBiDiLeadByte = true }
                utf16Cursor += utf8LeadByteUTF16Advance(b)
            }
            pos += 1
        }

        let lineSlice = UnsafeBufferPointer(rebasing: buffer[startPos..<pos])
        let lineUTF16Len = utf16Cursor - utf16Start
        if pos < buffer.count && buffer[pos] == 0x0A {
            pos += 1
            utf16Cursor += 1
        }
        return UTF8ScannedSecurityLine(
            slice: lineSlice,
            nextPos: pos,
            nextUTF16: utf16Cursor,
            utf16Length: lineUTF16Len,
            isASCII: isASCII,
            hasInlineTrigger: (sawBracket && sawParen) || sawBiDiLeadByte
        )
    }

    @inline(__always)
    private static func utf8LeadByteUTF16Advance(_ byte: UInt8) -> Int {
        if byte >= 0xF0 { return 2 }
        if byte >= 0xC0 { return 1 }
        return 0
    }

    private static func inspectUTF8SecurityLine(
        _ scanned: UTF8ScannedSecurityLine,
        lineIndex: Int,
        lineStartUTF16: Int,
        maxLine: Int,
        openFence: inout (char: UInt8, count: Int)?,
        scratch: inout InlineScanScratch,
        into out: inout [MarkdownLintDiagnostic]
    ) {
        if let fence = openFence {
            if isClosingFenceUTF8(scanned.slice, char: fence.char, minCount: fence.count) {
                openFence = nil
            }
            return
        }
        if let opened = fenceOpeningUTF8(scanned.slice) {
            openFence = opened
            return
        }
        guard scanned.hasInlineTrigger, scanned.utf16Length <= maxLine else { return }
        populateUTF16LineScratch(from: scanned.slice, isASCII: scanned.isASCII, into: &scratch.utf16Line)
        scanInline(scratch.utf16Line[...], base: lineStartUTF16, line: lineIndex, securityOnly: true, scratch: &scratch, into: &out)
    }

    private static func populateUTF16LineScratch(
        from slice: UnsafeBufferPointer<UInt8>,
        isASCII: Bool,
        into utf16Line: inout [UInt16]
    ) {
        utf16Line.removeAll(keepingCapacity: true)
        if isASCII {
            utf16Line.reserveCapacity(slice.count)
            for b in slice {
                utf16Line.append(UInt16(b))
            }
        } else {
            let decoded = String(decoding: slice, as: UTF8.self)
            utf16Line.append(contentsOf: decoded.utf16)
        }
    }
}
