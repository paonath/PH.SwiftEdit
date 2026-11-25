#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Classification of asset verification failures mapped to deterministic CLI exit codes.
///
/// - `integrity`: Missing file, broken relative link, or mismatched token (`exit 1`).
/// - `security`: Path traversal, symlink escape, host-path leak, SVG script, or alpha contract violation (`exit 2`).
enum IssueSeverity: String, Sendable {
    case integrity = "INTEGRITY_ERROR"
    case security = "SECURITY_VIOLATION"
}

/// Immutable diagnostic emitted for a single integrity or security rule violation.
struct VerificationIssue: Sendable, Equatable {
    let severity: IssueSeverity
    let path: String
    let message: String
}

/// Aggregated verification outcome prioritizing security violations (`exit 2`) over integrity errors (`exit 1`).
struct VerificationReport: Sendable {
    let issues: [VerificationIssue]

    var exitCode: Int32 {
        if issues.contains(where: { $0.severity == .security }) {
            return 2
        }
        return issues.isEmpty ? 0 : 1
    }
}

/// Extracts non-external relative asset references from Markdown links and HTML `<img>` tags while ignoring fenced/inline code spans.
enum MarkdownLinkScanner {
    /// Parses Markdown content and returns relative file paths excluding `http`, `https`, and `mailto` URIs.
    /// - Parameter markdown: Raw UTF-8 Markdown text.
    /// - Returns: Ordered list of raw relative link targets stripped of URL fragments.
    static func extractRelativeTargets(from markdown: String) -> [String] {
        let strippedFences = markdown.replacingOccurrences(
            of: "```[\\s\\S]*?```",
            with: "",
            options: .regularExpression
        )
        let strippedInline = strippedFences.replacingOccurrences(
            of: "`[^`\\n]*`",
            with: "",
            options: .regularExpression
        )
        let patterns = [
            "\\[[^\\]]*\\]\\(([^)\\s]+)\\)",
            "<img\\s+[^>]*src=\"([^\"]+)\"",
        ]
        var targets: [String] = []
        let range = NSRange(strippedInline.startIndex..<strippedInline.endIndex, in: strippedInline)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: strippedInline, range: range) {
                guard let r = Range(match.range(at: 1), in: strippedInline) else { continue }
                let raw = String(strippedInline[r]).split(separator: "#").first.map(String.init) ?? ""
                if raw.isEmpty || raw.hasPrefix("http://") || raw.hasPrefix("https://") || raw.hasPrefix("mailto:") {
                    continue
                }
                targets.append(raw)
            }
        }
        return targets
    }
}

/// Security boundary guard enforcing directory confinement (`CWE-22`, `[SEC-003]`), symlink detection, and `16 MiB` resource caps (`CWE-400`).
enum PathConfinementGuard {
    /// Maximum allowed byte size (`16 MiB`) for any single documentation or icon file before `ImageIO` decoding.
    static let maxAssetBytes: UInt64 = 16 * 1024 * 1024

    /// Rejects files exceeding `maxAssetBytes` to prevent decompression or memory-exhaustion DoS (`CWE-400`).
    static func validateFileSize(at url: URL, reportedPath: String) -> VerificationIssue? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64,
              size > maxAssetBytes else {
            return nil
        }
        return VerificationIssue(
            severity: .security,
            path: reportedPath,
            message: "Asset exceeds 16 MiB security ceiling (\(size) bytes) (CWE-400)"
        )
    }

    /// Resolves symbolic links and verifies that `candidateURL` stays strictly inside `canonicalBoundary` (`CWE-22`).
    static func isConfined(candidateURL: URL, withinCanonicalDirectory canonicalBoundary: String) -> Bool {
        let resolvedPath = candidateURL.resolvingSymlinksInPath().standardizedFileURL.path
        return resolvedPath == canonicalBoundary || resolvedPath.hasPrefix(canonicalBoundary + "/")
    }

    /// Returns `true` when the filesystem entry itself is a symbolic link (`lstat` semantics via `attributesOfItem`).
    static func isSymbolicLink(at url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let type = attrs[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeSymbolicLink
    }
}

/// Single slot declaration inside an Xcode `AppIcon.appiconset/Contents.json` manifest.
struct AppIconSlotEntry: Codable, Sendable {
    let idiom: String
    let size: String
    let scale: String
    let filename: String?
}

/// Metadata footer inside `Contents.json` (`version: 1`, `author: "xcode"`).
struct AppIconInfo: Codable, Sendable {
    let version: Int
    let author: String
}

/// Root `Codable` representation of an Xcode `.appiconset/Contents.json` catalog manifest.
struct AppIconContentsManifest: Codable, Sendable {
    let images: [AppIconSlotEntry]
    let info: AppIconInfo
}

/// Normative Xcode icon slot contract computing expected pixel edge length from `pointSize * scaleFactor`.
struct IconSlotSpec: Hashable, Sendable {
    let idiom: String
    let pointSize: Int
    let scaleFactor: Int

    var sizeString: String { "\(pointSize)x\(pointSize)" }
    var scaleString: String { "\(scaleFactor)x" }
    var expectedPixels: Int { pointSize * scaleFactor }
}

/// Platform-specific `AppIcon.appiconset` specification binding slot completeness and alpha-channel invariants (`[UI-001]`).
struct AppIconCatalogSpec: Sendable {
    let relativeDir: String
    let expectedUniqueFilesCount: Int
    let requiredHasAlpha: Bool
    let slots: [IconSlotSpec]
}

/// Decoded PNG raster header attributes read via `ImageIO` without caching uncompressed pixel buffers.
struct PngImageHeader: Sendable {
    let width: Int
    let height: Int
    let hasAlpha: Bool
}

/// Reads PNG dimensions and alpha presence via `CGImageSourceCopyPropertiesAtIndex` (`kCGImageSourceShouldCache: false`).
enum PngHeaderInspector {
    /// Inspects the primary image header at `url`, returning `nil` if the file is unreadable or not a valid image source.
    static func inspect(url: URL) -> PngImageHeader? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        let hasAlpha = (props[kCGImagePropertyHasAlpha] as? Bool) ?? false
        return PngImageHeader(width: width, height: height, hasAlpha: hasAlpha)
    }
}

