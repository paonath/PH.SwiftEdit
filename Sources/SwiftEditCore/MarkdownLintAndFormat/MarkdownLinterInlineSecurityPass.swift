import Foundation

/// Linear-time O(L) inline link and image security pass extracted from `MarkdownAllConstructsLinter` (`BC-001`, `SEC-012`).
extension MarkdownAllConstructsLinter {
    // MARK: Inline links and images (hardened, strictly O(L))

    /// Reusable per-lint pass buffers to avoid thousands of per-line `[Int]` / `[UInt16]` heap allocations.
    struct InlineScanScratch {
        var matchBracket: [Int] = []
        var matchParen: [Int] = []
        var bracketStack: [Int] = []
        var parenStack: [Int] = []
        var utf16Line: [UInt16] = []
    }

    static func hasSecurityRelevantInlineUnits(_ slice: ArraySlice<UInt16>) -> Bool {
        let triggers = prescanInlineTriggers(slice)
        return triggers.hasLinkDelimiters || triggers.hasTrojanBiDi
    }

    static func scanInline(
        _ slice: ArraySlice<UInt16>,
        base: Int,
        line: Int,
        securityOnly: Bool = false,
        scratch: inout InlineScanScratch,
        into out: inout [MarkdownLintDiagnostic]
    ) {
        guard !slice.isEmpty else { return }
        let triggers = prescanInlineTriggers(slice)
        guard triggers.hasLinkDelimiters || triggers.hasTrojanBiDi else { return }

        if !triggers.hasLinkDelimiters {
            emitStandaloneBiDiDiagnostics(slice, base: base, line: line, into: &out)
            return
        }

        prepareInlineDelimiterMatches(slice, scratch: &scratch)
        scanInlineWithBalancedLinks(slice, base: base, line: line, securityOnly: securityOnly, scratch: scratch, into: &out)
    }

    private static func prescanInlineTriggers(_ slice: ArraySlice<UInt16>) -> (hasLinkDelimiters: Bool, hasTrojanBiDi: Bool) {
        var hasBracket = false
        var hasParen = false
        var hasTrojanBiDi = false
        for u in slice {
            if u == 0x5B { hasBracket = true }
            else if u == 0x28 { hasParen = true }
            else if u >= 0x061C, isTrojanBiDiUnit(u) { hasTrojanBiDi = true }
        }
        let hasLinkDelimiters = slice.count >= 4 && hasBracket && hasParen
        return (hasLinkDelimiters, hasTrojanBiDi)
    }

    private static func emitStandaloneBiDiDiagnostics(
        _ slice: ArraySlice<UInt16>,
        base: Int,
        line: Int,
        into out: inout [MarkdownLintDiagnostic]
    ) {
        let start = slice.startIndex
        var i = start
        while i < slice.endIndex {
            if slice[i] == 0x60 {
                guard let close = scanInlineCodeClose(slice, after: i) else { break }
                i = close + 1
                continue
            }
            if isTrojanBiDiUnit(slice[i]) {
                let range = TextRange(location: base + (i - start), length: 1)
                out.append(MarkdownLintDiagnostic(rule: .unsafeLinkScheme, line: line + 1, message: "Disallowed bidirectional control character", range: range))
            }
            i += 1
        }
    }

    private static func prepareInlineDelimiterMatches(_ slice: ArraySlice<UInt16>, scratch: inout InlineScanScratch) {
        let start = slice.startIndex
        let length = slice.endIndex - start
        if scratch.matchBracket.count < length {
            let extra = length - scratch.matchBracket.count
            scratch.matchBracket.append(contentsOf: repeatElement(-1, count: extra))
            scratch.matchParen.append(contentsOf: repeatElement(-1, count: extra))
        }
        scratch.bracketStack.removeAll(keepingCapacity: true)
        scratch.parenStack.removeAll(keepingCapacity: true)

        var idx = start
        while idx < slice.endIndex {
            recordDelimiterMatchStep(slice[idx], rel: idx - start, scratch: &scratch)
            idx += 1
        }
    }

