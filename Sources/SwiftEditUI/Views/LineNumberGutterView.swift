import Foundation
import SwiftEditCore
import SwiftUI

/// Immutable 1-based line-number gutter projection synchronized with `EditorZoomController` typography (`UI-001`, `UI-002`, `UI-004`, `UI-012`, `PERF-007`).
public struct LineNumberGutterProjection: Equatable, Sendable {
    /// Total 1-based line count (`>= 1`); stored without allocating `Array(1...lineCount)` per render pass (`PERF-007`).
    public let lineCount: Int
    /// Monotonically increasing 1-based line numbers (`1...max(1, lineCount)`), materialized on demand for API/test consumers.
    public var lineNumbers: [Int] { Array(1...lineCount) }
    /// 1-based line number currently containing the editor caret (`>= 1`).
    public let activeLine: Int
    /// Scaled monospaced font point size matching `EditorZoomController.scaledFontSizePoints`.
    public let fontSizePoints: Double

    public init(lineCount: Int, activeLine: Int, fontSizePoints: Double) {
        self.lineCount = max(1, lineCount)
        self.activeLine = min(max(1, activeLine), max(1, lineCount))
        self.fontSizePoints = fontSizePoints
    }

    public init(lineNumbers: [Int], activeLine: Int, fontSizePoints: Double) {
        let count = max(1, lineNumbers.count)
        self.lineCount = count
        self.activeLine = min(max(1, activeLine), count)
        self.fontSizePoints = fontSizePoints
    }

    /// `O(log L)` variant over a per-revision `DocumentTextIndex`; results equal `evaluate(text:caretLocation:fontSizePoints:)` (`PERF-B2`).
    public static func evaluate(index: DocumentTextIndex, caretLocation: Int, fontSizePoints: Double) -> LineNumberGutterProjection {
        LineNumberGutterProjection(
            lineCount: index.lineCount,
            activeLine: min(max(1, index.gutterActiveLine(caret: caretLocation)), index.lineCount),
            fontSizePoints: fontSizePoints
        )
    }

    /// Evaluates 1-based line count and active caret line in one allocation-free contiguous UTF-8 byte pass without forcing whole-document TextKit layout (`UI-012`, `PERF-007`).
    /// - Parameters:
    ///   - text: Active buffer string (`LF`, `CRLF`, or `CR` breaks).
    ///   - caretLocation: UTF-16 caret offset; clamped safely into `0...text.utf16.count`.
    ///   - fontSizePoints: Effective zoomed font size in points.
    /// - Returns: Clamped `LineNumberGutterProjection` with at least line `1`.
    public static func evaluate(text: String, caretLocation: Int, fontSizePoints: Double) -> LineNumberGutterProjection {
        let clampedCaret = max(0, caretLocation)
        if let fast = text.utf8.withContiguousStorageIfAvailable({ buf -> LineNumberGutterProjection in
            let count = buf.count
            guard let base = buf.baseAddress, count > 0 else {
                return LineNumberGutterProjection(lineCount: 1, activeLine: 1, fontSizePoints: fontSizePoints)
            }
            var totalLines = 1
            var activeLine = 1
            var utf16Offset = 0
            var i = 0
            while i < count {
                let b = base[i]
                if b == 0x0A {
                    totalLines += 1
                    utf16Offset += 1
                    i += 1
                    if utf16Offset <= clampedCaret { activeLine += 1 }
                } else if b == 0x0D {
                    totalLines += 1
                    let beforeBreak = utf16Offset
                    if i + 1 < count && base[i + 1] == 0x0A {
                        utf16Offset += 2
                        i += 2
                        if beforeBreak + 1 < clampedCaret { activeLine += 1 }
                    } else {
                        utf16Offset += 1
                        i += 1
                        if utf16Offset <= clampedCaret { activeLine += 1 }
                    }
                } else if b < 0x80 {
                    utf16Offset += 1
                    i += 1
                } else if b < 0xE0 {
                    utf16Offset += 1
                    i += 2
                } else if b < 0xF0 {
                    utf16Offset += 1
                    i += 3
                } else {
                    utf16Offset += 2
                    i += 4
                }
            }
            return LineNumberGutterProjection(
                lineCount: totalLines,
                activeLine: min(max(1, activeLine), totalLines),
                fontSizePoints: fontSizePoints
            )
        }) {
            return fast
        }

        let utf16 = text.utf16
        let boundedCaret = min(clampedCaret, utf16.count)
        var totalLines = 1
        var activeLine = 1
        var offset = 0
        var idx = utf16.startIndex
        while idx < utf16.endIndex {
            let unit = utf16[idx]
            if unit == 0x0A {
                totalLines += 1
                idx = utf16.index(after: idx)
                offset += 1
                if offset <= boundedCaret { activeLine += 1 }
            } else if unit == 0x0D {
                totalLines += 1
                let next = utf16.index(after: idx)
                let step = (next < utf16.endIndex && utf16[next] == 0x0A) ? 2 : 1
                idx = (step == 2) ? utf16.index(after: next) : next
                let beforeBreak = offset
                offset += step
                if step == 2 {
                    if beforeBreak + 1 < boundedCaret { activeLine += 1 }
                } else {
                    if offset <= boundedCaret { activeLine += 1 }
                }
            } else {
                idx = utf16.index(after: idx)
                offset += 1
            }
        }
        return LineNumberGutterProjection(
            lineCount: totalLines,
            activeLine: min(max(1, activeLine), totalLines),
            fontSizePoints: fontSizePoints
        )
    }
}