/// Verifies promoted `docs/design/` deliverables, Markdown link confinement, and `AppIcon.appiconset` catalogs against `openspec/Constitution.md` (`v1.2.0`).
struct DesignAssetsVerifier: Sendable {
    let rootURL: URL

    private static let requiredPromotedPaths: [String] = [
        "README.md",
        "docs/design/color-schemes-and-zed-layout.md",
        "docs/design/assets/app-icons-riepilogo.md",
        "docs/design/assets/logo-e2-refined.svg",
        "docs/design/assets/logo-e2-refined-512.png",
        "docs/design/assets/preview-dark-black-purple.png",
        "docs/design/assets/preview-light-purple.png",
        "docs/design/assets/preview-file-compare-diff.png",
    ]

    private static let markdownFilesToCheck: [String] = [
        "README.md",
        "docs/design/color-schemes-and-zed-layout.md",
        "docs/design/assets/app-icons-riepilogo.md",
    ]

    private static let requiredSvgHexTokens = ["#0B0614", "#7C3AED", "#A78BFA", "#C4B5FD"]
    private static let requiredColorSpecTokens = ["#0B0614", "#7C3AED", "#A78BFA", "#C4B5FD", "#FFFFFF", "#000000", "50%", "300%"]

    private static let forbiddenSvgPatterns = [
        "<script",
        "<foreignobject",
        "javascript:",
        "onload=",
        "onerror=",
        "<!entity",
    ]

    private static let forbiddenHostPathSubstrings = ["file://", "/Users/", "\\Users\\"]

    /// Verifies promoted Markdown/logo/preview files, non-destructive `reasoning/` preservation, brand tokens, SVG hygiene, and relative link confinement (`P1`, `N1`, `N2`).
    func verifyDocumentationAndAssets() -> [VerificationIssue] {
        let fm = FileManager.default
        let canonicalRoot = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let canonicalDocsDesign = rootURL.appendingPathComponent("docs/design")
            .resolvingSymlinksInPath().standardizedFileURL.path

        var issues: [VerificationIssue] = []
        issues.append(contentsOf: verifyRequiredPromotedFiles(using: fm))
        issues.append(contentsOf: verifyReasoningSourcePreservation(using: fm))
        issues.append(contentsOf: verifySvgSecurity())
        issues.append(contentsOf: verifyMasterLogoPng())
        issues.append(contentsOf: verifyBrandTokens())
        issues.append(contentsOf: Self.markdownFilesToCheck.flatMap {
            verifyMarkdownFile($0, fileManager: fm, canonicalRoot: canonicalRoot, canonicalDocsDesign: canonicalDocsDesign)
        })
        return issues
    }

    private func verifyRequiredPromotedFiles(using fm: FileManager) -> [VerificationIssue] {
        var issues: [VerificationIssue] = []
        for relPath in Self.requiredPromotedPaths {
            let fileURL = rootURL.appendingPathComponent(relPath)
            guard fm.fileExists(atPath: fileURL.path) else {
                issues.append(VerificationIssue(
                    severity: .integrity,
                    path: relPath,
                    message: "Required promoted design deliverable does not exist"
                ))
                continue
            }
            if let sizeIssue = PathConfinementGuard.validateFileSize(at: fileURL, reportedPath: relPath) {
                issues.append(sizeIssue)
            }
        }
        return issues
    }

    private func verifyReasoningSourcePreservation(using fm: FileManager) -> [VerificationIssue] {
        let reasoningDeliverables = rootURL.appendingPathComponent("reasoning/001_project-constitution/deliverables")
        guard fm.fileExists(atPath: reasoningDeliverables.path) else { return [] }
        let sourceChecks = [
            "reasoning/001_project-constitution/deliverables/color-schemes-and-zed-layout.md",
            "reasoning/001_project-constitution/deliverables/assets/app-icons-riepilogo.md",
            "reasoning/001_project-constitution/deliverables/assets/logo-e2-refined.svg",
        ]
        return sourceChecks
            .filter { !fm.fileExists(atPath: rootURL.appendingPathComponent($0).path) }
            .map {
                VerificationIssue(
                    severity: .integrity,
                    path: $0,
                    message: "Source deliverable in reasoning/ was removed instead of preserved via copy"
                )
            }
    }

    private func verifyMarkdownFile(
        _ mdRel: String,
        fileManager fm: FileManager,
        canonicalRoot: String,
        canonicalDocsDesign: String
    ) -> [VerificationIssue] {
        let mdURL = rootURL.appendingPathComponent(mdRel)
        guard fm.fileExists(atPath: mdURL.path),
              let text = try? String(contentsOf: mdURL, encoding: .utf8) else {
            return []
        }

        var issues: [VerificationIssue] = []
        if let hostLeak = verifyHostPathLeak(in: text, reportedPath: mdRel) {
            issues.append(hostLeak)
        }

        let baseDir = mdURL.deletingLastPathComponent()
        let confinementPrefix = mdRel.hasPrefix("docs/design/") ? canonicalDocsDesign : canonicalRoot
        let linkIssues = MarkdownLinkScanner.extractRelativeTargets(from: text).compactMap {
            validateRelativeMarkdownTarget(
                $0,
                mdRel: mdRel,
                baseDir: baseDir,
                confinementPrefix: confinementPrefix,
                fileManager: fm
            )
        }
        issues.append(contentsOf: linkIssues)
        return issues
    }

    private func verifyHostPathLeak(in text: String, reportedPath: String) -> VerificationIssue? {
        guard Self.forbiddenHostPathSubstrings.contains(where: { text.contains($0) }) else {
            return nil
        }
        return VerificationIssue(
            severity: .security,
            path: reportedPath,
            message: "Residual workstation file:// or /Users/ path detected (CWE-200)"
        )
    }

