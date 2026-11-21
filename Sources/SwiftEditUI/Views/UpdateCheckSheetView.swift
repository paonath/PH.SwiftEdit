#if os(macOS)
import SwiftEditCore
import SwiftUI

/// Modal update status sheet presented from `SwiftEdit -> Check for Updates…` (`SEC-001`, `SEC-004`, `UI-001`).
public struct UpdateCheckSheetView: View {
    @Bindable var model: SwiftEditWorkbenchModel
    public let palette: PurpleThemePalette
    public let onClose: () -> Void

    public init(model: SwiftEditWorkbenchModel, palette: PurpleThemePalette, onClose: @escaping () -> Void) {
        self.model = model
        self.palette = palette
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 14) {
            SwiftEditBrandLogoView(size: CGFloat(SwiftEditBrandLogoGeometry.aboutDialogLogoSize * 0.65))
            Text("Software Update")
                .appFont(.title2, weight: .bold)
                .foregroundStyle(palette.chromeForeground.swiftUIColor)

            if model.isCheckingForUpdates {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking GitHub Releases for SwiftEdit…")
                        .appFont(.callout)
                        .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                }
            } else {
                outcomeBody
            }

            Button("Close") { onClose() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 440, height: 250)
        .purpleModalSheetChrome(palette: palette)
    }

    @ViewBuilder
    private var outcomeBody: some View {
        switch model.updateCheckOutcome {
        case .upToDate(let current):
            VStack(spacing: 6) {
                Text("SwiftEdit \(current) is up to date.")
                    .appFont(.headline)
                    .foregroundStyle(palette.chromeForeground.swiftUIColor)
                Text("You are running the latest available release.")
                    .appFont(.caption)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
            }
        case .noReleasesFound(let current):
            VStack(spacing: 6) {
                Text("SwiftEdit \(current) is up to date.")
                    .appFont(.headline)
                    .foregroundStyle(palette.chromeForeground.swiftUIColor)
                Text("No newer GitHub release was found for paonath/PH.SwiftEdit.")
                    .appFont(.caption)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
            }
        case .updateAvailable(let current, let latest, let releaseURL, let downloadURL):
            VStack(spacing: 10) {
                Text("Update Available: SwiftEdit \(latest)")
                    .appFont(.headline)
                    .foregroundStyle(palette.chromeForeground.swiftUIColor)
                Text("Installed version: \(current)")
                    .appFont(.caption, monospaced: true)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                HStack(spacing: 10) {
                    Button("Download Update…") {
                        model.openVerifiedUpdateURL(downloadURL ?? releaseURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.activeControlFill.swiftUIColor)

                    Button("Release Notes…") {
                        model.openVerifiedUpdateURL(releaseURL)
                    }
                    .buttonStyle(.bordered)
                    .tint(palette.chromeAccent.swiftUIColor)
                }
            }
        case .error(let message):
            VStack(spacing: 10) {
                Text(message)
                    .appFont(.callout)
                    .foregroundStyle(palette.bidiWarningForeground.swiftUIColor)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button("Retry") { model.checkForUpdates() }
                        .buttonStyle(.bordered)
                    Button("Open GitHub Releases…") {
                        model.openVerifiedUpdateURL(GitHubReleaseUpdateChecker.releasesPageURL)
                    }
                    .buttonStyle(.bordered)
                }
            }
        case .none:
            EmptyView()
        }
    }
}
#endif