/// Immutable status-bar counter projection surfacing 1-based `Line`, `Column`, `Character count`, `UTF-8`, and `LF`/`CRLF`/`CR` (`UI-001`, `DATA-004`).
public struct StatusBarMetricsProjection: Equatable, Sendable {
    public let line: Int
    public let column: Int
    public let characterCount: Int
    public let encodingLabel: String
    public let lineEnding: LineEnding

    public init(line: Int, column: Int, characterCount: Int, encodingLabel: String, lineEnding: LineEnding) {
        self.line = line
        self.column = column
        self.characterCount = characterCount
        self.encodingLabel = encodingLabel
        self.lineEnding = lineEnding
    }

    /// `O(log L)` variant over the snapshot's per-revision `DocumentTextIndex`; results equal `evaluate(snapshot:caretLocation:)` (`PERF-B2`).
    public static func evaluate(snapshot: DocumentSnapshot, index: DocumentTextIndex, caretLocation: Int) -> StatusBarMetricsProjection {
        let clampedCaret = min(max(0, caretLocation), index.utf16Count)
        let cursor = index.cursorLineAndColumn(caret: clampedCaret) ?? (1, 1)
        return StatusBarMetricsProjection(
            line: cursor.line,
            column: cursor.column,
            characterCount: index.unicodeScalarCount,
            encodingLabel: displayLabel(for: snapshot.encoding),
            lineEnding: snapshot.lineEnding
        )
    }

    /// Evaluates clamped cursor and wire-format counters for `snapshot` at `caretLocation` (`UI-001`).
    public static func evaluate(snapshot: DocumentSnapshot, caretLocation: Int) -> StatusBarMetricsProjection {
        let clampedCaret = min(max(0, caretLocation), snapshot.text.utf16.count)
        let cursor = (try? CursorMetricsCalculator.metrics(in: snapshot.text, caretLocation: clampedCaret))
            ?? CursorMetrics(line: 1, column: 1, characterCount: snapshot.text.unicodeScalars.count)
        return StatusBarMetricsProjection(
            line: cursor.line,
            column: cursor.column,
            characterCount: cursor.characterCount,
            encodingLabel: displayLabel(for: snapshot.encoding),
            lineEnding: snapshot.lineEnding
        )
    }

    /// Human-readable status-bar label (`LF`, `CRLF`, `CR`) for `lineEnding`.
    public static func displayLabel(for lineEnding: LineEnding) -> String {
        switch lineEnding {
        case .lf: return "LF"
        case .crlf: return "CRLF"
        case .cr: return "CR"
        }
    }

    /// Human-readable status-bar encoding label (`UTF-8`, `UTF-8 BOM`, `UTF-16LE`, `UTF-16BE`).
    public static func displayLabel(for encoding: TextEncoding) -> String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf8WithBOM: return "UTF-8 BOM"
        case .utf16LEWithBOM: return "UTF-16LE"
        case .utf16BEWithBOM: return "UTF-16BE"
        }
    }

    /// Formatted status summary string (`Ln X, Col Y · N chars · UTF-8 · LF/CRLF/CR`).
    public var formattedSummary: String {
        "Ln \(line), Col \(column) · \(characterCount) chars · \(encodingLabel) · \(Self.displayLabel(for: lineEnding))"
    }
}

/// Single visible line fragment position sampled from TextKit 2 to align gutter numbers with soft-wrapped paragraphs (`BUG-012`).
public struct GutterLineMetric: Equatable, Sendable {
    public let lineNumber: Int
    public let minY: CGFloat
    public let height: CGFloat

    public init(lineNumber: Int, minY: CGFloat, height: CGFloat) {
        self.lineNumber = max(1, lineNumber)
        self.minY = minY.isFinite ? minY : 0
        self.height = height.isFinite ? max(0, height) : 0
    }
}

/// Synchronized vertical scroll offset and visible TextKit 2 fragment positions for `LineNumberGutterView` (`BUG-012`).
public struct GutterViewportMetrics: Equatable, Sendable {
    public let scrollOffsetY: CGFloat
    public let visibleLines: [GutterLineMetric]

