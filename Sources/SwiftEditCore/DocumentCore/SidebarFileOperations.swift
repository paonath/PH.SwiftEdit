import Foundation

/// Validates single-segment sidebar file and directory names prior to path construction (`CWE-22`, `BC-007`, `BC-012`, `SEC-012`).
public enum SidebarItemNameValidator {
    public static let maxUTF8Bytes: Int = 255

    /// Ensures `rawName` is a non-empty single path segment (`<= 255` UTF-8 bytes) free of `.`, `..`, `/`, `:`, ASCII control characters, and Unicode BiDi overrides.
    /// - Parameter rawName: Candidate item name supplied by a sidebar Create or Rename action.
    /// - Returns: Validated `rawName`.
    /// - Throws: `DomainError.invalidItemName` when any syntactic or character constraint fails.
    @discardableResult
    public static func validate(_ rawName: String) throws -> String {
        guard !rawName.isEmpty,
              rawName != ".",
              rawName != "..",
              rawName.utf8.count <= maxUTF8Bytes else {
            throw DomainError.invalidItemName(rawName)
        }

        for scalar in rawName.unicodeScalars {
            let v = scalar.value
            let isSeparator = (v == 0x2F || v == 0x3A)
            let isControl = (v <= 0x1F || v == 0x7F)
            let isBiDiOverride = (0x202A...0x202E).contains(v) || (0x2066...0x2069).contains(v) || v == 0x061C
            if isSeparator || isControl || isBiDiOverride {
                throw DomainError.invalidItemName(rawName)
            }
        }
        return rawName
    }
}

/// Selects move (`cut`) vs non-overwriting collision-suffixed copy (`copy`) semantics on sidebar `pasteItem` (`BC-012`, `DATA-004`).
public enum PasteMode: Equatable, Sendable {
    case cut
    case copy
}

/// Narrow `Sendable` seam wrapping `FileManager.trashItem` so sidebar Delete never permanently removes files (`AR-007`, `BC-012`, `SEC-012`, `TEST-004`).
public protocol ItemTrashing: Sendable {
    func trashItem(at url: URL) throws
}

/// Production `ItemTrashing` adapter forwarding to `FileManager.default.trashItem`.
public struct FileManagerTrasher: ItemTrashing, Sendable {
    public init() {}

    public func trashItem(at url: URL) throws {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }
}

/// Allocates the first free Finder-style collision suffix (`name copy.ext`, `name copy 2.ext`, ...) without overwriting existing files.
enum SidebarCollisionSuffixAllocator {
    static func firstAvailableName(for originalName: String, isTaken: (String) -> Bool) throws -> String {
        _ = try SidebarItemNameValidator.validate(originalName)
        if !isTaken(originalName) {
            return originalName
        }
        let (stem, extSuffix) = splitStemAndExtension(originalName)
        let firstCandidate = "\(stem) copy\(extSuffix)"
        if !isTaken(firstCandidate) {
            return try SidebarItemNameValidator.validate(firstCandidate)
        }
        var ordinal = 2
        while ordinal <= 10_000 {
            let candidate = "\(stem) copy \(ordinal)\(extSuffix)"
            if !isTaken(candidate) {
                return try SidebarItemNameValidator.validate(candidate)
            }
            ordinal += 1
        }
        throw DomainError.destinationAlreadyExists(path: originalName)
    }

    private static func splitStemAndExtension(_ name: String) -> (stem: String, extSuffix: String) {
        if let dotIndex = name.lastIndex(of: "."), dotIndex > name.startIndex {
            let stem = String(name[..<dotIndex])
            let extSuffix = String(name[dotIndex...])
            return (stem, extSuffix)
        }
        return (name, "")
    }
}