    private func validateRelativeMarkdownTarget(
        _ target: String,
        mdRel: String,
        baseDir: URL,
        confinementPrefix: String,
        fileManager fm: FileManager
    ) -> VerificationIssue? {
        if isTraversalOrAbsoluteTarget(target) {
            return VerificationIssue(
                severity: .security,
                path: mdRel,
                message: "Path traversal or non-relative URI '\(target)' rejected (CWE-22)"
            )
        }
        let candidateURL = baseDir.appendingPathComponent(target)
        guard fm.fileExists(atPath: candidateURL.path) else {
            return VerificationIssue(
                severity: .integrity,
                path: mdRel,
                message: "Broken relative Markdown link target '\(target)'"
            )
        }
        guard PathConfinementGuard.isConfined(candidateURL: candidateURL, withinCanonicalDirectory: confinementPrefix) else {
            return VerificationIssue(
                severity: .security,
                path: mdRel,
                message: "Link '\(target)' resolves outside confined boundary via symlink (CWE-22)"
            )
        }
        return nil
    }

    private func isTraversalOrAbsoluteTarget(_ target: String) -> Bool {
        target.hasPrefix("/") || target.hasPrefix("file:") || target.split(separator: "/").contains("..")
    }

    /// Scans `logo-e2-refined.svg` to reject embedded `<script>`, `<foreignObject>`, `javascript:` URIs, event handlers, and XML `<!ENTITY` declarations (`CWE-79`/`CWE-611`).
    private func verifySvgSecurity() -> [VerificationIssue] {
        let svgRel = "docs/design/assets/logo-e2-refined.svg"
        let svgURL = rootURL.appendingPathComponent(svgRel)
        guard let svgText = try? String(contentsOf: svgURL, encoding: .utf8) else {
            return []
        }
        let lower = svgText.lowercased()
        var issues: [VerificationIssue] = []
        for pattern in Self.forbiddenSvgPatterns where lower.contains(pattern) {
            issues.append(VerificationIssue(
                severity: .security,
                path: svgRel,
                message: "Forbidden active SVG construct '\(pattern)' detected (CWE-79/CWE-611)"
            ))
        }
        return issues
    }

    /// Validates that `logo-e2-refined-512.png` decodes to `512x512 px` with outer corner transparency preserved.
    private func verifyMasterLogoPng() -> [VerificationIssue] {
        let pngRel = "docs/design/assets/logo-e2-refined-512.png"
        let pngURL = rootURL.appendingPathComponent(pngRel)
        guard FileManager.default.fileExists(atPath: pngURL.path) else {
            return []
        }
        guard let header = PngHeaderInspector.inspect(url: pngURL) else {
            return [VerificationIssue(severity: .integrity, path: pngRel, message: "Unable to decode master PNG via ImageIO")]
        }
        var issues: [VerificationIssue] = []
        if header.width != 512 || header.height != 512 {
            issues.append(VerificationIssue(
                severity: .integrity,
                path: pngRel,
                message: "Expected 512x512 px master preview, got \(header.width)x\(header.height) px"
            ))
        }
        if !header.hasAlpha {
            issues.append(VerificationIssue(
                severity: .security,
                path: pngRel,
                message: "Master preview logo-e2-refined-512.png must retain outer corner alpha"
            ))
        }
        return issues
    }

    /// Verifies Concept E2 Purple hex anchors (`#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`), `#FFFFFF`/`#000000` canvas polarity, and `50%..300%` Zoom Mode tokens (`[UI-001..004]`).
    private func verifyBrandTokens() -> [VerificationIssue] {
        var issues: [VerificationIssue] = []
        let svgRel = "docs/design/assets/logo-e2-refined.svg"
        if let svgText = try? String(contentsOf: rootURL.appendingPathComponent(svgRel), encoding: .utf8) {
            let upper = svgText.uppercased()
            for token in Self.requiredSvgHexTokens where !upper.contains(token) {
                issues.append(VerificationIssue(
                    severity: .integrity,
                    path: svgRel,
                    message: "Missing Concept E2 brand hex token '\(token)'"
                ))
            }
        }
        let specRel = "docs/design/color-schemes-and-zed-layout.md"
        if let specText = try? String(contentsOf: rootURL.appendingPathComponent(specRel), encoding: .utf8) {
            let upper = specText.uppercased()
            for token in Self.requiredColorSpecTokens where !upper.contains(token) {
                issues.append(VerificationIssue(
                    severity: .integrity,
                    path: specRel,
                    message: "Missing required UI/Zoom token '\(token)'"
                ))
            }
        }
        return issues
    }

    private static let catalogSpecs: [AppIconCatalogSpec] = [
        AppIconCatalogSpec(
            relativeDir: "docs/design/assets/app-icons/macos/AppIcon.appiconset",
            expectedUniqueFilesCount: 10,
            requiredHasAlpha: true,
            slots: [16, 32, 128, 256, 512].flatMap { pt in
                [1, 2].map { IconSlotSpec(idiom: "mac", pointSize: pt, scaleFactor: $0) }
            }
        ),
        AppIconCatalogSpec(
            relativeDir: "docs/design/assets/app-icons/ios/AppIcon.appiconset",
            expectedUniqueFilesCount: 8,
            requiredHasAlpha: false,
            slots: [
                IconSlotSpec(idiom: "iphone", pointSize: 20, scaleFactor: 2),
                IconSlotSpec(idiom: "iphone", pointSize: 20, scaleFactor: 3),
                IconSlotSpec(idiom: "iphone", pointSize: 29, scaleFactor: 2),
                IconSlotSpec(idiom: "iphone", pointSize: 29, scaleFactor: 3),
                IconSlotSpec(idiom: "iphone", pointSize: 40, scaleFactor: 2),
                IconSlotSpec(idiom: "iphone", pointSize: 40, scaleFactor: 3),
                IconSlotSpec(idiom: "iphone", pointSize: 60, scaleFactor: 2),
                IconSlotSpec(idiom: "iphone", pointSize: 60, scaleFactor: 3),
                IconSlotSpec(idiom: "ios-marketing", pointSize: 1024, scaleFactor: 1),
            ]
        ),
    ]

