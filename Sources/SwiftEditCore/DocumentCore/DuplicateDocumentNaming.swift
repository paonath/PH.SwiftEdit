import Foundation

/// Pure naming rule for "Duplicate Document" (`REQ-021-05`): `name copy.ext`, then `name copy 2.ext` … in the same
/// folder as the source, never reusing an existing path (no overwrite, `CWE-22`/`CWE-73` safe: only the last path
/// component changes and it is derived from the source name).
public enum DuplicateDocumentNaming {
    public static let maxAttempts = 999

    /// File name for attempt `index` (`1` = `name copy.ext`).
    public static func copyName(for sourceName: String, attempt index: Int) -> String {
        let suffix = index <= 1 ? " copy" : " copy \(index)"
        let ns = sourceName as NSString
        let ext = ns.pathExtension
        // Dotfiles like `.env` have no stem/extension split: append the suffix to the whole name.
        let isDotfileWithoutExtension = sourceName.hasPrefix(".") && (sourceName.dropFirst() as Substring).contains(".") == false
        guard !ext.isEmpty, !isDotfileWithoutExtension else { return sourceName + suffix }
        return ns.deletingPathExtension + suffix + "." + ext
    }

    /// First free sibling URL for a copy of `source`, or `nil` after `maxAttempts` taken names.
    public static func copyURL(for source: URL, exists: (URL) -> Bool) -> URL? {
        let standardized = source.standardizedFileURL
        let folder = standardized.deletingLastPathComponent()
        let name = standardized.lastPathComponent
        guard !name.isEmpty, name != "/" else { return nil }
        for attempt in 1...maxAttempts {
            let candidate = folder.appendingPathComponent(copyName(for: name, attempt: attempt), isDirectory: false)
            if !exists(candidate) { return candidate }
        }
        return nil
    }
}
