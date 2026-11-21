import Foundation

/// Converts `NSString`-bridged Swift strings (as returned by `NSTextView.string`) into native contiguous UTF-8 storage
/// at the TextKit → `DocumentCore` boundary (`PERF-B1`, `UI-012`).
///
/// Why: a bridged `String` is backed lazily by the text storage's `NSString`; comparing it with the session text costs
/// ~25 ms per keystroke on a 1 MB buffer and every later `utf8`/`utf16` scan (gutter, status bar, lint, line index) runs
/// 2–19x slower. One `O(N)` transcoding (~2 ms per MB) at the boundary makes all downstream work run on native storage.
public enum NativeTextNormalizer {
    /// Returns `text` unchanged when it is already native contiguous UTF-8, otherwise a native copy with identical content.
    public static func native(_ text: String) -> String {
        if text.utf8.withContiguousStorageIfAvailable({ _ in true }) == true { return text }
        return String(decoding: Array(text.utf8), as: UTF8.self)
    }
}
