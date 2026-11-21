import Foundation

/// Immutable diagnostic representing a constitutional import or dependency boundary violation (`AR-002`, `AR-005`).
public struct ArchitectureFitnessViolation: Sendable, Equatable {
    public let filePath: String
    public let reason: String

    public init(filePath: String, reason: String) {
        self.filePath = filePath
        self.reason = reason
    }
}

/// Static architecture fitness analyzer enforcing `SwiftEditCore` UI/network/database import isolation (`AR-002`, `DATA-001`) and `swift-markdown` dependency allowlisting (`AR-005`).
public enum ArchitectureImportScanner {
    private static let forbiddenCoreModules: Set<String> = [
        "AppKit",
        "UIKit",
        "SwiftUI",
        "WebKit",
        "Combine",
        "Network",
        "SwiftEditUI",
        "SQLite3",
        "CoreData",
        "SwiftData",
    ]

    private static let allowlistedPackageIdentities: Set<String> = [
        "swift-markdown",
        "swift-cmark",
    ]

    /// Scans a single Swift source text and reports any forbidden framework imports inside `SwiftEditCore`.
    /// - Parameters:
    ///   - content: Raw UTF-8 Swift source code.
    ///   - filePath: Logical or physical path reported on violation.
    /// - Returns: Violations for each forbidden `import` statement outside comments.
    public static func scanSwiftEditCoreSource(content: String, filePath: String) -> [ArchitectureFitnessViolation] {
        let uncommented = stripCommentsPreservingStrings(from: content)
        var violations: [ArchitectureFitnessViolation] = []
        for rawLine in uncommented.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard let rootModule = extractImportedModule(from: trimmed) else {
                continue
            }
            if forbiddenCoreModules.contains(rootModule) {
                violations.append(ArchitectureFitnessViolation(
                    filePath: filePath,
                    reason: "Forbidden import '\(rootModule)' inside SwiftEditCore violates AR-002"
                ))
            }
        }
        return violations
    }

    private static func extractImportedModule(from line: String) -> String? {
        let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let importIndex = tokens.firstIndex(of: "import"), importIndex + 1 < tokens.count else {
            return nil
        }
        let declarationKinds: Set<String> = ["struct", "class", "enum", "protocol", "typealias", "func", "var", "let"]
        let nextToken = tokens[importIndex + 1]
        let moduleSpecifier: String
        if declarationKinds.contains(nextToken) {
            guard importIndex + 2 < tokens.count else { return nil }
            moduleSpecifier = tokens[importIndex + 2]
        } else {
            moduleSpecifier = nextToken
        }
        return moduleSpecifier.split(separator: ".").first.map(String.init)
    }

    /// Validates resolved SwiftPM package identities against the `AR-005` allowlist (`swift-markdown` and transitive `swift-cmark`).
    public static func validateExternalDependencies(packageIdentities: [String]) -> [ArchitectureFitnessViolation] {
        packageIdentities.compactMap { identity in
            let normalized = identity.lowercased()
            guard !allowlistedPackageIdentities.contains(normalized) else {
                return nil
            }
            return ArchitectureFitnessViolation(
                filePath: "Package.swift",
                reason: "Unapproved external dependency '\(identity)' violates AR-005"
            )
        }
    }

    /// Recursively scans all `.swift` files under `directoryURL` for forbidden `SwiftEditCore` imports (`TEST-006`).
    public static func scanDirectory(at directoryURL: URL) throws -> [ArchitectureFitnessViolation] {
        try scanSwiftFiles(at: directoryURL, using: scanSwiftEditCoreSource)
    }

    /// Audits a `SwiftEditUI` view source file for non-semantic color constructs outside comments (`UI-001`, `SEC-009`, `TEST-006`).
    ///
    /// Rejects `brandGround`, raw 6-digit or 8-digit `#RRGGBB` hex literals, inline `Color(.sRGB`, and inline `NSColor(srgbRed:` constructors so Light-mode chrome and modal sheets cannot regress to `1.10:1` dark-on-dark camouflage (`CWE-451`).
    /// - Parameters:
    ///   - content: Raw UTF-8 Swift source text from a view file.
    ///   - filePath: Logical or physical file path recorded in any emitted violation.
    /// - Returns: Deterministic list of `ArchitectureFitnessViolation` items found outside comments.
    public static func scanSwiftEditUIThemeTokens(content: String, filePath: String) -> [ArchitectureFitnessViolation] {
        let uncommented = stripCommentsPreservingStrings(from: content)
        var violations: [ArchitectureFitnessViolation] = []

        if uncommented.range(of: #"\bbrandGround\b"#, options: .regularExpression) != nil {
            violations.append(ArchitectureFitnessViolation(
                filePath: filePath,
                reason: "Forbidden token 'brandGround' in SwiftEditUI View violates UI-001 (CWE-451)"
            ))
        }

        let hexPattern = "\"#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?\""
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            let nsRange = NSRange(uncommented.startIndex..<uncommented.endIndex, in: uncommented)
            for match in regex.matches(in: uncommented, range: nsRange) {
                if let range = Range(match.range, in: uncommented) {
                    let literal = String(uncommented[range])
                    violations.append(ArchitectureFitnessViolation(
                        filePath: filePath,
                        reason: "Forbidden raw hex color literal \(literal) in SwiftEditUI View violates UI-001 (CWE-451)"
                    ))
                }
            }
        }

        if uncommented.contains("Color(.sRGB") {
            violations.append(ArchitectureFitnessViolation(
                filePath: filePath,
                reason: "Forbidden inline 'Color(.sRGB' constructor in SwiftEditUI View violates UI-001"
            ))
        }

        if uncommented.contains("NSColor(srgbRed:") {
            violations.append(ArchitectureFitnessViolation(
                filePath: filePath,
                reason: "Forbidden inline 'NSColor(srgbRed:' constructor in SwiftEditUI View violates UI-001"
            ))
        }

        return violations
    }

    /// Recursively scans all `.swift` files under `directoryURL` in deterministic path order to enforce semantic `PurpleThemePalette` view token usage (`UI-001`, `CWE-451`).
    /// - Parameter directoryURL: Root `Sources/SwiftEditUI/Views` directory URL to audit.
    /// - Returns: Aggregated `ArchitectureFitnessViolation` items across all discovered `.swift` files.
    /// - Throws: File I/O errors if an enumerated `.swift` file cannot be decoded as UTF-8.
    public static func scanSwiftEditUIViewsDirectory(at directoryURL: URL) throws -> [ArchitectureFitnessViolation] {
        try scanSwiftFiles(at: directoryURL, using: scanSwiftEditUIThemeTokens)
    }

    private static func scanSwiftFiles(
        at directoryURL: URL,
        using scanner: (String, String) -> [ArchitectureFitnessViolation]
    ) throws -> [ArchitectureFitnessViolation] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var swiftFiles: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            swiftFiles.append(fileURL)
        }
        swiftFiles.sort { $0.path < $1.path }

        var violations: [ArchitectureFitnessViolation] = []
        for fileURL in swiftFiles {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            violations.append(contentsOf: scanner(content, fileURL.path))
        }
        return violations
    }

    private static func stripCommentsPreservingStrings(from source: String) -> String {
        var output = String()
        output.reserveCapacity(source.utf8.count)
        let scalars = Array(source)
        var i = 0
        var inString = false
        while i < scalars.count {
            let ch = scalars[i]
            if inString {
                output.append(ch)
                if ch == "\\" && i + 1 < scalars.count {
                    output.append(scalars[i + 1])
                    i += 2
                    continue
                }
                if ch == "\"" {
                    inString = false
                }
                i += 1
                continue
            }
            if ch == "\"" {
                inString = true
                output.append(ch)
                i += 1
                continue
            }
            if ch == "/" && i + 1 < scalars.count {
                let next = scalars[i + 1]
                if next == "/" {
                    i += 2
                    while i < scalars.count && scalars[i] != "\n" {
                        i += 1
                    }
                    continue
                } else if next == "*" {
                    i += 2
                    while i + 1 < scalars.count && !(scalars[i] == "*" && scalars[i + 1] == "/") {
                        if scalars[i] == "\n" {
                            output.append("\n")
                        }
                        i += 1
                    }
                    i += 2
                    continue
                }
            }
            output.append(ch)
            i += 1
        }
        return output
    }
}

