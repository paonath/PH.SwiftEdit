#if os(macOS)
import AppKit
import CryptoKit
import Darwin
import Foundation

/// Typed errors emitted during verified in-app macOS update installation (`SEC-001`, `SEC-004`).
public enum AppUpdateInstallError: Error, Equatable, Sendable {
    case unverifiedDownloadURL
    case downloadFailed(statusCode: Int)
    case checksumMismatch
    case extractionFailed(String)
    case missingAppBundleInArchive
    case nonAppBundleHost
    case destinationNotWritable(String)
    case archiveTooLarge(Int)
    case helperLaunchFailed(String)
}

/// Dedicated ephemeral download fetcher with a 5-minute resource timeout for `.zip` release archives (`SEC-001`).
public struct URLSessionUpdateDownloadFetcher: HTTPDataFetching {
    public init() {}

    public func fetch(request: URLRequest) async throws -> (Data, Int) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http.statusCode)
    }
}

/// Downloads, SHA-256 verifies, stages, and swaps an updated `SwiftEdit.app` bundle on macOS:
/// 1. Verifies the download URL is an allowlisted GitHub HTTPS `.zip` asset.
/// 2. Downloads the archive and companion `.sha256` checksum and verifies SHA-256 with `CryptoKit`.
/// 3. Inspects `com.apple.quarantine` on the installed app BEFORE updating: if the app had NO quarantine,
///    the post-exit helper automatically strips `com.apple.quarantine` from the updated bundle (`xattr -dr`).
/// 4. Launches a detached positional-argument swap helper (zero shell interpolation, `CWE-78`) that waits for
///    the running app to exit, swaps the bundle atomically with rollback on error, strips quarantine if needed,
///    and runs `open <app>` to relaunch the updated SwiftEdit automatically.
public struct AppUpdateInstaller: Sendable {
    public static let maxArchiveBytes = 256 * 1024 * 1024
    private let fetcher: any HTTPDataFetching

    public init(fetcher: any HTTPDataFetching = URLSessionUpdateDownloadFetcher()) {
        self.fetcher = fetcher
    }

    /// Returns `true` when `appURL` currently carries the `com.apple.quarantine` extended attribute.
    public static func hasQuarantineAttribute(at appURL: URL) -> Bool {
        let path = appURL.standardizedFileURL.path
        return getxattr(path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW) >= 0
    }

    /// Returns `true` when `existingAppURL` is an existing `.app` bundle that did NOT have `com.apple.quarantine`
    /// before updating, meaning the updated bundle must also remain quarantine-free.
    public static func shouldStripQuarantineAfterUpdate(existingAppURL: URL) -> Bool {
        guard existingAppURL.pathExtension.lowercased() == "app",
              FileManager.default.fileExists(atPath: existingAppURL.path) else {
            return false
        }
        return !hasQuarantineAttribute(at: existingAppURL)
    }

    private static let hexDigits: [UInt8] = Array("0123456789abcdef".utf8)

    /// Computes lowercase hex SHA-256 of `data` and compares it against a `shasum -a 256` text payload.
    public static func verifySHA256(data: Data, checksumText: String) -> Bool {
        guard let expectedHex = checksumText
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map({ String($0).lowercased() }),
              expectedHex.count == 64,
              expectedHex.allSatisfy({ $0.isHexDigit }) else {
            return false
        }
        let digest = SHA256.hash(data: data)
        var hexBytes = [UInt8]()
        hexBytes.reserveCapacity(64)
        for byte in digest {
            hexBytes.append(hexDigits[Int(byte >> 4)])
            hexBytes.append(hexDigits[Int(byte & 0x0F)])
        }
        return String(decoding: hexBytes, as: UTF8.self) == expectedHex
    }

    /// Positional-argument `/bin/sh` swap script (`$1=pid`, `$2=extractedApp`, `$3=destApp`, `$4=stripQuarantine(1|0)`, `$5=relaunch(1|0)`, `$6=workdir`).
    /// Uses strictly quoted positional parameters (zero string interpolation of paths, `CWE-78`).
    public static let postExitSwapScript: String = """
    set -eu
    PID="$1"
    SRC_APP="$2"
    DEST_APP="$3"
    STRIP_QUARANTINE="$4"
    RELAUNCH="$5"
    WORKDIR="$6"
    BACKUP_APP="${WORKDIR}/SwiftEdit.app.backup"

    WAITED=0
    while kill -0 "$PID" 2>/dev/null && [ "$WAITED" -lt 75 ]; do
        sleep 0.2
        WAITED=$((WAITED + 1))
    done
    if kill -0 "$PID" 2>/dev/null; then
        kill -TERM "$PID" 2>/dev/null || true
        sleep 0.5
    fi

    if [ -e "$DEST_APP" ]; then
        mv "$DEST_APP" "$BACKUP_APP"
    fi

    if ! /usr/bin/ditto "$SRC_APP" "$DEST_APP"; then
        if [ -e "$BACKUP_APP" ]; then
            mv "$BACKUP_APP" "$DEST_APP"
        fi
        rm -rf "$WORKDIR"
        exit 1
    fi

    if [ "$STRIP_QUARANTINE" = "1" ]; then
        /usr/bin/xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true
    fi

    rm -rf "$WORKDIR"

    if [ "$RELAUNCH" = "1" ]; then
        /usr/bin/open "$DEST_APP"
    fi
    """

