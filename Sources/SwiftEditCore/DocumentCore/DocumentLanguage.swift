import Foundation

/// Editing language of a tab, resolved once from its filename and cached on `TabDescriptor` (`BC-001`, `AR-009`).
///
/// A closed `enum` (not a language-plugin protocol) with a handful of variants; dispatch stays an explicit,
/// allocation-free `switch` at each engine entry point.
public enum DocumentLanguage: String, Codable, Sendable, CaseIterable {
    case markdown, yaml, json, html, log, plainText

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]
    private static let yamlExtensions: Set<String> = ["yml", "yaml"]
    private static let jsonExtensions: Set<String> = ["json", "jsonl"]
    private static let htmlExtensions: Set<String> = ["html", "htm"]
    private static let logExtensions: Set<String> = ["log"]

    /// Status-bar label (`UI-001`).
    public var statusBarLabel: String {
        switch self {
        case .markdown: return "Markdown"
        case .yaml: return "YAML"
        case .json: return "JSON"
        case .html: return "HTML"
        case .log: return "Log"
        case .plainText: return "Plain Text"
        }
    }

    /// Classifies `filename` by its final path extension only (case-insensitive).
    ///
    /// - Untitled buffers (`nil`, empty, or `Untitled…` without extension) are Markdown, matching `newUntitledTab()`.
    /// - Double extensions use the last component only (`config.yml.bak` is plain text, `notes.yaml.md` is Markdown) so a
    ///   name can never smuggle a different engine onto a buffer (STRIDE Spoofing).
    /// - Binary or degraded buffers are always `.plainText`, so no YAML/Markdown engine ever touches them (`DATA-003`, `SEC-012`).
    public static func resolve(filename: String?, isBinary: Bool = false, isDegraded: Bool = false) -> DocumentLanguage {
        guard !isBinary, !isDegraded else { return .plainText }
        guard let filename, !filename.isEmpty else { return .markdown }
        let ext = (filename as NSString).pathExtension.lowercased()
        if ext.isEmpty { return filename.hasPrefix("Untitled") ? .markdown : .plainText }
        if markdownExtensions.contains(ext) { return .markdown }
        if yamlExtensions.contains(ext) { return .yaml }
        if jsonExtensions.contains(ext) { return .json }
        if htmlExtensions.contains(ext) { return .html }
        if logExtensions.contains(ext) { return .log }
        return .plainText
    }
}
