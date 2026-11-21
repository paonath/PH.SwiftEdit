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

    /// Evaluates 1-based line count and active caret line in one allocation-free UTF-16 pass without forcing whole-document TextKit layout (`UI-012`, `PERF-007`).
    /// - Parameters:
    ///   - text: Active buffer string (`LF`, `CRLF`, or `CR` breaks).
    ///   - caretLocation: UTF-16 caret offset; clamped safely into `0...text.utf16.count`.
    ///   - fontSizePoints: Effective zoomed font size in points.
    /// - Returns: Clamped `LineNumberGutterProjection` with at least line `1`.
    public static func evaluate(text: String, caretLocation: Int, fontSizePoints: Double) -> LineNumberGutterProjection {
        let utf16 = text.utf16
        let clampedCaret = min(max(0, caretLocation), utf16.count)
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
                if offset <= clampedCaret { activeLine += 1 }
            } else if unit == 0x0D {
                totalLines += 1
                let next = utf16.index(after: idx)
                let step = (next < utf16.endIndex && utf16[next] == 0x0A) ? 2 : 1
                idx = (step == 2) ? utf16.index(after: next) : next
                let beforeBreak = offset
                offset += step
                if step == 2 {
                    if beforeBreak + 1 < clampedCaret { activeLine += 1 }
                } else {
                    if offset <= clampedCaret { activeLine += 1 }
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
        self.minY = minY
        self.height = max(0, height)
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
/// Left 1-based line-number gutter synchronized with TextKit 2 vertical scroll and soft-wrap fragment heights (`BUG-012`, `UI-001`, `UI-002`).
public struct LineNumberGutterView: View {
    public let projection: LineNumberGutterProjection
    public let palette: PurpleThemePalette
    /// Worst lint severity per 1-based line; rendered as an `O(1)` badge dot with tooltip and VoiceOver text.
    public let severityByLine: [Int: MarkdownLintSeverity]
    public var viewportMetrics: GutterViewportMetrics?

    public init(
        projection: LineNumberGutterProjection,
        palette: PurpleThemePalette,
        severityByLine: [Int: MarkdownLintSeverity] = [:],
        viewportMetrics: GutterViewportMetrics? = nil
    ) {
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
                    .padding(.horizontal, 8)
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
                    .padding(.horizontal, 8)
                }
            }
        }
        .frame(minWidth: 52, maxWidth: 68)
        .background(palette.gutterSurface.swiftUIColor)
        .purpleHairlineBorder(palette: palette, edge: .trailing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Line Number Gutter")
    }

    @ViewBuilder
    private func lineRow(lineNumber: Int) -> some View {
        let isActive = lineNumber == projection.activeLine
        let token = isActive ? palette.gutterActiveForeground : palette.gutterForeground
        HStack(spacing: 3) {
            if let severity = severityByLine[lineNumber] {
                Circle()
                    .fill((severity == .error ? palette.unbalancedBracketHighlight : palette.bidiWarningForeground).swiftUIColor)
                    .frame(width: 6, height: 6)
                    .help(severity == .error ? "Markdown lint error on this line" : "Markdown lint warning on this line")
                    .accessibilityLabel(severity == .error ? "Lint error" : "Lint warning")
            }
            Text("\(lineNumber)")
                .font(.system(size: projection.fontSizePoints, weight: isActive ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(token.swiftUIColor)
        }
        .frame(minWidth: 36, alignment: .trailing)
    }
}
#endif