    public init(scrollOffsetY: CGFloat = 0, visibleLines: [GutterLineMetric] = []) {
        self.scrollOffsetY = scrollOffsetY.isFinite ? max(0, scrollOffsetY) : 0
        self.visibleLines = visibleLines
    }
}

#if os(macOS)
/// Gutter lint dot: hovering shows an English popover with the rule code, message and explanation (also a tooltip and
/// the VoiceOver label). The hover area is larger than the 8 pt dot so it is easy to target.
struct LintBadge: View {
    let color: Color
    let details: String
    let isError: Bool
    @State private var isHovering = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .frame(width: 12, height: 16)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .popover(isPresented: $isHovering, arrowEdge: .trailing) {
                Text(details)
                    .appFont(.callout)
                    .frame(maxWidth: 380, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
            }
            .help(details)
            .accessibilityLabel("\(isError ? "Lint error" : "Lint warning"): \(details)")
    }
}

/// Left 1-based line-number gutter synchronized with TextKit 2 vertical scroll and soft-wrap fragment heights (`BUG-012`, `UI-001`, `UI-002`).
public struct LineNumberGutterView: View {
    public let projection: LineNumberGutterProjection
    public let palette: PurpleThemePalette
    /// Worst lint severity per 1-based line; rendered as an `O(1)` badge dot with tooltip and VoiceOver text.
    public let severityByLine: [Int: MarkdownLintSeverity]
    public var viewportMetrics: GutterViewportMetrics?
    /// Zoom- and font-driven width (`ZoomedChromeMetrics.gutterWidth`).
    public var width: CGFloat
    /// English hover text per 1-based line (rule code, message and explanation), shown by the lint badge.
    public var lintDetailsByLine: [Int: String]

    public init(
        projection: LineNumberGutterProjection,
        palette: PurpleThemePalette,
        severityByLine: [Int: MarkdownLintSeverity] = [:],
        viewportMetrics: GutterViewportMetrics? = nil,
        width: CGFloat = 52,
        lintDetailsByLine: [Int: String] = [:]
    ) {
        self.width = width
        self.lintDetailsByLine = lintDetailsByLine
        self.projection = projection
        self.palette = palette
        self.severityByLine = severityByLine
        self.viewportMetrics = viewportMetrics
    }

    public var body: some View {
        Group {
            if let viewportMetrics, !viewportMetrics.visibleLines.isEmpty {
                GeometryReader { _ in
                    ZStack(alignment: .topTrailing) {
                        ForEach(viewportMetrics.visibleLines, id: \.lineNumber) { metric in
                            lineRow(lineNumber: metric.lineNumber)
                                .offset(y: metric.minY - viewportMetrics.scrollOffsetY)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .clipped()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .trailing, spacing: 2) {
                        ForEach(1...projection.lineCount, id: \.self) { lineNumber in
                            lineRow(lineNumber: lineNumber)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(width: width)
        .background(palette.gutterSurface.swiftUIColor)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Line Number Gutter")
    }

    @ViewBuilder
    private func lineRow(lineNumber: Int) -> some View {
        let isActive = lineNumber == projection.activeLine
        let severity = severityByLine[lineNumber]
        let token = isActive ? palette.gutterActiveForeground : palette.gutterForeground
        let severityColor = severity.map { ($0 == .error ? palette.unbalancedBracketHighlight : palette.bidiWarningForeground).swiftUIColor }
        // Number right-aligned in its own column; diagnostics live in a separate left column so they can never
        // overlap or wrap the number (V-02, R-05).
        // Numbers are slightly smaller than the text (`numberScale`) and nudged down so their baseline matches the
        // editor line; both follow the zoomed editor font size (`REQ-022-02`).
        Text("\(lineNumber)")
            .appFont(size: projection.fontSizePoints * Self.numberScale, weight: isActive ? .semibold : .regular, monospaced: true, role: .editor)
            .padding(.top, projection.fontSizePoints * (1 - Self.numberScale) * 0.8)
            .foregroundStyle(token.swiftUIColor)
            .lineLimit(1)
            .fixedSize()
            .padding(.trailing, Self.numberTrailingPadding)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .overlay(alignment: .leading) {
                if let severityColor, let severity {
                    HStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(severityColor)
                            .frame(width: 3, height: max(12, projection.fontSizePoints * 0.95))
                            .accessibilityHidden(true)
                        LintBadge(
                            color: severityColor,
                            details: lintDetailsByLine[lineNumber] ?? (severity == .error ? "Markdown lint error on this line" : "Markdown lint warning on this line"),
                            isError: severity == .error
                        )
                    }
                }
            }
    }

    /// Gap between the number column and the text canvas.
    static let numberTrailingPadding: CGFloat = 10
    /// Line numbers render at 85% of the editor font size.
    static let numberScale: CGFloat = 0.85
}
#endif