/// Decoded summary of `swift package dump-package` JSON evaluated against constitutional topology and dependency rules (`AR-001..AR-006`, `TEST-006`).
public struct PackageManifestSummary: Sendable, Equatable {
    public let platforms: [String: String]
    public let externalDependencies: [String]
    public let targetNames: [String]
    public let violations: [ArchitectureFitnessViolation]

    public init(
        platforms: [String: String],
        externalDependencies: [String],
        targetNames: [String],
        violations: [ArchitectureFitnessViolation]
    ) {
        self.platforms = platforms
        self.externalDependencies = externalDependencies
        self.targetNames = targetNames
        self.violations = violations
    }
}

/// Fail-closed `Decodable` evaluator for `swift package dump-package` JSON enforcing `.macOS(.v26)`, `.iOS(.v26)`, `swift-markdown` allowlisting, and inward `SwiftEditCore` dependency isolation (`TEST-006`, `SEC-012`).
public enum PackageManifestDumpValidator {
    private struct DumpPackagePayload: Decodable, Sendable {
        let platforms: [DumpPlatform]?
        let dependencies: [DumpDependency]?
        let targets: [DumpTarget]?
    }

    private struct DumpPlatform: Decodable, Sendable {
        let platformName: String
        let version: String
    }

    private struct DumpDependency: Decodable, Sendable {
        let sourceControl: [DumpSourceControl]?
    }

