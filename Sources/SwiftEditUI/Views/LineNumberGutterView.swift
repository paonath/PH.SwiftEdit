import Foundation
import SwiftEditCore
import SwiftUI

/// Immutable 1-based line-number gutter projection synchronized with `EditorZoomController` typography (`UI-001`, `UI-002`, `UI-004`, `UI-012`).
public struct LineNumberGutterProjection: Equatable, Sendable {
    /// Monotonically increasing 1-based line numbers (`1...max(1, lineCount)`).
    public let lineNumbers: [Int]
    /// 1-based line number currently containing the editor caret (`>= 1`).
    public let activeLine: Int
    /// Scaled monospaced font point size matching `EditorZoomController.scaledFontSizePoints`.
    public let fontSizePoints: Double

    public init(lineNumbers: [Int], activeLine: Int, fontSizePoints: Double) {
        self.lineNumbers = lineNumbers
        self.activeLine = activeLine
        self.fontSizePoints = fontSizePoints
    }

    /// Evaluates 1-based line numbers and the active caret line in one UTF-16 pass without forcing whole-document TextKit layout (`UI-012`).
    /// - Parameters:
    ///   - text: Active buffer string (`LF`, `CRLF`, or `CR` breaks).
    ///   - caretLocation: UTF-16 caret offset; clamped safely into `0...text.utf16.count`.
    ///   - fontSizePoints: Effective zoomed font size in points.
    /// - Returns: Clamped `LineNumberGutterProjection` with at least line `1`.
    public static func evaluate(text: String, caretLocation: Int, fontSizePoints: Double) -> LineNumberGutterProjection {
        let totalLines = max(1, countLines(in: text))
        let clampedCaret = min(max(0, caretLocation), text.utf16.count)
        let resolvedLine = (try? CursorMetricsCalculator.metrics(in: text, caretLocation: clampedCaret).line) ?? 1
        return LineNumberGutterProjection(
            lineNumbers: Array(1...totalLines),
            activeLine: min(max(1, resolvedLine), totalLines),
            fontSizePoints: fontSizePoints
        )
    }

    private static func countLines(in text: String) -> Int {
        guard !text.isEmpty else { return 1 }
        let units = Array(text.utf16)
        var lines = 1
        var index = 0
        while index < units.count {
            let unit = units[index]
            if unit == 0x0A {
                lines += 1
                index += 1
            } else if unit == 0x0D {
                lines += 1
                index += (index + 1 < units.count && units[index + 1] == 0x0A) ? 2 : 1
            } else {
                index += 1
            }
        }
        return lines
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

#if os(macOS)
/// Left 1-based line-number gutter rendered immediately beside the `#FFFFFF`/`#000000` TextKit 2 editor canvas (`UI-001`, `UI-002`).
public struct LineNumberGutterView: View {
    public let projection: LineNumberGutterProjection
    public let palette: PurpleThemePalette

    public init(projection: LineNumberGutterProjection, palette: PurpleThemePalette) {
        self.projection = projection
        self.palette = palette
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(projection.lineNumbers, id: \.self) { lineNumber in
                    let isActive = lineNumber == projection.activeLine
                    let token = isActive ? palette.gutterActiveForeground : palette.gutterForeground
                    Text("\(lineNumber)")
                        .font(.system(size: projection.fontSizePoints, weight: isActive ? .semibold : .regular, design: .monospaced))
                        .foregroundStyle(token.swiftUIColor)
                        .frame(minWidth: 36, alignment: .trailing)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
        }
        .frame(minWidth: 52, maxWidth: 68)
        .background(palette.gutterSurface.swiftUIColor)
        .purpleHairlineBorder(palette: palette, edge: .trailing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Line Number Gutter")
    }
}
#endif