    /// Downloads, verifies, extracts, and schedules atomic replacement + relaunch of `targetBundleURL`.
    /// Caller should invoke `NSApp.terminate(nil)` upon `.success` so the app closes gracefully and swaps.
    public func stageAndScheduleInstall(
        downloadURL: URL,
        targetBundleURL: URL = Bundle.main.bundleURL,
        runningPID: Int32 = ProcessInfo.processInfo.processIdentifier,
        relaunch: Bool = true
    ) async throws {
        guard let verifiedZipURL = GitHubReleaseUpdateChecker.verifiedGitHubHTTPSURL(downloadURL.absoluteString),
              verifiedZipURL.pathExtension.lowercased() == "zip" else {
            throw AppUpdateInstallError.unverifiedDownloadURL
        }
        guard targetBundleURL.pathExtension.lowercased() == "app" else {
            throw AppUpdateInstallError.nonAppBundleHost
        }
        let parentDir = targetBundleURL.deletingLastPathComponent().standardizedFileURL
        guard FileManager.default.isWritableFile(atPath: parentDir.path) else {
            throw AppUpdateInstallError.destinationNotWritable(parentDir.path)
        }
        guard let verifiedShaURL = GitHubReleaseUpdateChecker.verifiedGitHubHTTPSURL(verifiedZipURL.absoluteString + ".sha256") else {
            throw AppUpdateInstallError.unverifiedDownloadURL
        }

        let (zipData, zipStatus) = try await fetcher.fetch(request: Self.makeDownloadRequest(url: verifiedZipURL))
        guard zipStatus == 200 else { throw AppUpdateInstallError.downloadFailed(statusCode: zipStatus) }
        guard zipData.count <= Self.maxArchiveBytes else { throw AppUpdateInstallError.archiveTooLarge(zipData.count) }

        let (shaData, shaStatus) = try await fetcher.fetch(request: Self.makeDownloadRequest(url: verifiedShaURL))
        guard shaStatus == 200,
              let shaText = String(data: shaData, encoding: .utf8),
              Self.verifySHA256(data: zipData, checksumText: shaText) else {
            throw AppUpdateInstallError.checksumMismatch
        }

        let workdir = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-autoupdate-\(UUID().uuidString)", isDirectory: true)
        let extractedDir = workdir.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)

        let zipFileURL = workdir.appendingPathComponent("update.zip")
        do {
            try zipData.write(to: zipFileURL, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: workdir)
            throw error
        }

        // Run ditto off the cooperative async pool and drain stderr before waitUntilExit() to prevent 64 KiB pipe deadlock.
        let (exitCode, stderrData): (Int32, Data)
        do {
            (exitCode, stderrData) = try await Task.detached(priority: .utility) {
                let ditto = Process()
                ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                ditto.arguments = ["-x", "-k", zipFileURL.path, extractedDir.path]
                let stderrPipe = Pipe()
                ditto.standardError = stderrPipe
                try ditto.run()
                let errBytes = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                ditto.waitUntilExit()
                return (ditto.terminationStatus, errBytes)
            }.value
        } catch {
            try? FileManager.default.removeItem(at: workdir)
            throw error
        }

        guard exitCode == 0 else {
            let msg = String(data: stderrData, encoding: .utf8) ?? "ditto failed"
            try? FileManager.default.removeItem(at: workdir)
            throw AppUpdateInstallError.extractionFailed(msg)
        }

        let candidatePrimary = extractedDir.appendingPathComponent("SwiftEdit.app", isDirectory: true)
        let candidateLegacy = extractedDir.appendingPathComponent("PH.SwiftEdit.app", isDirectory: true)
        let extractedApp: URL
        if FileManager.default.fileExists(atPath: candidatePrimary.path) {
            extractedApp = candidatePrimary
        } else if FileManager.default.fileExists(atPath: candidateLegacy.path) {
            extractedApp = candidateLegacy
        } else {
            try? FileManager.default.removeItem(at: workdir)
            throw AppUpdateInstallError.missingAppBundleInArchive
        }

        let stripQuarantine = Self.shouldStripQuarantineAfterUpdate(existingAppURL: targetBundleURL)

        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = [
            "-c",
            Self.postExitSwapScript,
            "swiftedit-updater",
            String(runningPID),
            extractedApp.path,
            targetBundleURL.standardizedFileURL.path,
            stripQuarantine ? "1" : "0",
            relaunch ? "1" : "0",
            workdir.path,
        ]
        helper.standardInput = nil
        helper.standardOutput = nil
        helper.standardError = nil
        do {
            try helper.run()
        } catch {
            try? FileManager.default.removeItem(at: workdir)
            throw AppUpdateInstallError.helperLaunchFailed(error.localizedDescription)
        }
    }

    private static func makeDownloadRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("SwiftEdit", forHTTPHeaderField: "User-Agent")
        return request
    }
}
#endif
