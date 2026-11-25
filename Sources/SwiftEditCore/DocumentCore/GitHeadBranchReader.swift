import Foundation

/// Confined zero-subprocess `.git/HEAD` branch reader (`REQ-012`, `SEC-003`, `SEC-004`).
///
/// Security guarantees:
/// - **Zero Subprocesses (`SEC-004`)**: Reads `.git/HEAD` directly via `FileSystemProviding` without invoking `git` or `/bin/sh`.
/// - **Canonical Scope Confinement (`SEC-003`)**: Rejects symlinked `HEAD` files and halts parent traversal strictly at `scopeRootURL`.
/// - **Bounded & Sanitized (`CWE-20`, `CWE-400`)**: Caps reads at `maxHeadBytes` (`256`) and allowlists `[A-Za-z0-9._/-]` branch scalars (blocking URLs, credentials, and `..` sequences).
public enum GitHeadBranchReader {
    public static let maxHeadBytes = 256

    public static func readBranchName(
        startingAt url: URL,
        withinScope scopeRootURL: URL,
        fileSystem: any FileSystemProviding
    ) -> String? {
        let canonicalScope = scopeRootURL.resolvingSymlinksInPath().standardizedFileURL
        let scopePath = canonicalScope.path
        let scopePrefix = scopePath.hasSuffix("/") ? scopePath : scopePath + "/"
        var current = url.standardizedFileURL

        for _ in 0..<64 {
            let canonicalCurrent = current.resolvingSymlinksInPath().standardizedFileURL.path
            guard canonicalCurrent == scopePath || canonicalCurrent.hasPrefix(scopePrefix) else {
                break
            }
            let headURL = current.appendingPathComponent(".git", isDirectory: true).appendingPathComponent("HEAD")
            if let branch = readHeadFileIfConfined(at: headURL, scopeRoot: canonicalScope, fileSystem: fileSystem) {
                return branch
            }
            if canonicalCurrent == scopePath || current.path == "/" {
                break
            }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            if parent.path == current.path { break }
            current = parent
        }
        return nil
    }

    private static func readHeadFileIfConfined(
        at headURL: URL,
        scopeRoot: URL,
        fileSystem: any FileSystemProviding
    ) -> String? {
        guard let attrs = try? fileSystem.fileAttributes(at: headURL, withinScope: scopeRoot),
              !attrs.isSymbolicLink,
              attrs.byteSize > 0,
              attrs.byteSize <= UInt64(maxHeadBytes) else {
            return nil
        }
        let canonicalHead = headURL.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPrefix = scopeRoot.path.hasSuffix("/") ? scopeRoot.path : scopeRoot.path + "/"
        guard canonicalHead.hasPrefix(rootPrefix),
              let data = try? fileSystem.readData(at: headURL, maxBytes: maxHeadBytes, withinScope: scopeRoot),
              let raw = String(data: data, encoding: .utf8) else {
            return nil
        }
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !line.contains("\n"), !line.contains("\r") else { return nil }
        if line.hasPrefix("ref:") {
            let ref = line.dropFirst(4).trimmingCharacters(in: .whitespaces)
            let headsPrefix = "refs/heads/"
            let name = ref.hasPrefix(headsPrefix) ? String(ref.dropFirst(headsPrefix.count)) : ref
            return isValidGitBranchRef(name) ? name : nil
        }
        if line.count >= 7, line.count <= 64, line.allSatisfy(\.isHexDigit) {
            return String(line.prefix(7))
        }
        return nil
    }

    private static func isValidGitBranchRef(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 120,
              !name.hasPrefix("/"), !name.hasSuffix("/"),
              !name.hasPrefix("."), !name.hasSuffix("."),
              !name.contains(".."), !name.contains("//") else {
            return false
        }
        for byte in name.utf8 {
            let allowed = (byte >= 0x41 && byte <= 0x5A)
                || (byte >= 0x61 && byte <= 0x7A)
                || (byte >= 0x30 && byte <= 0x39)
                || byte == 0x2D || byte == 0x5F || byte == 0x2E || byte == 0x2F
            if !allowed { return false }
        }
        return true
    }
}

/// Pure `SwiftEditCore` selection character/line and Markdown word-count metrics (`REQ-012`).
public struct EnrichedStatusBarMetrics: Equatable, Sendable {
    public let selectedCharacterCount: Int
    public let selectedLineCount: Int
    public let markdownWordCount: Int?

    public init(selectedCharacterCount: Int = 0, selectedLineCount: Int = 0, markdownWordCount: Int? = nil) {
        self.selectedCharacterCount = selectedCharacterCount
        self.selectedLineCount = selectedLineCount
        self.markdownWordCount = markdownWordCount
    }

    public static func evaluate(
        snapshot: DocumentSnapshot,
        selection: TextRange,
        isMarkdown: Bool
    ) -> EnrichedStatusBarMetrics {
        var selChars = 0
        var selLines = 0
        let nsText = snapshot.text as NSString
        let totalUTF16 = nsText.length
        if selection.length > 0, selection.location >= 0, selection.location < totalUTF16 {
            let clampedLen = min(selection.length, totalUTF16 - selection.location)
            let slice = nsText.substring(with: NSRange(location: selection.location, length: clampedLen))
            selChars = slice.unicodeScalars.count
            selLines = countOccupiedLines(in: slice)
        }
        let wordCount: Int? = (isMarkdown && !snapshot.isBinaryReadOnly && !snapshot.isDegradedPlainText)
            ? countWords(in: snapshot.text)
            : nil
        return EnrichedStatusBarMetrics(
            selectedCharacterCount: selChars,
            selectedLineCount: selLines,
            markdownWordCount: wordCount
        )
    }

    private static func countOccupiedLines(in slice: String) -> Int {
        guard !slice.isEmpty else { return 0 }
        var lines = 1
        var prevCR = false
        for b in slice.utf8 {
            if b == 0x0A {
                if !prevCR { lines += 1 }
                prevCR = false
            } else if b == 0x0D {
                lines += 1
                prevCR = true
            } else {
                prevCR = false
            }
        }
        return lines
    }

    private static func countWords(in text: String) -> Int {
        var count = 0
        var inWord = false
        for scalar in text.unicodeScalars {
            let isWordChar = CharacterSet.alphanumerics.contains(scalar) || scalar.value == 0x27 || scalar.value == 0x2D
            if isWordChar {
                if !inWord { count += 1; inWord = true }
            } else {
                inWord = false
            }
        }
        return count
    }
}