    private static func recordDelimiterMatchStep(_ unit: UInt16, rel: Int, scratch: inout InlineScanScratch) {
        if unit == 0x5B {
            scratch.matchBracket[rel] = -1
            scratch.bracketStack.append(rel)
        } else if unit == 0x5D, let openRel = scratch.bracketStack.popLast() {
            scratch.matchBracket[openRel] = rel
        } else if unit == 0x28 {
            scratch.matchParen[rel] = -1
            scratch.parenStack.append(rel)
        } else if unit == 0x29, let openRel = scratch.parenStack.popLast() {
            scratch.matchParen[openRel] = rel
        }
    }

    private static func scanInlineWithBalancedLinks(
        _ slice: ArraySlice<UInt16>,
        base: Int,
        line: Int,
        securityOnly: Bool,
        scratch: InlineScanScratch,
        into out: inout [MarkdownLintDiagnostic]
    ) {
        let start = slice.startIndex
        var i = start
        while i < slice.endIndex {
            if slice[i] == 0x60 {
                guard let close = scanInlineCodeClose(slice, after: i) else { break }
                i = close + 1
                continue
            }
            if let nextIndex = consumeBalancedLinkOrImage(slice, at: i, base: base, line: line, securityOnly: securityOnly, scratch: scratch, into: &out) {
                i = nextIndex
                continue
            }
            if isTrojanBiDiUnit(slice[i]) {
                let range = TextRange(location: base + (i - start), length: 1)
                out.append(MarkdownLintDiagnostic(rule: .unsafeLinkScheme, line: line + 1, message: "Disallowed bidirectional control character", range: range))
            }
            i += 1
        }
    }

    private static func scanInlineCodeClose(_ slice: ArraySlice<UInt16>, after openBacktick: Int) -> Int? {
        slice[(openBacktick + 1)...].firstIndex(of: 0x60)
    }

    private static func consumeBalancedLinkOrImage(
        _ slice: ArraySlice<UInt16>,
        at index: Int,
        base: Int,
        line: Int,
        securityOnly: Bool,
        scratch: InlineScanScratch,
        into out: inout [MarkdownLintDiagnostic]
    ) -> Int? {
        let start = slice.startIndex
        let end = slice.endIndex
        let isImage = slice[index] == 0x21 && index + 1 < end && slice[index + 1] == 0x5B
        guard slice[index] == 0x5B || isImage else { return nil }

        let openBracket = isImage ? index + 1 : index
        let closeRel = scratch.matchBracket[openBracket - start]
        guard closeRel >= 0 else { return nil }
        let closeBracket = start + closeRel
        guard closeBracket + 1 < end, slice[closeBracket + 1] == 0x28 else { return nil }

        let closeParenRel = scratch.matchParen[closeBracket + 1 - start]
        guard closeParenRel >= 0 else { return nil }
        let closeParen = start + closeParenRel
        let range = TextRange(location: base + (index - start), length: closeParen - index + 1)

        inspectMatchedLinkOrImage(
            slice,
            isImage: isImage,
            openBracket: openBracket,
            closeBracket: closeBracket,
            closeParen: closeParen,
            line: line,
            range: range,
            securityOnly: securityOnly,
            into: &out
        )
        return closeParen + 1
    }

    private static func inspectMatchedLinkOrImage(
        _ slice: ArraySlice<UInt16>,
        isImage: Bool,
        openBracket: Int,
        closeBracket: Int,
        closeParen: Int,
        line: Int,
        range: TextRange,
        securityOnly: Bool,
        into out: inout [MarkdownLintDiagnostic]
    ) {
        if !securityOnly, isImage, isImageAltEmpty(slice, from: openBracket + 1, to: closeBracket) {
            out.append(MarkdownLintDiagnostic(rule: .missingImageAltText, line: line + 1, message: "Images should have alternate text", range: range))
        }

        let hasLabelBiDi = sliceContainsTrojanBiDi(slice, from: openBracket + 1, to: closeBracket)
        if !hasLabelBiDi, inspectCleanASCIIDestination(slice, from: closeBracket + 2, to: closeParen, isImage: isImage, line: line, range: range, into: &out) != nil {
            return
        }

        let raw = String(decoding: slice[(closeBracket + 2)..<closeParen], as: UTF16.self)
        inspectNormalizedDestination(raw, isImage: isImage, hasLabelBiDi: hasLabelBiDi, line: line, range: range, into: &out)
    }

