import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Immutable `About PH.SwiftEdit` metadata descriptor resolving `nbgv` bundle versions and guarding external repository links (`AR-014`, `SEC-004`, `UI-008`).
public struct AboutSheetDescriptor: Equatable, Sendable {
    public static let officialAppName = "PH.SwiftEdit"
    public static let officialRepositoryURL = "https://github.com/paoloinnocenti/PH.SwiftEdit"

    public let appName: String
    public let shortVersion: String
    public let fullVersion: String
    public let repositoryURL: String

    public init(appName: String, shortVersion: String, fullVersion: String, repositoryURL: String) {
        self.appName = appName
        self.shortVersion = shortVersion
        self.fullVersion = fullVersion
        self.repositoryURL = repositoryURL
    }

    /// Parses a `version.json` (`Nerdbank.GitVersioning`) payload via `InfoPlistVersionStamper` into an `AboutSheetDescriptor` (`AR-014`).
    public static func resolve(versionManifestData: Data) throws -> AboutSheetDescriptor {
        let stamp = try InfoPlistVersionStamper.parseVersionDescriptor(from: versionManifestData)
        return AboutSheetDescriptor(
            appName: officialAppName,
            shortVersion: stamp.shortVersionString,
            fullVersion: stamp.fullBuildVersionString,
            repositoryURL: officialRepositoryURL
        )
    }

    /// Resolves runtime bundle version strings from `Bundle.main` with deterministic fallback (`AR-014`).
    public static func resolveFromMainBundle() -> AboutSheetDescriptor {
        let short = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.1"
        let full = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0.0.1-alpha1"
        return AboutSheetDescriptor(
            appName: officialAppName,
            shortVersion: short,
            fullVersion: full,
            repositoryURL: officialRepositoryURL
        )
    }

    /// Validates an external repository or help link exclusively for `https` with a non-empty host (`SEC-004`, `UI-008`).
    public static func prepareRepositoryLinkConfirmation(rawURI: String) -> ExternalURIConfirmationPrompt? {
        guard let prompt = InspectionSafetyBannerState.prepareExternalURIConfirmation(rawURI: rawURI),
              prompt.scheme == "https" else {
            return nil
        }
        return prompt
    }
}

#if os(macOS)
/// Modal `About PH.SwiftEdit` sheet displaying version metadata and a user-confirmed GitHub link (`AR-014`, `SEC-004`).
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
            Image(systemName: "Highlighter")
                .font(.system(size: 38))
                .foregroundStyle(Color(.sRGB, red: palette.featherHighlight.red, green: palette.featherHighlight.green, blue: palette.featherHighlight.blue, opacity: 1.0))
            Text(descriptor.appName)
                .font(.title2.weight(.bold))
            Text("Version \(descriptor.fullVersion) (\(descriptor.shortVersion))")
                .font(.callout.monospaced())
            Text("Minimalist Sandboxed macOS Text & Markdown Editor")
                .font(.caption)
                .opacity(0.85)
            Button("GitHub: \(descriptor.repositoryURL)") {
                pendingLinkPrompt = AboutSheetDescriptor.prepareRepositoryLinkConfirmation(rawURI: descriptor.repositoryURL)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.sRGB, red: palette.primaryAccent.red, green: palette.primaryAccent.green, blue: palette.primaryAccent.blue, opacity: 1.0))
            Button("Close") { onClose() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 440, height: 260)
        .background(Color(.sRGB, red: palette.brandGround.red, green: palette.brandGround.green, blue: palette.brandGround.blue, opacity: 1.0))
        .foregroundStyle(Color(.sRGB, red: palette.chromeForeground.red, green: palette.chromeForeground.green, blue: palette.chromeForeground.blue, opacity: 1.0))
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
