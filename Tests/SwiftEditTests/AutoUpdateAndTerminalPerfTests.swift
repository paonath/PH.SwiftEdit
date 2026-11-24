import AppKit
import CryptoKit
import Darwin
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("AutoUpdateAndTerminalPerfTests", .serialized)
@MainActor
struct AutoUpdateAndTerminalPerfTests {

    @Test("P-UPD1: shouldStripQuarantineAfterUpdate preserves quarantine-free status and detects quarantined bundles")
    func pQuarantineDetectionAndPreservation() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-quarantine-test-\(UUID().uuidString)", isDirectory: true)
        let cleanApp = dir.appendingPathComponent("Clean.app", isDirectory: true)
        let quarantinedApp = dir.appendingPathComponent("Quarantined.app", isDirectory: true)
        try FileManager.default.createDirectory(at: cleanApp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: quarantinedApp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Ensure cleanApp has no quarantine attribute
        _ = removexattr(cleanApp.path, "com.apple.quarantine", XATTR_NOFOLLOW)
        #expect(!AppUpdateInstaller.hasQuarantineAttribute(at: cleanApp))
        #expect(AppUpdateInstaller.shouldStripQuarantineAfterUpdate(existingAppURL: cleanApp) == true)

        // Add quarantine attribute to quarantinedApp
        let qVal = "0081;65f00000;Safari;00000000-0000-0000-0000-000000000000"
        _ = qVal.withCString { ptr in
            setxattr(quarantinedApp.path, "com.apple.quarantine", ptr, strlen(ptr), 0, XATTR_NOFOLLOW)
        }
        #expect(AppUpdateInstaller.hasQuarantineAttribute(at: quarantinedApp))
        #expect(AppUpdateInstaller.shouldStripQuarantineAfterUpdate(existingAppURL: quarantinedApp) == false)
    }

    @Test("P-UPD2: verifySHA256 validates matching checksums and rejects tampered or malformed checksums")
    func pSHA256Verification() {
        let payload = Data("SwiftEdit release payload".utf8)
        let digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        let checksumLine = "\(digest)  PH.SwiftEdit-v0.1.4-macOS-arm64.zip\n"

        #expect(AppUpdateInstaller.verifySHA256(data: payload, checksumText: checksumLine) == true)
        #expect(AppUpdateInstaller.verifySHA256(data: Data("tampered".utf8), checksumText: checksumLine) == false)
        #expect(AppUpdateInstaller.verifySHA256(data: payload, checksumText: "not-a-valid-hash") == false)
    }

    @Test("P-UPD3: postExitSwapScript atomically swaps bundle and strips quarantine when requested")
    func pPostExitSwapScriptSwapsAndStripsQuarantine() throws {
        let workdir = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-swap-test-\(UUID().uuidString)", isDirectory: true)
        let destParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-dest-test-\(UUID().uuidString)", isDirectory: true)
        let srcApp = workdir.appendingPathComponent("SwiftEdit.app", isDirectory: true)
        let destApp = destParent.appendingPathComponent("SwiftEdit.app", isDirectory: true)
        try FileManager.default.createDirectory(at: srcApp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destApp, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: workdir)
            try? FileManager.default.removeItem(at: destParent)
        }

        try Data("v2".utf8).write(to: srcApp.appendingPathComponent("version.txt"))
        try Data("v1".utf8).write(to: destApp.appendingPathComponent("version.txt"))

        // Quarantine the newly downloaded srcApp to simulate a browser/curl download
        let qVal = "0081;65f00000;curl;00000000-0000-0000-0000-000000000000"
        _ = qVal.withCString { ptr in
            setxattr(srcApp.path, "com.apple.quarantine", ptr, strlen(ptr), 0, XATTR_NOFOLLOW)
        }
        #expect(AppUpdateInstaller.hasQuarantineAttribute(at: srcApp))

        // Run postExitSwapScript with a non-existent PID (999999), stripQuarantine=1, relaunch=0
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = [
            "-c",
            AppUpdateInstaller.postExitSwapScript,
            "swiftedit-updater-test",
            "999999",
            srcApp.path,
            destApp.path,
            "1",
            "0",
            workdir.path,
        ]
        try proc.run()
        proc.waitUntilExit()

        #expect(proc.terminationStatus == 0)
        let installedVersion = try String(contentsOf: destApp.appendingPathComponent("version.txt"), encoding: .utf8)
        #expect(installedVersion == "v2")
        #expect(!AppUpdateInstaller.hasQuarantineAttribute(at: destApp))
        #expect(!FileManager.default.fileExists(atPath: workdir.path))
    }

    @Test("P-TERM-RESIZE1: terminalPanelHeight clamps cleanly between min and dynamic maxAvailableHeight")
    func pTerminalPanelHeightClamping() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("term-h-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        #expect(model.terminalPanelHeight == 240)
        model.setTerminalPanelHeight(420, maxAvailableHeight: 600)
        #expect(model.terminalPanelHeight == 420)
        model.setTerminalPanelHeight(50, maxAvailableHeight: 600)
        #expect(model.terminalPanelHeight == SwiftEditWorkbenchModel.minTerminalPanelHeight)
        model.setTerminalPanelHeight(999, maxAvailableHeight: 500)
        #expect(model.terminalPanelHeight == 500)
    }

    @Test("P-TERM-METAL1: SwiftEditTerminalView activates GPU Metal rendering when attached to an NSWindow")
    func pTerminalActivatesMetalOnWindowAttach() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 320),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        let termView = SwiftEditTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 320))
        window.contentView?.addSubview(termView)
        if MTLCreateSystemDefaultDevice() != nil {
            #expect(termView.isMetalActive == true)
        }
        termView.removeFromSuperview()
    }

    @Test("P7-UPD: checkForUpdates and performUpdateCheck delegate to GitHubReleaseUpdateChecker.evaluateReleaseUpdate without mutual recursion")
    func p7UpdateCheckerDisambiguatedFromWorkbenchCommand() async throws {
        // GIVEN a stubbed GitHub release response and a workbench model wired to that checker
        struct LocalStubFetcher: HTTPDataFetching {
            let payload: Data
            func fetch(request: URLRequest) async throws -> (Data, Int) {
                (payload, 200)
            }
        }
        let releaseJSON = Data("""
        {
          "tag_name": "v0.2.0",
          "html_url": "https://github.com/paonath/PH.SwiftEdit/releases/tag/v0.2.0",
          "draft": false
        }
        """.utf8)
        let checker = GitHubReleaseUpdateChecker(fetcher: LocalStubFetcher(payload: releaseJSON))
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let checkerSource = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/SwiftEditUI/Updates/GitHubReleaseUpdateChecker.swift"),
            encoding: .utf8
        )
        let workbenchUpdateSource = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+TerminalLogAndUpdates.swift"),
            encoding: .utf8
        )

        // WHEN evaluating release updates via the disambiguated API
        let outcome = await checker.evaluateReleaseUpdate(currentVersion: "0.1.0")

        // THEN evaluateReleaseUpdate returns updateAvailable and checkForUpdates(currentVersion:) is absent from GitHubReleaseUpdateChecker
        #expect(outcome == .updateAvailable(
            currentVersion: "0.1.0",
            latestVersion: "0.2.0",
            releaseURL: URL(string: "https://github.com/paonath/PH.SwiftEdit/releases/tag/v0.2.0")!,
            downloadURL: nil
        ))
        #expect(!checkerSource.contains("func checkForUpdates(currentVersion:"))
        #expect(workbenchUpdateSource.contains(".evaluateReleaseUpdate(currentVersion:"))
    }
}
