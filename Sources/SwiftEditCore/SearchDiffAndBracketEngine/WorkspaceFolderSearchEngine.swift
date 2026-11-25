import Foundation

/// Indexed non-binary workspace file entry discovered by `WorkspaceFolderSearchEngine` (`REQ-007`, `SEC-003`).
public struct WorkspaceIndexedFile: Equatable, Sendable {
    public let url: URL
    public let relativePath: String
    public let filename: String

    public init(url: URL, relativePath: String, filename: String) {
        self.url = url
        self.relativePath = relativePath
        self.filename = filename
    }
}

/// Ranked Quick Open (`Cmd+T`) candidate (`REQ-007`).
public struct QuickOpenCandidate: Equatable, Sendable, Identifiable {
    public var id: String { url.path }
    public let url: URL
    public let relativePath: String
    public let filename: String
    public let score: Int

    public init(url: URL, relativePath: String, filename: String, score: Int) {
        self.url = url
        self.relativePath = relativePath
        self.filename = filename
        self.score = score
    }
}

/// Single literal match across workspace files for Find in Folder (`Ctrl+Shift+F`, `REQ-007`).
public struct FolderSearchMatch: Equatable, Sendable, Identifiable {
    public var id: String { "\(fileURL.path):\(matchRange.location)" }
    public let fileURL: URL
    public let relativePath: String
    public let lineNumber: Int
    public let columnNumber: Int
    public let linePreview: String
    public let matchRange: TextRange

    public init(
        fileURL: URL,
        relativePath: String,
        lineNumber: Int,
        columnNumber: Int,
        linePreview: String,
        matchRange: TextRange
    ) {
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.linePreview = linePreview
        self.matchRange = matchRange
    }
}

/// Bounded multi-file literal search outcome (`REQ-007`, `CWE-400`, `SEC-003`).
public struct FolderSearchResult: Equatable, Sendable {
    public let matches: [FolderSearchMatch]
    public let isTruncatedAtMatchCap: Bool
    public let skippedExternalSymlinkCount: Int

    public init(matches: [FolderSearchMatch], isTruncatedAtMatchCap: Bool, skippedExternalSymlinkCount: Int) {
        self.matches = matches
        self.isTruncatedAtMatchCap = isTruncatedAtMatchCap
        self.skippedExternalSymlinkCount = skippedExternalSymlinkCount
    }
}

/// Confined iterative workspace indexer and multi-file literal search engine (`REQ-007`, `SEC-003`, `CWE-1333`, `CWE-400`, `CWE-674`).
///
/// Security guarantees:
/// - **Zero Regex (`CWE-1333`)**: Delegates exclusively to `DocumentSearchEngine` literal/whole-word comparison.
/// - **Symlink Confinement (`SEC-003`)**: Enforces `EscapingSymlinkPolicy.skipAndReport` via `DotfileFolderNavigator` before any `8 KiB` binary read.
/// - **Cycle-Proof BFS (`CWE-674`)**: Deduplicates canonical directory and file paths via `visitedCanonicalDirs` / `seenCanonicalFiles` with zero recursion.
/// - **Bounded Resources (`CWE-400`)**: Caps indexed files at `maxIndexedFiles` (`10,000`) and emitted matches at `maxFolderMatches` (`5,000`).
public enum WorkspaceFolderSearchEngine {
    public static let maxIndexedFiles = 10_000
    public static let maxFolderMatches = 5_000

    private struct IndexingCrawlState {
        let rootPrefix: String
        let maxFiles: Int
        var queue: [URL]
        var visitedCanonicalDirs: Set<String>
        var seenCanonicalFiles: Set<String> = []
        var files: [WorkspaceIndexedFile] = []
        var skippedSymlinks: Int = 0
    }