    private static func inspectNormalizedDestination(
        _ raw: String,
        isImage: Bool,
        hasLabelBiDi: Bool,
        line: Int,
        range: TextRange,
        into out: inout [MarkdownLintDiagnostic]
    ) {
        let dest = destination(raw)
        if !isImage, dest.isEmpty {
            out.append(MarkdownLintDiagnostic(rule: .emptyLinkTarget, line: line + 1, message: "Link target is empty", range: range))
        }
        let cleaned = normalizeDestinationCheckingScalars(dest)
        if hasUnsafeScheme(cleaned.normalized) || cleaned.hasDisallowedScalar || hasLabelBiDi {
            out.append(MarkdownLintDiagnostic(rule: .unsafeLinkScheme, line: line + 1, message: "Unsafe link scheme", range: range))
        }
        if isImage, hasUnsafeImagePath(cleaned.normalized) {
            out.append(MarkdownLintDiagnostic(rule: .unsafeImagePath, line: line + 1, message: "Unsafe image path", range: range))
        }
    }

    /// Checks whether image alt text is empty without allocating when content is ASCII.
    private static func isImageAltEmpty(_ slice: ArraySlice<UInt16>, from start: Int, to end: Int) -> Bool {
        var idx = start
        var allSpacesOrTabs = true
        while idx < end {
            let u = slice[idx]
            if u >= 0x21 && u < 0x7F { return false }
            if u != 0x20 && u != 0x09 {
                allSpacesOrTabs = false
                break
            }
            idx += 1
        }
        if allSpacesOrTabs { return true }
        return String(decoding: slice[start..<end], as: UTF16.self).trimmingCharacters(in: .whitespaces).isEmpty
    }
}

extension MarkdownAllConstructsLinter {
    /// Evaluates clean ASCII link/image destinations directly on `UInt16` indices with zero `String` allocations.
    /// Returns `nil` to fall back to full Unicode/entity/percent normalization whenever `%`, `&`, control chars, or non-ASCII units appear.
    private static func inspectCleanASCIIDestination(
        _ slice: ArraySlice<UInt16>,
        from rawStart: Int,
        to rawEnd: Int,
        isImage: Bool,
        line: Int,
        range: TextRange,
        into out: inout [MarkdownLintDiagnostic]
    ) -> Void? {
        guard isPrintableOrWhitespaceASCIISpan(slice, from: rawStart, to: rawEnd),
              let bounds = extractCleanASCIIDestinationBounds(slice, from: rawStart, to: rawEnd) else {
            return nil
        }
        if bounds.isEmpty {
            if !isImage {
                out.append(MarkdownLintDiagnostic(rule: .emptyLinkTarget, line: line + 1, message: "Link target is empty", range: range))
            }
            return ()
        }
        if hasUnsafeSchemeASCII(slice, from: bounds.lowerBound, to: bounds.upperBound) {
            out.append(MarkdownLintDiagnostic(rule: .unsafeLinkScheme, line: line + 1, message: "Unsafe link scheme", range: range))
        }
        if isImage, hasUnsafeImagePathASCII(slice, from: bounds.lowerBound, to: bounds.upperBound) {
            out.append(MarkdownLintDiagnostic(rule: .unsafeImagePath, line: line + 1, message: "Unsafe image path", range: range))
        }
        return ()
    }

    private static func isPrintableOrWhitespaceASCIISpan(_ slice: ArraySlice<UInt16>, from start: Int, to end: Int) -> Bool {
        var j = start
        while j < end {
            let u = slice[j]
            let isAllowedWhitespace = u == 0x09 || u == 0x0A || u == 0x0D
            guard (u >= 0x20 && u < 0x7F) || isAllowedWhitespace else { return false }
            j += 1
        }
        return true
    }

    private static func extractCleanASCIIDestinationBounds(_ slice: ArraySlice<UInt16>, from rawStart: Int, to rawEnd: Int) -> Range<Int>? {
        let trimmed = trimASCIIDestinationWhitespace(slice, from: rawStart, to: rawEnd)
        let unwrapped = unwrapASCIIDestinationToken(slice, bounds: trimmed)
        guard isUnencodedPrintableASCIISpan(slice, bounds: unwrapped) else { return nil }
        return unwrapped
    }

