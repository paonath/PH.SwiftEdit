import Foundation

/// Typed errors raised during `XcodeApp/` bundle manifest, `AppIcon.appiconset`, or `nbgv` `Info.plist` validation (`AR-001`, `AR-014`).
public enum PackagingFitnessError: Error, Equatable, Sendable {
    case invalidVersionManifest
    case invalidPlistPayload
    case missingAppIconSlot(String)
}

/// Canonical bundle version pair extracted from `version.json` (`Nerdbank.GitVersioning`) (`AR-014`, `TEST-008`).
public struct VersionStampDescriptor: Equatable, Sendable {
    public let shortVersionString: String
    public let fullBuildVersionString: String

    public init(shortVersionString: String, fullBuildVersionString: String) {
        self.shortVersionString = shortVersionString
        self.fullBuildVersionString = fullBuildVersionString
    }
}

/// Single entitlement policy violation detected in a macOS or iOS `.entitlements` plist (`SEC-001`).
public struct EntitlementViolation: Equatable, Sendable {
    public let key: String
    public let reason: String

    public init(key: String, reason: String) {
        self.key = key
        self.reason = reason
    }
}

/// Audits `XcodeApp/` `.entitlements` manifests and `AppIcon.appiconset` asset catalogs (`AR-001`, `SEC-001`, `SEC-004`, `SEC-008`, `TEST-007`).
///
/// Security invariants:
/// - `com.apple.security.app-sandbox` MUST be explicitly `true` on both macOS and iOS (`SEC-001`).
/// - Only user-selected read-write and app-scoped bookmark keys are allowlisted on macOS; any network (`network.client`, `network.server`), `files.all`, `temporary-exception`, or library-validation-relaxation key is rejected fail-closed (`SEC-001`, `SEC-004`, `SEC-008`).
public enum EntitlementsFitnessValidator {
    public enum TargetPlatform: String, Sendable {
        case macOS
        case iOS
    }

    public static let allowedMacOSEntitlements: Set<String> = [
        "com.apple.security.app-sandbox",
        "com.apple.security.files.user-selected.read-write",
        "com.apple.security.files.bookmarks.app-scope",
    ]

    public static let allowedIOSEntitlements: Set<String> = [
        "com.apple.security.app-sandbox",
    ]

    /// Parses an XML or binary `.entitlements` plist and returns any security policy violations sorted by entitlement key.
    public static func validate(plistData: Data, platform: TargetPlatform) throws -> [EntitlementViolation] {
        guard let dict = (try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)) as? [String: Any] else {
            throw PackagingFitnessError.invalidPlistPayload
        }

        var violations: [EntitlementViolation] = []
        if (dict["com.apple.security.app-sandbox"] as? Bool) != true {
            violations.append(EntitlementViolation(
                key: "com.apple.security.app-sandbox",
                reason: "App Sandbox must be enabled (SEC-001)"
            ))
        }

        let allowedKeys = (platform == .macOS) ? allowedMacOSEntitlements : allowedIOSEntitlements
        for key in dict.keys where !allowedKeys.contains(key) {
            violations.append(EntitlementViolation(
                key: key,
                reason: "Forbidden entitlement key outside SEC-001 least-privilege allowlist"
            ))
        }

        return violations.sorted { $0.key < $1.key }
    }

    /// Verifies that `Contents.json` inside `appiconsetURL` exists and every referenced PNG slot resolves on disk with `expectedPNGCount` unique PNG files (`AR-001`, `UI-001`, `TEST-007`).
    public static func verifyAppIconCatalog(at appiconsetURL: URL, expectedPNGCount: Int) throws -> Bool {
        let contentsURL = appiconsetURL.appendingPathComponent("Contents.json")
        let rawData: Data
        do {
            rawData = try Data(contentsOf: contentsURL)
        } catch {
            throw PackagingFitnessError.missingAppIconSlot("Contents.json")
        }

        struct CatalogManifest: Decodable {
            struct Slot: Decodable {
                let filename: String?
            }
            let images: [Slot]
        }

        let manifest: CatalogManifest
        do {
            manifest = try JSONDecoder().decode(CatalogManifest.self, from: rawData)
        } catch {
            throw PackagingFitnessError.invalidPlistPayload
        }

        var uniquePNGs: Set<String> = []
        for slot in manifest.images {
            guard let filename = slot.filename, !filename.isEmpty else {
                throw PackagingFitnessError.missingAppIconSlot("<unassigned-slot>")
            }
            let fileURL = appiconsetURL.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw PackagingFitnessError.missingAppIconSlot(filename)
            }
            uniquePNGs.insert(filename)
        }

        return uniquePNGs.count == expectedPNGCount
    }
}

/// Deterministically stamps and validates `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` from `version.json` (`AR-014`, `TEST-008`).
public enum InfoPlistVersionStamper {
    private struct NbgvManifest: Decodable {
        let version: String
    }

    /// Parses `version.json` (`Nerdbank.GitVersioning`), extracting `shortVersionString` (`X.Y.Z`) and `fullBuildVersionString` (`X.Y.Z-prerelease`).
    public static func parseVersionDescriptor(from versionJsonData: Data) throws -> VersionStampDescriptor {
        let manifest: NbgvManifest
        do {
            manifest = try JSONDecoder().decode(NbgvManifest.self, from: versionJsonData)
        } catch {
            throw PackagingFitnessError.invalidVersionManifest
        }
        let trimmed = manifest.version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PackagingFitnessError.invalidVersionManifest
        }
        let shortPrefix = extractNumericSemVerPrefix(from: trimmed)
        guard !shortPrefix.isEmpty else {
            throw PackagingFitnessError.invalidVersionManifest
        }
        return VersionStampDescriptor(
            shortVersionString: shortPrefix,
            fullBuildVersionString: trimmed
        )
    }

    /// Returns a new XML `Info.plist` `Data` payload with `CFBundleShortVersionString` and `CFBundleVersion` stamped from `descriptor`.
    public static func stampInfoPlist(plistData: Data, descriptor: VersionStampDescriptor) throws -> Data {
        guard var plistDict = (try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)) as? [String: Any] else {
            throw PackagingFitnessError.invalidPlistPayload
        }
        plistDict["CFBundleShortVersionString"] = descriptor.shortVersionString
        plistDict["CFBundleVersion"] = descriptor.fullBuildVersionString
        do {
            return try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
        } catch {
            throw PackagingFitnessError.invalidPlistPayload
        }
    }

    /// Reads `CFBundleShortVersionString` and `CFBundleVersion` from an `Info.plist` payload.
    public static func readStampedVersions(from plistData: Data) throws -> VersionStampDescriptor {
        guard let plistDict = (try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)) as? [String: Any],
              let shortVersion = plistDict["CFBundleShortVersionString"] as? String,
              let fullVersion = plistDict["CFBundleVersion"] as? String else {
            throw PackagingFitnessError.invalidPlistPayload
        }
        return VersionStampDescriptor(
            shortVersionString: shortVersion,
            fullBuildVersionString: fullVersion
        )
    }

    private static func extractNumericSemVerPrefix(from rawVersion: String) -> String {
        let base = rawVersion.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
        return base.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
    }
}