    /// Validates both macOS (`10` PNGs `16..1024 px`, `hasAlpha == true`) and iOS (`9` slots / `8` PNGs `40..1024 px`, `hasAlpha == false` per App Store Connect `ITMS-90717`) `AppIcon.appiconset` catalogs (`P2`, `N3`, `N4`).
    func verifyAppIconCatalogs() -> [VerificationIssue] {
        Self.catalogSpecs.flatMap { verifySingleAppIconSet(spec: $0) }
    }

    /// Evaluates one `.appiconset` directory against slot completeness, `size * scale` pixel dimensions, platform alpha rules, symlink bans, and `16 MiB` caps.
    private func verifySingleAppIconSet(spec: AppIconCatalogSpec) -> [VerificationIssue] {
        let setURL = rootURL.appendingPathComponent(spec.relativeDir)
        let manifestRel = "\(spec.relativeDir)/Contents.json"
        let manifestURL = setURL.appendingPathComponent("Contents.json")

        guard let manifest = loadAppIconManifest(at: manifestURL) else {
            return [VerificationIssue(
                severity: .integrity,
                path: manifestRel,
                message: "Missing or malformed Contents.json manifest"
            )]
        }

        var issues: [VerificationIssue] = []
        if manifest.images.count != spec.slots.count {
            issues.append(VerificationIssue(
                severity: .integrity,
                path: manifestRel,
                message: "Expected \(spec.slots.count) icon slots, found \(manifest.images.count)"
            ))
        }

        let canonicalSetDir = setURL.resolvingSymlinksInPath().standardizedFileURL.path
        var uniqueFilenames = Set<String>()
        for expected in spec.slots {
            issues.append(contentsOf: validateAppIconSlot(
                expected,
                in: manifest,
                spec: spec,
                setURL: setURL,
                canonicalSetDir: canonicalSetDir,
                uniqueFilenames: &uniqueFilenames
            ))
        }

        if uniqueFilenames.count != spec.expectedUniqueFilesCount {
            issues.append(VerificationIssue(
                severity: .integrity,
                path: manifestRel,
                message: "Expected \(spec.expectedUniqueFilesCount) distinct PNG files, found \(uniqueFilenames.count)"
            ))
        }

        issues.append(contentsOf: verifyStrayAppIconEntries(
            in: setURL,
            relativeDir: spec.relativeDir,
            allowedFilenames: uniqueFilenames
        ))
        return issues
    }

    private func loadAppIconManifest(at manifestURL: URL) -> AppIconContentsManifest? {
        guard FileManager.default.fileExists(atPath: manifestURL.path),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(AppIconContentsManifest.self, from: data) else {
            return nil
        }
        return manifest
    }

    private func validateAppIconSlot(
        _ expected: IconSlotSpec,
        in manifest: AppIconContentsManifest,
        spec: AppIconCatalogSpec,
        setURL: URL,
        canonicalSetDir: String,
        uniqueFilenames: inout Set<String>
    ) -> [VerificationIssue] {
        let manifestRel = "\(spec.relativeDir)/Contents.json"
        guard let entry = manifest.images.first(where: {
            $0.idiom == expected.idiom && $0.size == expected.sizeString && $0.scale == expected.scaleString
        }), let filename = entry.filename, !filename.isEmpty else {
            return [VerificationIssue(
                severity: .integrity,
                path: manifestRel,
                message: "Missing required slot \(expected.idiom) \(expected.sizeString) @\(expected.scaleString)"
            )]
        }

        if filename.contains("/") || filename.contains("\\") || filename.contains("..") {
            return [VerificationIssue(
                severity: .security,
                path: manifestRel,
                message: "Icon filename '\(filename)' contains path separator or traversal segment (CWE-22)"
            )]
        }

        uniqueFilenames.insert(filename)
        let pngRel = "\(spec.relativeDir)/\(filename)"
        let pngURL = setURL.appendingPathComponent(filename)
        return validateAppIconFile(
            at: pngURL,
            pngRel: pngRel,
            expectedPixels: expected.expectedPixels,
            requiredHasAlpha: spec.requiredHasAlpha,
            canonicalSetDir: canonicalSetDir
        )
    }

    private func validateAppIconFile(
        at pngURL: URL,
        pngRel: String,
        expectedPixels: Int,
        requiredHasAlpha: Bool,
        canonicalSetDir: String
    ) -> [VerificationIssue] {
        if PathConfinementGuard.isSymbolicLink(at: pngURL) {
            return [VerificationIssue(
                severity: .security,
                path: pngRel,
                message: "Symbolic link inside AppIcon.appiconset is forbidden (CWE-22)"
            )]
        }
        guard FileManager.default.fileExists(atPath: pngURL.path) else {
            return [VerificationIssue(
                severity: .integrity,
                path: pngRel,
                message: "Referenced icon PNG file does not exist"
            )]
        }
        if !PathConfinementGuard.isConfined(candidateURL: pngURL, withinCanonicalDirectory: canonicalSetDir) {
            return [VerificationIssue(
                severity: .security,
                path: pngRel,
                message: "Icon path escapes AppIcon.appiconset boundary (CWE-22)"
            )]
        }
        if let sizeIssue = PathConfinementGuard.validateFileSize(at: pngURL, reportedPath: pngRel) {
            return [sizeIssue]
        }
        return validatePngRaster(
            at: pngURL,
            pngRel: pngRel,
            expectedPixels: expectedPixels,
            requiredHasAlpha: requiredHasAlpha
        )
    }

    private func validatePngRaster(
        at pngURL: URL,
        pngRel: String,
        expectedPixels: Int,
        requiredHasAlpha: Bool
    ) -> [VerificationIssue] {
        guard let header = PngHeaderInspector.inspect(url: pngURL) else {
            return [VerificationIssue(
                severity: .integrity,
                path: pngRel,
                message: "Unable to decode PNG header via ImageIO"
            )]
        }

        var issues: [VerificationIssue] = []
        if header.width != expectedPixels || header.height != expectedPixels {
            issues.append(VerificationIssue(
                severity: .integrity,
                path: pngRel,
                message: "Expected \(expectedPixels)x\(expectedPixels) px, got \(header.width)x\(header.height) px"
            ))
        }
        if header.hasAlpha != requiredHasAlpha {
            issues.append(VerificationIssue(
                severity: .security,
                path: pngRel,
                message: "Alpha channel mismatch: expected hasAlpha == \(requiredHasAlpha), got \(header.hasAlpha) (UI-001 / ITMS-90717)"
            ))
        }
        return issues
    }