    private struct DumpSourceControl: Decodable, Sendable {
        let identity: String
    }

    private struct DumpTarget: Decodable, Sendable {
        let name: String
        let dependencies: [DumpTargetDependency]?
    }

    private struct DumpTargetDependency: Decodable, Sendable {
        let byName: [String?]?
        let product: [String?]?
    }

    /// Decodes `swift package dump-package` JSON `Data` and validates deployment platforms, external packages, and `SwiftEditCore` target dependencies.
    public static func validateDumpPackageJSON(_ data: Data) throws -> PackageManifestSummary {
        let payload: DumpPackagePayload
        do {
            payload = try JSONDecoder().decode(DumpPackagePayload.self, from: data)
        } catch {
            throw DomainError.ioFailure("Failed to decode swift package dump-package JSON: \(error.localizedDescription)")
        }

        var platforms: [String: String] = [:]
        for entry in payload.platforms ?? [] {
            platforms[entry.platformName.lowercased()] = entry.version
        }

        let externalDependencies = (payload.dependencies ?? [])
            .flatMap { $0.sourceControl ?? [] }
            .map(\.identity)

        var violations = ArchitectureImportScanner.validateExternalDependencies(
            packageIdentities: externalDependencies
        )

        if platforms["macos"] != "26.0" || platforms["ios"] != "26.0" {
            violations.append(ArchitectureFitnessViolation(
                filePath: "Package.swift",
                reason: "Manifest must declare .macOS(.v26) and .iOS(.v26) deployment targets (AR-001)"
            ))
        }

        var targetNames: [String] = []
        for target in payload.targets ?? [] {
            targetNames.append(target.name)
            guard target.name == "SwiftEditCore" else { continue }
            for depEntry in target.dependencies ?? [] {
                if let depTarget = depEntry.byName?.first ?? nil {
                    violations.append(ArchitectureFitnessViolation(
                        filePath: "Package.swift",
                        reason: "SwiftEditCore must not depend on target '\(depTarget)' (AR-002 / AR-006)"
                    ))
                }
                if let product = depEntry.product,
                   product.count >= 2,
                   let pkgName = product[1],
                   pkgName.lowercased() != "swift-markdown" {
                    violations.append(ArchitectureFitnessViolation(
                        filePath: "Package.swift",
                        reason: "SwiftEditCore depends on non-allowlisted product package '\(pkgName)' (AR-005)"
                    ))
                }
            }
        }

        return PackageManifestSummary(
            platforms: platforms,
            externalDependencies: externalDependencies,
            targetNames: targetNames,
            violations: violations
        )
    }
}