    private static func trimASCIIDestinationWhitespace(_ slice: ArraySlice<UInt16>, from start: Int, to end: Int) -> Range<Int> {
        var dStart = start
        var dEnd = end
        while dStart < dEnd, isASCIIWhitespaceUnit(slice[dStart]) { dStart += 1 }
        while dEnd > dStart, isASCIIWhitespaceUnit(slice[dEnd - 1]) { dEnd -= 1 }
        return dStart..<dEnd
    }

    @inline(__always)
    private static func isASCIIWhitespaceUnit(_ u: UInt16) -> Bool {
        u == 0x20 || u == 0x09 || u == 0x0A || u == 0x0D
    }

    private static func unwrapASCIIDestinationToken(_ slice: ArraySlice<UInt16>, bounds: Range<Int>) -> Range<Int> {
        let dStart = bounds.lowerBound
        let dEnd = bounds.upperBound
        guard dStart < dEnd else { return bounds }
        if slice[dStart] == 0x3C {
            var k = dStart + 1
            while k < dEnd, slice[k] != 0x3E { k += 1 }
            return k < dEnd ? (dStart + 1)..<k : bounds
        }
        var k = dStart
        while k < dEnd, slice[k] != 0x20, slice[k] != 0x09 { k += 1 }
        return dStart..<k
    }

    private static func isUnencodedPrintableASCIISpan(_ slice: ArraySlice<UInt16>, bounds: Range<Int>) -> Bool {
        for c in bounds {
            let u = slice[c]
            guard u >= 0x20, u < 0x7F, u != 0x25, u != 0x26 else { return false }
        }
        return true
    }
}

extension MarkdownAllConstructsLinter {
    @inline(__always)
    private static func asciiLower(_ u: UInt16) -> UInt16 {
        (u >= 0x41 && u <= 0x5A) ? (u | 0x20) : u
    }

    private static func sliceEqualsASCII(_ slice: ArraySlice<UInt16>, from start: Int, to end: Int, lowerBytes: StaticString) -> Bool {
        let len = end - start
        guard len == lowerBytes.utf8CodeUnitCount else { return false }
        return lowerBytes.withUTF8Buffer { buf in
            for idx in 0..<len {
                if asciiLower(slice[start + idx]) != UInt16(buf[idx]) { return false }
            }
            return true
        }
    }

    private static func hasUnsafeSchemeASCII(_ slice: ArraySlice<UInt16>, from start: Int, to end: Int) -> Bool {
        if end - start >= 2, slice[start] == 0x2F, slice[start + 1] == 0x2F { return true }
        var idx = start
        while idx < end {
            let u = slice[idx]
            if u == 0x3A {
                return idx > start && (isAllowedASCIIScheme(slice, from: start, to: idx) == false)
            }
            if u == 0x2F || u == 0x3F || u == 0x23 { return false }
            guard isASCIISchemeBodyChar(u) else { return false }
            idx += 1
        }
        return false
    }

    private static func isAllowedASCIIScheme(_ slice: ArraySlice<UInt16>, from start: Int, to end: Int) -> Bool {
        sliceEqualsASCII(slice, from: start, to: end, lowerBytes: "https")
            || sliceEqualsASCII(slice, from: start, to: end, lowerBytes: "http")
            || sliceEqualsASCII(slice, from: start, to: end, lowerBytes: "mailto")
    }

    @inline(__always)
    private static func isASCIISchemeBodyChar(_ u: UInt16) -> Bool {
        let lower = asciiLower(u)
        if lower >= 0x61 && lower <= 0x7A { return true }
        if u >= 0x30 && u <= 0x39 { return true }
        return u == 0x2B || u == 0x2E || u == 0x2D
    }

    private static func containsRemoteSchemeSeparatorASCII(_ slice: ArraySlice<UInt16>, from start: Int, to pathEnd: Int) -> Bool {
        guard pathEnd - start >= 3 else { return false }
        var k = start
        let limit = pathEnd - 2
        while k < limit {
            if slice[k] == 0x3A && slice[k + 1] == 0x2F && slice[k + 2] == 0x2F { return true }
            k += 1
        }
        return false
    }

