import Foundation
import Testing
@testable import SwiftEditUI

enum RepoRootLocator {
    static var rootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

@Suite("XcodeAppShellAndPackagingFitnessTests")
struct XcodeAppShellAndPackagingFitnessTests {

    @Test("P3: XcodeApp bundles Concept E2 macOS/iOS AppIcon.appiconset catalogs, least-privilege entitlements, and Info.plist stamped from version.json")
    func p3XcodeAppIconsEntitlementsAndNbgvInfoPlistStamping() throws {
        // GIVEN the repository root containing version.json and XcodeApp/ bundle resources
        let root = RepoRootLocator.rootURL
        let macIconsURL = root.appendingPathComponent("XcodeApp/Assets.xcassets/AppIcon.appiconset")
        let iosIconsURL = root.appendingPathComponent("XcodeApp/iOSAssets.xcassets/AppIcon.appiconset")
        let macEntitlementsURL = root.appendingPathComponent("XcodeApp/PH.SwiftEdit.macOS.entitlements")
        let iosEntitlementsURL = root.appendingPathComponent("XcodeApp/PH.SwiftEdit.iOS.entitlements")
        let infoPlistURL = root.appendingPathComponent("XcodeApp/Info.plist")
        let versionJsonURL = root.appendingPathComponent("version.json")

        // WHEN validating AppIcon catalogs, entitlements plists, and Info.plist version stamping
        let macIconsValid = try EntitlementsFitnessValidator.verifyAppIconCatalog(at: macIconsURL, expectedPNGCount: 10)
        let iosIconsValid = try EntitlementsFitnessValidator.verifyAppIconCatalog(at: iosIconsURL, expectedPNGCount: 8)
        let macViolations = try EntitlementsFitnessValidator.validate(plistData: Data(contentsOf: macEntitlementsURL), platform: .macOS)
        let iosViolations = try EntitlementsFitnessValidator.validate(plistData: Data(contentsOf: iosEntitlementsURL), platform: .iOS)
        let versionDescriptor = try InfoPlistVersionStamper.parseVersionDescriptor(from: Data(contentsOf: versionJsonURL))
        let stampedPlistData = try InfoPlistVersionStamper.stampInfoPlist(plistData: Data(contentsOf: infoPlistURL), descriptor: versionDescriptor)
        let repoInfoPlistVersions = try InfoPlistVersionStamper.readStampedVersions(from: Data(contentsOf: infoPlistURL))
        let stampedVersions = try InfoPlistVersionStamper.readStampedVersions(from: stampedPlistData)

        // THEN all AppIcon slots exist, both entitlements have zero violations, and Info.plist matches version.json (0.0.1 / 0.0.1-alpha1)
        #expect(macIconsValid == true)
        #expect(iosIconsValid == true)
        #expect(macViolations.isEmpty)
        #expect(iosViolations.isEmpty)
        #expect(versionDescriptor == VersionStampDescriptor(shortVersionString: "0.0.1", fullBuildVersionString: "0.0.1-alpha1"))
        #expect(repoInfoPlistVersions == versionDescriptor)
        #expect(stampedVersions == versionDescriptor)
    }

    @Test("N5: InfoPlistVersionStamper throws invalidVersionManifest or invalidPlistPayload on malformed inputs")
    func n5MalformedVersionManifestOrInfoPlistFailsClosed() {
        // GIVEN malformed version.json and malformed Info.plist data
        let missingVersionJSON = Data(#"{"cloudBuild":true}"#.utf8)
        let brokenPlist = Data("not-a-plist".utf8)
        let validDescriptor = VersionStampDescriptor(shortVersionString: "0.0.1", fullBuildVersionString: "0.0.1-alpha1")

        // WHEN / THEN parsing or stamping fails closed with PackagingFitnessError
        #expect(throws: PackagingFitnessError.invalidVersionManifest) {
            _ = try InfoPlistVersionStamper.parseVersionDescriptor(from: missingVersionJSON)
        }
        #expect(throws: PackagingFitnessError.invalidPlistPayload) {
            _ = try InfoPlistVersionStamper.stampInfoPlist(plistData: brokenPlist, descriptor: validDescriptor)
        }
    }

    @Test("N6 [Security]: EntitlementsFitnessValidator rejects missing app-sandbox and forbidden network, files.all, temporary-exception, and library-validation keys")
    func n6SecurityEntitlementsValidatorRejectsUnsandboxedNetworkAndFilesAllKeys() throws {
        // GIVEN an over-privileged entitlements plist violating SEC-001, SEC-004, and SEC-008
        let rogueDict: [String: Any] = [
            "com.apple.security.app-sandbox": false,
            "com.apple.security.network.client": true,
            "com.apple.security.network.server": true,
            "com.apple.security.files.all": true,
            "com.apple.security.temporary-exception.files.absolute-path.read-write": ["/"],
            "com.apple.security.cs.disable-library-validation": true,
        ]
        let roguePlistData = try PropertyListSerialization.data(fromPropertyList: rogueDict, format: .xml, options: 0)

        // WHEN validating the plist
        let violations = try EntitlementsFitnessValidator.validate(plistData: roguePlistData, platform: .macOS)

        // THEN all six security violations are reported in deterministic key order
        #expect(violations.map(\.key) == [
            "com.apple.security.app-sandbox",
            "com.apple.security.cs.disable-library-validation",
            "com.apple.security.files.all",
            "com.apple.security.network.client",
            "com.apple.security.network.server",
            "com.apple.security.temporary-exception.files.absolute-path.read-write",
        ])
    }
}