    /// Iteratively indexes up to `maxFiles` non-binary regular files inside `rootURL` using `.skipAndReport` symlink confinement (`REQ-007`, `SEC-003`).
    public static func indexWorkspaceFiles(
        rootURL: URL,
        fileSystem: any FileSystemProviding,
        maxFiles: Int = maxIndexedFiles
    ) -> (files: [WorkspaceIndexedFile], skippedExternalSymlinks: Int) {
        let navigator = DotfileFolderNavigator(fileSystem: fileSystem)
        let scopeRoot = rootURL.standardizedFileURL
        let rootPrefix = scopeRoot.path.hasSuffix("/") ? scopeRoot.path : scopeRoot.path + "/"
        var state = IndexingCrawlState(
            rootPrefix: rootPrefix,
            maxFiles: maxFiles,
            queue: [scopeRoot],
            visitedCanonicalDirs: [scopeRoot.resolvingSymlinksInPath().standardizedFileURL.path]
        )
        var cursor = 0
        while cursor < state.queue.count, state.files.count < maxFiles {
            let dir = state.queue[cursor]
            cursor += 1
            guard let listing = try? navigator.listEntriesWithDiagnostics(
                in: dir,
                withinScope: scopeRoot,
                symlinkPolicy: .skipAndReport
            ) else { continue }
            state.skippedSymlinks += listing.skippedExternalSymlinkCount
            for entry in listing.entries {
                ingestDirectoryEntry(entry, into: &state)
                if state.files.count >= maxFiles { break }
            }
        }
        return (state.files, state.skippedSymlinks)
    }

    private static let excludedDirectoryNames: Set<String> = [".git", ".build", "node_modules"]

    private static func ingestDirectoryEntry(_ entry: FolderEntryDescriptor, into state: inout IndexingCrawlState) {
        if entry.isDirectory {
            guard !excludedDirectoryNames.contains(entry.name) else { return }
            let canonicalDir = entry.url.resolvingSymlinksInPath().standardizedFileURL.path
            if state.visitedCanonicalDirs.insert(canonicalDir).inserted {
                state.queue.append(entry.url)
            }
            return
        }
        guard !entry.isBinary, state.files.count < state.maxFiles else { return }
        let canonicalFile = entry.url.resolvingSymlinksInPath().standardizedFileURL.path
        guard state.seenCanonicalFiles.insert(canonicalFile).inserted else { return }
        let fullPath = entry.url.standardizedFileURL.path
        let rel = fullPath.hasPrefix(state.rootPrefix) ? String(fullPath.dropFirst(state.rootPrefix.count)) : entry.name
        state.files.append(WorkspaceIndexedFile(url: entry.url, relativePath: rel, filename: entry.name))
    }