    private func verifyStrayAppIconEntries(
        in setURL: URL,
        relativeDir: String,
        allowedFilenames: Set<String>
    ) -> [VerificationIssue] {
        guard let dirItems = try? FileManager.default.contentsOfDirectory(atPath: setURL.path) else {
            return []
        }
        let allowed = allowedFilenames.union(["Contents.json"])
        return dirItems
            .filter { !allowed.contains($0) }
            .map { item in
                let strayURL = setURL.appendingPathComponent(item)
                let severity: IssueSeverity = PathConfinementGuard.isSymbolicLink(at: strayURL) ? .security : .integrity
                return VerificationIssue(
                    severity: severity,
                    path: "\(relativeDir)/\(item)",
                    message: "Unexpected file or symbolic link inside AppIcon.appiconset"
                )
            }
    }

    /// Executes all documentation, link-confinement, SVG, and `AppIcon.appiconset` checks and aggregates them into a `VerificationReport`.
    func verifyAll(includeAppIcons: Bool = true) -> VerificationReport {
        var combined = verifyDocumentationAndAssets()
        if includeAppIcons {
            combined.append(contentsOf: verifyAppIconCatalogs())
        }
        return VerificationReport(issues: combined)
    }
}

// MARK: - Self-Test Harness (Linear AAA, Zero Branching Inside Tests)

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw TestFailure(description: "ASSERTION FAILED: \(message)")
    }
}