    private static func containsTraversalOrBackslashASCII(_ slice: ArraySlice<UInt16>, from start: Int, to pathEnd: Int) -> Bool {
        if hasLeadingDotDotTraversalASCII(slice, from: start, to: pathEnd) { return true }
        var k = start
        while k < pathEnd {
            if slice[k] == 0x5C { return true }
            if isInteriorSlashDotDotSlashASCII(slice, at: k, pathEnd: pathEnd) { return true }
            k += 1
        }
        return false
    }

    private static func hasLeadingDotDotTraversalASCII(_ slice: ArraySlice<UInt16>, from start: Int, to pathEnd: Int) -> Bool {
        let pathLen = pathEnd - start
        guard pathLen >= 2, slice[start] == 0x2E, slice[start + 1] == 0x2E else { return false }
        return pathLen == 2 || slice[start + 2] == 0x2F || slice[start + 2] == 0x5C
    }

    @inline(__always)
    private static func isInteriorSlashDotDotSlashASCII(_ slice: ArraySlice<UInt16>, at index: Int, pathEnd: Int) -> Bool {
        guard index + 3 < pathEnd, slice[index] == 0x2F, slice[index + 3] == 0x2F else { return false }
        return slice[index + 1] == 0x2E && slice[index + 2] == 0x2E
    }

    private static func hasUnsafeImagePathASCII(_ slice: ArraySlice<UInt16>, from start: Int, to end: Int) -> Bool {
        var pathEnd = start
        while pathEnd < end && slice[pathEnd] != 0x3F && slice[pathEnd] != 0x23 {
            pathEnd += 1
        }
        let pathLen = pathEnd - start
        if pathLen >= 4, sliceEqualsASCII(slice, from: pathEnd - 4, to: pathEnd, lowerBytes: ".svg") { return true }
        if pathLen >= 5, sliceEqualsASCII(slice, from: pathEnd - 5, to: pathEnd, lowerBytes: ".svgz") { return true }
        // Remote schemes (`://` or `mailto:`) are classified by hasUnsafeScheme, not path traversal.
        if containsRemoteSchemeSeparatorASCII(slice, from: start, to: pathEnd) { return false }
        if pathLen >= 7, sliceEqualsASCII(slice, from: start, to: start + 7, lowerBytes: "mailto:") { return false }
        if pathLen > 0, slice[start] == 0x2F { return true }
        return containsTraversalOrBackslashASCII(slice, from: start, to: pathEnd)
    }
}

extension MarkdownAllConstructsLinter {
    private static func destination(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("<"), let end = s.firstIndex(of: ">") { return String(s[s.index(after: s.startIndex)..<end]) }
        if let space = s.firstIndex(where: { $0 == " " || $0 == "\t" }) { s = String(s[..<space]) }
        return s
    }

    static func isDisallowedControlOrBiDiScalar(_ value: UInt32) -> Bool {
        if value < 0x20 || (value >= 0x7F && value <= 0x9F) { return true }
        if (value >= 0x200B && value <= 0x200F) || (value >= 0x202A && value <= 0x202E) { return true }
        return (value >= 0x2060 && value <= 0x2069) || value == 0xFEFF || value == 0x061C
    }

    private static func isTrojanBiDiUnit(_ u: UInt16) -> Bool {
        let isBiDiRange = (u >= 0x202A && u <= 0x202E) || (u >= 0x2066 && u <= 0x2069) || u == 0x061C
        guard isBiDiRange else { return false }
        return isDisallowedControlOrBiDiScalar(UInt32(u))
    }

    private static func sliceContainsTrojanBiDi(_ slice: ArraySlice<UInt16>, from start: Int, to end: Int) -> Bool {
        guard start < end else { return false }
        for idx in start..<end {
            if isTrojanBiDiUnit(slice[idx]) { return true }
        }
        return false
    }

    /// Percent- and HTML-entity-decodes (bounded), strips control/C1/zero-width/BiDi scalars, and lowercases for scheme and path classification (`SEC-LINT-01`).
    static func normalize(_ input: String) -> String {
        normalizeDestinationCheckingScalars(input).normalized
    }