    /// Ranks indexed workspace files against `query` by filename exact/prefix/substring and relative-path subsequence score (`REQ-007`).
    public static func rankQuickOpen(
        query: String,
        files: [WorkspaceIndexedFile],
        limit: Int = 100
    ) -> [QuickOpenCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return files
                .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
                .prefix(limit)
                .map { QuickOpenCandidate(url: $0.url, relativePath: $0.relativePath, filename: $0.filename, score: 1) }
        }
        let lowerQuery = trimmed.lowercased()
        var scored: [QuickOpenCandidate] = []
        for file in files {
            if let s = scoreCandidate(file: file, lowerQuery: lowerQuery) {
                scored.append(QuickOpenCandidate(url: file.url, relativePath: file.relativePath, filename: file.filename, score: s))
            }
        }
        scored.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.relativePath.count < $1.relativePath.count
        }
        return Array(scored.prefix(limit))
    }

    /// Searches indexed non-binary files inside `rootURL` using strictly literal/whole-word matching (`CWE-1333` zero-regex), capping total matches at `maxMatches` (`REQ-007`).
    public static func searchInFolder(
        query: String,
        rootURL: URL,
        fileSystem: any FileSystemProviding,
        isCaseSensitive: Bool = false,
        isWholeWord: Bool = false,
        maxFiles: Int = maxIndexedFiles,
        maxMatches: Int = maxFolderMatches
    ) -> FolderSearchResult {
        guard !query.isEmpty, query.utf16.count <= DocumentSearchEngine.maxQueryUTF16Units else {
            return FolderSearchResult(matches: [], isTruncatedAtMatchCap: false, skippedExternalSymlinkCount: 0)
        }
        let indexed = indexWorkspaceFiles(rootURL: rootURL, fileSystem: fileSystem, maxFiles: maxFiles)
        let loader = DocumentLoader(fileSystem: fileSystem)
        let options = SearchOptions(isCaseSensitive: isCaseSensitive, isWholeWord: isWholeWord)
        let scopeRoot = rootURL.standardizedFileURL
        var allMatches: [FolderSearchMatch] = []
        var truncated = false

        for file in indexed.files {
            if allMatches.count >= maxMatches {
                truncated = true
                break
            }
            guard let session = try? loader.load(from: file.url, withinScope: scopeRoot),
                  !session.isBinaryReadOnly, !session.isDegradedPlainText else { continue }
            let remaining = maxMatches - allMatches.count
            switch DocumentSearchEngine.find(query: query, in: session.snapshot, options: options) {
            case .completed(let ranges):
                if ranges.count > remaining {
                    appendFileMatches(ranges: Array(ranges.prefix(remaining)), in: session.text, file: file, into: &allMatches)
                    truncated = true
                } else {
                    appendFileMatches(ranges: ranges, in: session.text, file: file, into: &allMatches)
                }
            case .degradedOrTimedOut(.matchLimitExceeded):
                truncated = true
            case .degradedOrTimedOut:
                continue
            }
        }
        return FolderSearchResult(
            matches: allMatches,
            isTruncatedAtMatchCap: truncated,
            skippedExternalSymlinkCount: indexed.skippedExternalSymlinks
        )
    }

    private static func scoreCandidate(file: WorkspaceIndexedFile, lowerQuery: String) -> Int? {
        let lowerName = file.filename.lowercased()
        let stem = (file.filename as NSString).deletingPathExtension.lowercased()
        if lowerName == lowerQuery || stem == lowerQuery { return 1_000 }
        if lowerName.hasPrefix(lowerQuery) { return 700 - min(100, lowerName.count) }
        if lowerName.contains(lowerQuery) { return 450 - min(100, lowerName.count) }
        let lowerRel = file.relativePath.lowercased()
        if lowerRel.contains(lowerQuery) { return 250 }
        return isSubsequence(lowerQuery, of: lowerRel) ? 100 : nil
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var nIdx = needle.startIndex
        for ch in haystack where nIdx < needle.endIndex {
            if ch == needle[nIdx] { nIdx = needle.index(after: nIdx) }
        }
        return nIdx == needle.endIndex
    }

    private static func appendFileMatches(
        ranges: [TextRange],
        in text: String,
        file: WorkspaceIndexedFile,
        into out: inout [FolderSearchMatch]
    ) {
        guard !ranges.isEmpty else { return }
        let index = DocumentTextIndex(text: text)
        let nsText = text as NSString
        for r in ranges {
            let loc = index.cursorLineAndColumn(caret: r.location) ?? (line: 1, column: 1)
            let preview = extractLinePreview(nsText: nsText, lineNumber: loc.line, in: text)
            out.append(FolderSearchMatch(
                fileURL: file.url,
                relativePath: file.relativePath,
                lineNumber: loc.line,
                columnNumber: loc.column,
                linePreview: preview,
                matchRange: r
            ))
        }
    }

    private static func extractLinePreview(nsText: NSString, lineNumber: Int, in text: String) -> String {
        guard let lineRange = UTF16LineBreakScanner.lineContentRange(forLine: lineNumber, in: text),
              lineRange.location + lineRange.length <= nsText.length else { return "" }
        let raw = nsText.substring(with: NSRange(location: lineRange.location, length: min(200, lineRange.length)))
        return raw.trimmingCharacters(in: .whitespaces)
    }
}