enum FixtureBuilder {
    static func makeTempWorkspace(name: String) throws -> URL {
        let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".tmp/test-results/verify-design-assets-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func populateValidDocsFixture(at root: URL) throws {
        let fm = FileManager.default
        let docsAssets = root.appendingPathComponent("docs/design/assets")
        let reasoningAssets = root.appendingPathComponent("reasoning/001_project-constitution/deliverables/assets")
        try fm.createDirectory(at: docsAssets, withIntermediateDirectories: true)
        try fm.createDirectory(at: reasoningAssets, withIntermediateDirectories: true)

        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
          <rect width="512" height="512" rx="96" fill="#0B0614"/>
          <path d="M56 96 H456 L256 460 Z" stroke="#A78BFA"/>
          <stop offset="0" stop-color="#C4B5FD"/><stop offset="1" stop-color="#7C3AED"/>
        </svg>
        """
        try svg.write(to: docsAssets.appendingPathComponent("logo-e2-refined.svg"), atomically: true, encoding: .utf8)
        try svg.write(to: reasoningAssets.appendingPathComponent("logo-e2-refined.svg"), atomically: true, encoding: .utf8)

        try writeSolidPNG(to: docsAssets.appendingPathComponent("logo-e2-refined-512.png"), width: 512, height: 512, hasAlpha: true)
        try writeSolidPNG(to: docsAssets.appendingPathComponent("preview-dark-black-purple.png"), width: 64, height: 64, hasAlpha: false)
        try writeSolidPNG(to: docsAssets.appendingPathComponent("preview-light-purple.png"), width: 64, height: 64, hasAlpha: false)
        try writeSolidPNG(to: docsAssets.appendingPathComponent("preview-file-compare-diff.png"), width: 64, height: 64, hasAlpha: false)

        let riepilogo = """
        # App Icons Summary
        - [SVG](logo-e2-refined.svg)
        - [PNG](logo-e2-refined-512.png)
        """
        try riepilogo.write(to: docsAssets.appendingPathComponent("app-icons-riepilogo.md"), atomically: true, encoding: .utf8)
        try riepilogo.write(to: reasoningAssets.appendingPathComponent("app-icons-riepilogo.md"), atomically: true, encoding: .utf8)

        let colorDoc = """
        # Color Schemes (#0B0614, #7C3AED, #A78BFA, #C4B5FD, #FFFFFF, #000000, Zoom 50%..300%)
        - [Icons](assets/app-icons-riepilogo.md)
        - [SVG](assets/logo-e2-refined.svg)
        - [Logo PNG](assets/logo-e2-refined-512.png)
        - [Dark](assets/preview-dark-black-purple.png)
        - [Light](assets/preview-light-purple.png)
        - [Diff](assets/preview-file-compare-diff.png)
        """
        try colorDoc.write(to: root.appendingPathComponent("docs/design/color-schemes-and-zed-layout.md"), atomically: true, encoding: .utf8)
        try colorDoc.write(to: root.appendingPathComponent("reasoning/001_project-constitution/deliverables/color-schemes-and-zed-layout.md"), atomically: true, encoding: .utf8)

        let readme = """
        # PH.SwiftEdit
        <img src="docs/design/assets/logo-e2-refined-512.png" alt="Logo" />
        - [Color Schemes](docs/design/color-schemes-and-zed-layout.md)
        - [App Icons](docs/design/assets/app-icons-riepilogo.md)
        """
        try readme.write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try populateValidAppIconsFixture(at: root)
    }

    static func populateValidAppIconsFixture(at root: URL) throws {
        let fm = FileManager.default
        let macDir = root.appendingPathComponent("docs/design/assets/app-icons/macos/AppIcon.appiconset")
        let iosDir = root.appendingPathComponent("docs/design/assets/app-icons/ios/AppIcon.appiconset")
        try fm.createDirectory(at: macDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: iosDir, withIntermediateDirectories: true)

        let macContents = """
        {
          "images" : [
            { "idiom" : "mac", "size" : "16x16", "scale" : "1x", "filename" : "icon_16x16.png" },
            { "idiom" : "mac", "size" : "16x16", "scale" : "2x", "filename" : "icon_16x16@2x.png" },
            { "idiom" : "mac", "size" : "32x32", "scale" : "1x", "filename" : "icon_32x32.png" },
            { "idiom" : "mac", "size" : "32x32", "scale" : "2x", "filename" : "icon_32x32@2x.png" },
            { "idiom" : "mac", "size" : "128x128", "scale" : "1x", "filename" : "icon_128x128.png" },
            { "idiom" : "mac", "size" : "128x128", "scale" : "2x", "filename" : "icon_128x128@2x.png" },
            { "idiom" : "mac", "size" : "256x256", "scale" : "1x", "filename" : "icon_256x256.png" },
            { "idiom" : "mac", "size" : "256x256", "scale" : "2x", "filename" : "icon_256x256@2x.png" },
            { "idiom" : "mac", "size" : "512x512", "scale" : "1x", "filename" : "icon_512x512.png" },
            { "idiom" : "mac", "size" : "512x512", "scale" : "2x", "filename" : "icon_512x512@2x.png" }
          ],
          "info" : { "version" : 1, "author" : "xcode" }
        }
        """
        try macContents.write(to: macDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
        let macFiles: [(String, Int)] = [
            ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
        ]
        for (name, px) in macFiles {
            try writeSolidPNG(to: macDir.appendingPathComponent(name), width: px, height: px, hasAlpha: true)
        }

        let iosContents = """
        {
          "images" : [
            { "idiom" : "iphone", "size" : "20x20", "scale" : "2x", "filename" : "AppIcon-40.png" },
            { "idiom" : "iphone", "size" : "20x20", "scale" : "3x", "filename" : "AppIcon-60.png" },
            { "idiom" : "iphone", "size" : "29x29", "scale" : "2x", "filename" : "AppIcon-58.png" },
            { "idiom" : "iphone", "size" : "29x29", "scale" : "3x", "filename" : "AppIcon-87.png" },
            { "idiom" : "iphone", "size" : "40x40", "scale" : "2x", "filename" : "AppIcon-80.png" },
            { "idiom" : "iphone", "size" : "40x40", "scale" : "3x", "filename" : "AppIcon-120.png" },
            { "idiom" : "iphone", "size" : "60x60", "scale" : "2x", "filename" : "AppIcon-120.png" },
            { "idiom" : "iphone", "size" : "60x60", "scale" : "3x", "filename" : "AppIcon-180.png" },
            { "idiom" : "ios-marketing", "size" : "1024x1024", "scale" : "1x", "filename" : "AppIcon-1024.png" }
          ],
          "info" : { "version" : 1, "author" : "xcode" }
        }
        """
        try iosContents.write(to: iosDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
        let iosFiles: [(String, Int)] = [
            ("AppIcon-40.png", 40), ("AppIcon-60.png", 60),
            ("AppIcon-58.png", 58), ("AppIcon-87.png", 87),
            ("AppIcon-80.png", 80), ("AppIcon-120.png", 120),
            ("AppIcon-180.png", 180), ("AppIcon-1024.png", 1024),
        ]
        for (name, px) in iosFiles {
            try writeSolidPNG(to: iosDir.appendingPathComponent(name), width: px, height: px, hasAlpha: false)
        }
    }

    static func writeSolidPNG(to url: URL, width: Int, height: Int, hasAlpha: Bool) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = hasAlpha
            ? CGImageAlphaInfo.premultipliedLast.rawValue
            : CGImageAlphaInfo.noneSkipLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let cgImage = ctx.makeImage(),
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw TestFailure(description: "Failed to synthesize PNG fixture at \(url.path)")
        }
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 1.0]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw TestFailure(description: "Failed to finalize PNG fixture at \(url.path)")
        }
    }
}

func testP1LiveWorkspacePromotedDocsAndLinksExist() throws {
    // GIVEN the live repository root
    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let verifier = DesignAssetsVerifier(rootURL: repoRoot)
    let promotedColorSpec = repoRoot.appendingPathComponent("docs/design/color-schemes-and-zed-layout.md")

    // WHEN verifying documentation and promoted assets
    let report = verifier.verifyAll()

    // THEN the promoted file exists and verification succeeds with exit code 0
    try expect(FileManager.default.fileExists(atPath: promotedColorSpec.path), "Expected docs/design/color-schemes-and-zed-layout.md to exist in workspace")
    try expect(report.exitCode == 0, "Expected exitCode 0 for P1, got \(report.exitCode): \(report.issues)")
}

func testN1MissingPromotedAssetIsRejected() throws {
    // GIVEN a fixture missing preview-file-compare-diff.png
    let root = try FixtureBuilder.makeTempWorkspace(name: "n1-missing-asset")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    try FileManager.default.removeItem(at: root.appendingPathComponent("docs/design/assets/preview-file-compare-diff.png"))

    // WHEN running documentation verification
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification fails with exitCode 1
    try expect(report.exitCode == 1, "Expected exitCode 1 when preview-file-compare-diff.png is missing, got \(report.exitCode)")
}

func testN1BrokenRelativeMarkdownLinkIsRejected() throws {
    // GIVEN a fixture with a broken relative link inside color-schemes-and-zed-layout.md
    let root = try FixtureBuilder.makeTempWorkspace(name: "n1-broken-link")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let colorDocURL = root.appendingPathComponent("docs/design/color-schemes-and-zed-layout.md")
    try "# Broken (#0B0614 #7C3AED #A78BFA #C4B5FD #FFFFFF #000000 50% 300%)\n[Missing](assets/non-existent-diagram.png)\n".write(to: colorDocURL, atomically: true, encoding: .utf8)

    // WHEN running documentation verification
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification fails with exitCode 1
    try expect(report.exitCode == 1, "Expected exitCode 1 on broken Markdown link, got \(report.exitCode)")
}

func testN2ParentTraversalLinkIsRejectedWithSecurityExitCode() throws {
    // GIVEN a fixture where color-schemes-and-zed-layout.md links via ../ outside docs/design/
    let root = try FixtureBuilder.makeTempWorkspace(name: "n2-traversal")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let colorDocURL = root.appendingPathComponent("docs/design/color-schemes-and-zed-layout.md")
    try "# Traversal (#0B0614 #7C3AED #A78BFA #C4B5FD #FFFFFF #000000 50% 300%)\n[Escape](../../README.md)\n".write(to: colorDocURL, atomically: true, encoding: .utf8)

    // WHEN running security verification
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification rejects the traversal with exitCode 2
    try expect(report.exitCode == 2, "Expected security exitCode 2 on ../ traversal, got \(report.exitCode)")
}

func testN2SymlinkEscapingDocsDesignIsRejected() throws {
    // GIVEN a fixture containing a symlink inside docs/design/assets pointing outside docs/design/
    let root = try FixtureBuilder.makeTempWorkspace(name: "n2-symlink")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let outsideTarget = root.appendingPathComponent("README.md")
    let symlinkURL = root.appendingPathComponent("docs/design/assets/escaped-link.md")
    try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideTarget)
    let colorDocURL = root.appendingPathComponent("docs/design/color-schemes-and-zed-layout.md")
    try "# Symlink (#0B0614 #7C3AED #A78BFA #C4B5FD #FFFFFF #000000 50% 300%)\n[Escape](assets/escaped-link.md)\n".write(to: colorDocURL, atomically: true, encoding: .utf8)

    // WHEN running security verification
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification rejects the symlink escape with exitCode 2
    try expect(report.exitCode == 2, "Expected security exitCode 2 on symlink escape, got \(report.exitCode)")
}

func testN2ResidualHostFileURIIsRejected() throws {
    // GIVEN a fixture containing a workstation file:///Users/ URI
    let root = try FixtureBuilder.makeTempWorkspace(name: "n2-host-uri")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let colorDocURL = root.appendingPathComponent("docs/design/color-schemes-and-zed-layout.md")
    try "# Leak (#0B0614 #7C3AED #A78BFA #C4B5FD #FFFFFF #000000 50% 300%)\n[Local](file:///Users/developer/secret.png)\n".write(to: colorDocURL, atomically: true, encoding: .utf8)

    // WHEN running security verification
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification rejects the host URI leak with exitCode 2
    try expect(report.exitCode == 2, "Expected security exitCode 2 on file:///Users/ leak, got \(report.exitCode)")
}

func testN2SvgEmbeddedScriptOrEntityIsRejected() throws {
    // GIVEN a fixture whose logo-e2-refined.svg embeds an active <script> element
    let root = try FixtureBuilder.makeTempWorkspace(name: "n2-svg-script")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let maliciousSvg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
      <rect fill="#0B0614"/><path stroke="#A78BFA"/><stop stop-color="#C4B5FD"/><stop stop-color="#7C3AED"/>
      <script>alert(1)</script>
    </svg>
    """
    try maliciousSvg.write(to: root.appendingPathComponent("docs/design/assets/logo-e2-refined.svg"), atomically: true, encoding: .utf8)

    // WHEN running security verification
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification rejects the active SVG payload with exitCode 2
    try expect(report.exitCode == 2, "Expected security exitCode 2 on SVG <script>, got \(report.exitCode)")
}

func testP2LiveWorkspaceAppIconCatalogsPassImageIO() throws {
    // GIVEN the live repository root with macOS and iOS AppIcon.appiconset catalogs
    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let macManifest = repoRoot.appendingPathComponent("docs/design/assets/app-icons/macos/AppIcon.appiconset/Contents.json")
    let iosManifest = repoRoot.appendingPathComponent("docs/design/assets/app-icons/ios/AppIcon.appiconset/Contents.json")

    // WHEN verifying AppIcon catalogs
    let report = DesignAssetsVerifier(rootURL: repoRoot).verifyAll()

    // THEN both manifests exist on disk and full verification exits 0
    try expect(FileManager.default.fileExists(atPath: macManifest.path), "Expected macos/AppIcon.appiconset/Contents.json to exist")
    try expect(FileManager.default.fileExists(atPath: iosManifest.path), "Expected ios/AppIcon.appiconset/Contents.json to exist")
    try expect(report.exitCode == 0, "Expected exitCode 0 for P2, got \(report.exitCode): \(report.issues)")
}

func testN3PixelDimensionMismatchInAppIconIsRejected() throws {
    // GIVEN a fixture where icon_512x512@2x.png is 512x512 instead of 1024x1024
    let root = try FixtureBuilder.makeTempWorkspace(name: "n3-dim-mismatch")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let wrongIcon = root.appendingPathComponent("docs/design/assets/app-icons/macos/AppIcon.appiconset/icon_512x512@2x.png")
    try FixtureBuilder.writeSolidPNG(to: wrongIcon, width: 512, height: 512, hasAlpha: true)

    // WHEN verifying AppIcon catalogs
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification rejects the dimension mismatch with exitCode 1
    try expect(report.exitCode == 1, "Expected exitCode 1 on 512x512@2x dimension mismatch, got \(report.exitCode)")
}

func testN3MissingSlotOrCorruptedContentsJsonIsRejected() throws {
    // GIVEN a fixture with corrupted JSON in ios/AppIcon.appiconset/Contents.json
    let root = try FixtureBuilder.makeTempWorkspace(name: "n3-bad-json")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let iosManifest = root.appendingPathComponent("docs/design/assets/app-icons/ios/AppIcon.appiconset/Contents.json")
    try "{ broken json".write(to: iosManifest, atomically: true, encoding: .utf8)

    // WHEN verifying AppIcon catalogs
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification rejects the malformed manifest with exitCode 1
    try expect(report.exitCode == 1, "Expected exitCode 1 on corrupted Contents.json, got \(report.exitCode)")
}

func testN4IOSIconWithAlphaChannelIsRejectedWithSecurityExitCode() throws {
    // GIVEN an iOS AppIcon-1024.png erroneously containing an alpha channel (ITMS-90717 violation)
    let root = try FixtureBuilder.makeTempWorkspace(name: "n4-ios-alpha")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let iosMarketing = root.appendingPathComponent("docs/design/assets/app-icons/ios/AppIcon.appiconset/AppIcon-1024.png")
    try FixtureBuilder.writeSolidPNG(to: iosMarketing, width: 1024, height: 1024, hasAlpha: true)

    // WHEN running security verification
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification rejects the transparent iOS icon with exitCode 2
    try expect(report.exitCode == 2, "Expected exitCode 2 on iOS icon with alpha channel, got \(report.exitCode)")
}

func testN4MacOSIconMissingAlphaChannelIsRejectedWithSecurityExitCode() throws {
    // GIVEN a macOS icon_512x512@2x.png missing its required outer alpha margin
    let root = try FixtureBuilder.makeTempWorkspace(name: "n4-mac-no-alpha")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let macMaster = root.appendingPathComponent("docs/design/assets/app-icons/macos/AppIcon.appiconset/icon_512x512@2x.png")
    try FixtureBuilder.writeSolidPNG(to: macMaster, width: 1024, height: 1024, hasAlpha: false)

    // WHEN running security verification
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification rejects the opaque macOS icon with exitCode 2
    try expect(report.exitCode == 2, "Expected exitCode 2 on macOS icon without alpha channel, got \(report.exitCode)")
}

func testN4AppIconSymlinkOrPathTraversalFilenameIsRejected() throws {
    // GIVEN a macOS AppIconset where icon_16x16.png is replaced by a symbolic link
    let root = try FixtureBuilder.makeTempWorkspace(name: "n4-icon-symlink")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let iconURL = root.appendingPathComponent("docs/design/assets/app-icons/macos/AppIcon.appiconset/icon_16x16.png")
    let targetURL = root.appendingPathComponent("docs/design/assets/logo-e2-refined-512.png")
    try FileManager.default.removeItem(at: iconURL)
    try FileManager.default.createSymbolicLink(at: iconURL, withDestinationURL: targetURL)

    // WHEN running security verification
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification rejects the symlink inside .appiconset with exitCode 2
    try expect(report.exitCode == 2, "Expected exitCode 2 on symlink inside AppIcon.appiconset, got \(report.exitCode)")
}

func testN4OversizedIconPayloadExceeding16MiBIsRejected() throws {
    // GIVEN a fixture where an AppIcon file exceeds the 16 MiB security cap
    let root = try FixtureBuilder.makeTempWorkspace(name: "n4-oversized")
    defer { try? FileManager.default.removeItem(at: root) }
    try FixtureBuilder.populateValidDocsFixture(at: root)
    let iconURL = root.appendingPathComponent("docs/design/assets/app-icons/ios/AppIcon.appiconset/AppIcon-40.png")
    let oversizedData = Data(count: Int(PathConfinementGuard.maxAssetBytes) + 1024)
    try oversizedData.write(to: iconURL)

    // WHEN running security verification
    let report = DesignAssetsVerifier(rootURL: root).verifyAll()

    // THEN verification rejects the oversized payload with exitCode 2
    try expect(report.exitCode == 2, "Expected exitCode 2 on >16 MiB icon payload, got \(report.exitCode)")
}

func runSelfTests(filter: String?) -> Int32 {
    let allTests: [(name: String, tag: String, fn: () throws -> Void)] = [
        ("P1 Live Workspace Promoted Docs & Links Exist", "positive", testP1LiveWorkspacePromotedDocsAndLinksExist),
        ("N1 Missing Promoted Asset Rejected", "negative", testN1MissingPromotedAssetIsRejected),
        ("N1 Broken Relative Markdown Link Rejected", "negative", testN1BrokenRelativeMarkdownLinkIsRejected),
        ("N2 Parent Traversal Link Rejected (CWE-22)", "security", testN2ParentTraversalLinkIsRejectedWithSecurityExitCode),
        ("N2 Symlink Escape Outside docs/design Rejected (CWE-22)", "security", testN2SymlinkEscapingDocsDesignIsRejected),
        ("N2 Residual Host file:///Users URI Rejected (CWE-200)", "security", testN2ResidualHostFileURIIsRejected),
        ("N2 SVG Active Script/Entity Rejected (CWE-79/CWE-611)", "security", testN2SvgEmbeddedScriptOrEntityIsRejected),
        ("P2 Live Workspace macOS & iOS AppIcon Catalogs Pass ImageIO", "positive", testP2LiveWorkspaceAppIconCatalogsPassImageIO),
        ("N3 AppIcon Pixel Dimension Mismatch Rejected", "negative", testN3PixelDimensionMismatchInAppIconIsRejected),
        ("N3 AppIcon Corrupted Contents.json Rejected", "negative", testN3MissingSlotOrCorruptedContentsJsonIsRejected),
        ("N4 iOS AppIcon With Alpha Channel Rejected (ITMS-90717)", "security", testN4IOSIconWithAlphaChannelIsRejectedWithSecurityExitCode),
        ("N4 macOS AppIcon Missing Alpha Channel Rejected", "security", testN4MacOSIconMissingAlphaChannelIsRejectedWithSecurityExitCode),
        ("N4 AppIcon Symlink/Traversal Entry Rejected (CWE-22)", "security", testN4AppIconSymlinkOrPathTraversalFilenameIsRejected),
        ("N4 Oversized >16 MiB AppIcon Payload Rejected (CWE-400)", "security", testN4OversizedIconPayloadExceeding16MiBIsRejected),
    ]
    let suite = filter == nil ? allTests : allTests.filter { $0.tag == filter }
    var failures = 0
    for entry in suite {
        do {
            try entry.fn()
            print("PASS: \(entry.name)")
        } catch {
            failures += 1
            fputs("FAIL: \(entry.name) -> \(error)\n", stderr)
        }
    }
    print("Self-test summary: \(suite.count - failures)/\(suite.count) passed")
    return failures == 0 ? 0 : 1
}

let args = CommandLine.arguments
if args.contains("--self-test") {
    var filterTag: String?
    if let fIdx = args.firstIndex(of: "--filter"), fIdx + 1 < args.count {
        filterTag = args[fIdx + 1]
    }
    exit(runSelfTests(filter: filterTag))
}

var rootPath = FileManager.default.currentDirectoryPath
if let idx = args.firstIndex(of: "--root"), idx + 1 < args.count {
    rootPath = args[idx + 1]
}
let report = DesignAssetsVerifier(rootURL: URL(fileURLWithPath: rootPath)).verifyAll()
for issue in report.issues {
    fputs("[\(issue.severity.rawValue)] \(issue.path): \(issue.message)\n", stderr)
}
exit(report.exitCode)
