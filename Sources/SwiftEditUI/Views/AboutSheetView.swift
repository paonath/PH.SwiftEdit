import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Immutable `About SwiftEdit` metadata descriptor resolving `nbgv` bundle versions and guarding external repository and license links (`AR-014`, `SEC-004`, `UI-008`).
public struct AboutSheetDescriptor: Equatable, Sendable {
    public static let officialAppName = "SwiftEdit"
    public static let officialRepositoryURL = "https://github.com/paoloinnocenti/PH.SwiftEdit"
    public static let officialLicenseName = "MIT License"
    public static let officialLicenseURL = "https://github.com/paoloinnocenti/PH.SwiftEdit/blob/main/LICENSE"

    public let appName: String
    public let shortVersion: String
    public let fullVersion: String
    public let repositoryURL: String
    public let licenseName: String
    public let licenseURL: String

    public init(
        appName: String,
        shortVersion: String,
        fullVersion: String,
        repositoryURL: String,
        licenseName: String = AboutSheetDescriptor.officialLicenseName,
        licenseURL: String = AboutSheetDescriptor.officialLicenseURL
    ) {
        self.appName = appName
        self.shortVersion = shortVersion
        self.fullVersion = fullVersion
        self.repositoryURL = repositoryURL
        self.licenseName = licenseName
        self.licenseURL = licenseURL
    }

    /// Parses a `version.json` (`Nerdbank.GitVersioning`) payload via `InfoPlistVersionStamper` into an `AboutSheetDescriptor` (`AR-014`).
    public static func resolve(versionManifestData: Data) throws -> AboutSheetDescriptor {
        let stamp = try InfoPlistVersionStamper.parseVersionDescriptor(from: versionManifestData)
        return AboutSheetDescriptor(
            appName: officialAppName,
            shortVersion: stamp.shortVersionString,
            fullVersion: stamp.fullBuildVersionString,
            repositoryURL: officialRepositoryURL,
            licenseName: officialLicenseName,
            licenseURL: officialLicenseURL
        )
    }

    /// Resolves runtime bundle version strings from `Bundle.main` with deterministic fallback (`AR-014`).
    public static func resolveFromMainBundle() -> AboutSheetDescriptor {
        let short = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.1"
        let full = resolveFallbackFullVersion(bundleFullVersion: Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
        return AboutSheetDescriptor(
            appName: officialAppName,
            shortVersion: short,
            fullVersion: full,
            repositoryURL: officialRepositoryURL,
            licenseName: officialLicenseName,
            licenseURL: officialLicenseURL
        )
    }

    /// Returns the runtime bundle full version string or the aligned `0.0.1-alpha5` fallback (`BUG-018`).
    public static func resolveFallbackFullVersion(bundleFullVersion: String?) -> String {
        bundleFullVersion ?? "0.0.1-alpha5"
    }

    /// Validates an external repository, license, or help link exclusively for `https` with a non-empty host (`SEC-004`, `UI-008`).
    public static func prepareExternalLinkConfirmation(rawURI: String) -> ExternalURIConfirmationPrompt? {
        guard let prompt = InspectionSafetyBannerState.prepareExternalURIConfirmation(rawURI: rawURI),
              prompt.scheme == "https" else {
            return nil
        }
        return prompt
    }

    /// Validates an external repository link exclusively for `https` with a non-empty host (`SEC-004`, `UI-008`).
    public static func prepareRepositoryLinkConfirmation(rawURI: String) -> ExternalURIConfirmationPrompt? {
        prepareExternalLinkConfirmation(rawURI: rawURI)
    }
}

#if os(macOS)
/// Modal `About PH.SwiftEdit` dialog displaying the app name, large Concept E2 brand logo, `nbgv` version, and user-confirmed GitHub repository and MIT License links (`AR-014`, `SEC-004`, `UI-001`).
public struct AboutSheetView: View {
    public let descriptor: AboutSheetDescriptor
    public let palette: PurpleThemePalette
    public let onClose: () -> Void
    @State private var pendingLinkPrompt: ExternalURIConfirmationPrompt?

    public init(descriptor: AboutSheetDescriptor, palette: PurpleThemePalette, onClose: @escaping () -> Void) {
        self.descriptor = descriptor
        self.palette = palette
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 14) {
            SwiftEditBrandLogoView(size: CGFloat(SwiftEditBrandLogoGeometry.aboutDialogLogoSize))
                .shadow(color: palette.chromeAccent.swiftUIColor.opacity(0.35), radius: 10)
            Text(descriptor.appName)
                .appFont(.title2, weight: .bold)
                .foregroundStyle(palette.chromeForeground.swiftUIColor)
            Text("Version \(descriptor.fullVersion) (\(descriptor.shortVersion))")
                .appFont(.callout, monospaced: true)
                .foregroundStyle(palette.secondaryForeground.swiftUIColor)
            Text("Minimalist Sandboxed macOS Text & Markdown Editor")
                .appFont(.caption)
                .foregroundStyle(palette.secondaryForeground.swiftUIColor)
            HStack(spacing: 10) {
                Button("Repository (GitHub)") {
                    pendingLinkPrompt = AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI: descriptor.repositoryURL)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.activeControlFill.swiftUIColor)

                Button("License (\(descriptor.licenseName))") {
                    pendingLinkPrompt = AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI: descriptor.licenseURL)
                }
                .buttonStyle(.bordered)
                .tint(palette.chromeAccent.swiftUIColor)
            }
            Button("Close") { onClose() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 460, height: 320)
        .purpleModalSheetChrome(palette: palette)
        .alert(
            "Open External Link?",
            isPresented: Binding(
                get: { pendingLinkPrompt != nil },
                set: { if !$0 { pendingLinkPrompt = nil } }
            )
        ) {
            Button("Open in Browser") {
                if let prompt = pendingLinkPrompt, let url = URL(string: prompt.canonicalURI) {
                    NSWorkspace.shared.open(url)
                }
                pendingLinkPrompt = nil
            }
            Button("Cancel", role: .cancel) { pendingLinkPrompt = nil }
        } message: {
            Text(pendingLinkPrompt?.canonicalURI ?? "")
        }
    }
}
#endif
