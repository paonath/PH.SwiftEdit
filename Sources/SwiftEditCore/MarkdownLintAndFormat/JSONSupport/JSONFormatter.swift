import Foundation

/// Single-revision JSON Pretty-Print (`2`-space sorted keys) and Minify formatter preserving `LineEnding` (`REQ-010`, `DATA-004`).
///
/// Fails closed (`nil`) on binary, degraded, deeply nested (`> 128`), or syntactically invalid JSON so destructive partial edits never occur (`N11`).
public enum JSONFormatter {
    /// Formats `snapshot` into canonical 2-space indented JSON with deterministically sorted object keys (`REQ-010`).
    public static func prettyPrint(snapshot: DocumentSnapshot) -> TextEdit? {
        formatJSON(snapshot: snapshot, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes], appendTrailingNewline: true)
    }

    /// Compacts `snapshot` into single-line minified JSON with deterministically sorted object keys (`REQ-010`).
    public static func minify(snapshot: DocumentSnapshot) -> TextEdit? {
        formatJSON(snapshot: snapshot, options: [.sortedKeys, .withoutEscapingSlashes], appendTrailingNewline: false)
    }

    private static func formatJSON(
        snapshot: DocumentSnapshot,
        options: JSONSerialization.WritingOptions,
        appendTrailingNewline: Bool
    ) -> TextEdit? {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return nil }
        guard JSONStructureLinter.lint(snapshot: snapshot, isJSONLines: false).isEmpty else {
            return nil
        }
        guard let inputData = snapshot.text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: inputData, options: [.fragmentsAllowed]),
              let outputData = try? JSONSerialization.data(withJSONObject: object, options: options),
              var rendered = String(data: outputData, encoding: .utf8) else {
            return nil
        }
        if appendTrailingNewline, !rendered.hasSuffix("\n") {
            rendered += "\n"
        }
        if snapshot.text.utf8.contains(0x0D) {
            rendered = LineEnding.detect(in: snapshot.text).apply(toCanonicalLF: rendered)
        }
        guard rendered != snapshot.text else { return nil }
        return TextEdit(
            range: TextRange(location: 0, length: (snapshot.text as NSString).length),
            replacement: rendered
        )
    }
}