    private static func normalizeDestinationCheckingScalars(_ input: String) -> (normalized: String, hasDisallowedScalar: Bool) {
        let needsDecodeOrClean = input.utf8.contains { b in
            b < 0x20 || b >= 0x7F || b == 0x25 || b == 0x26 || (b >= 0x41 && b <= 0x5A)
        }
        guard needsDecodeOrClean else { return (input, false) }

        var hasDisallowed = containsDisallowedScalar(in: input)
        var s = decodeBoundedPercentEncoding(input)
        s = decodeEntities(s)
        var view = String.UnicodeScalarView()
        view.reserveCapacity(s.utf8.count)
        for u in s.unicodeScalars {
            if isDisallowedControlOrBiDiScalar(u.value) {
                hasDisallowed = true
            } else {
                view.append(u)
            }
        }
        return (String(view).lowercased(), hasDisallowed)
    }

    private static func containsDisallowedScalar(in text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if isDisallowedControlOrBiDiScalar(scalar.value) {
                return true
            }
        }
        return false
    }

    private static func decodeBoundedPercentEncoding(_ input: String) -> String {
        guard input.utf8.contains(0x25) else { return input }
        var current = input
        for _ in 0..<2 {
            let decoded = current.removingPercentEncoding ?? current
            if decoded == current { break }
            current = decoded
        }
        return current
    }

    private static func decodeEntityName(_ name: Substring) -> String? {
        if name.hasPrefix("#x") || name.hasPrefix("#X"),
           let v = UInt32(name.dropFirst(2), radix: 16),
           let u = UnicodeScalar(v) {
            return String(Character(u))
        }
        if name.hasPrefix("#"),
           let v = UInt32(name.dropFirst()),
           let u = UnicodeScalar(v) {
            return String(Character(u))
        }
        switch name {
        case "colon": return ":"
        case "tab", "newline": return ""
        case "amp": return "&"
        case "sol": return "/"
        default: return nil
        }
    }

    private static func decodeEntities(_ s: String) -> String {
        guard s.utf8.contains(0x26) else { return s }
        var result = ""
        result.reserveCapacity(s.utf8.count)
        var rest = Substring(s)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let tail = rest[amp...]
            if let semi = findEntitySemicolonBounded(in: tail),
               let decoded = decodeEntityName(tail[tail.index(after: tail.startIndex)..<semi]) {
                result += decoded
                rest = tail[tail.index(after: semi)...]
                continue
            }
            result.append("&")
            rest = tail.dropFirst()
        }
        result += rest
        return result
    }

    private static func findEntitySemicolonBounded(in tail: Substring) -> Substring.Index? {
        var cursor = tail.index(after: tail.startIndex)
        var steps = 1
        while cursor < tail.endIndex && steps <= 10 {
            if tail[cursor] == ";" { return cursor }
            cursor = tail.index(after: cursor)
            steps += 1
        }
        return nil
    }

    private static func hasUnsafeScheme(_ s: String) -> Bool {
        if s.hasPrefix("//") { return true }
        var idx = s.startIndex
        while idx < s.endIndex {
            let ch = s[idx]
            if ch == ":" {
                guard idx > s.startIndex else { return false }
                let scheme = String(s[..<idx])
                return !allowedSchemes.contains(scheme)
            }
            if ch == "/" || ch == "?" || ch == "#" { return false }
            guard isSchemeCharacter(ch) else { return false }
            idx = s.index(after: idx)
        }
        return false
    }

    private static func isSchemeCharacter(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "+" || ch == "." || ch == "-"
    }

    private static func hasUnsafeImagePath(_ s: String) -> Bool {
        let end = s.firstIndex(where: { $0 == "?" || $0 == "#" }) ?? s.endIndex
        let path = s[..<end]
        if path.hasSuffix(".svg") || path.hasSuffix(".svgz") { return true }
        if path.contains("://") || path.hasPrefix("mailto:") { return false }
        return isTraversalOrRootedPath(path)
    }

    private static func isTraversalOrRootedPath(_ path: Substring) -> Bool {
        if path.hasPrefix("/") || path.contains("\\") { return true }
        return path == ".." || path.hasPrefix("../") || path.contains("/../") || path.hasPrefix("..\\")
    }
}
