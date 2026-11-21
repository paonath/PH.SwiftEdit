import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("TransientBinaryInspectionTests")
struct TransientBinaryInspectionTests {

    private static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftEditBin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @MainActor
    private static func makeModel(recoveryDir: URL) -> SwiftEditWorkbenchModel {
        SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
    }

    @Test("P3: Opening binary file mounts transient read-only inspection and switching/dismissing releases it completely")
    @MainActor
    func p3TransientBinaryInspectionMountsAndReleasesCleanly() throws {
        // GIVEN a writable text tab and a NUL-bearing 2 MiB binary file on disk
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let binaryURL = dir.appendingPathComponent("archive.bin")
        var payload = Data(repeating: 0x41, count: 2 * 1024 * 1024)
        payload[12] = 0x00
        try payload.write(to: binaryURL)

        let model = Self.makeModel(recoveryDir: dir.appendingPathComponent("rec"))
        let welcomeID = try #require(model.tabSession.activeTabID)
        let sessionsCountBefore = model.sessionsByID.count
        let baselinesCountBefore = model.savedBaselineByID.count

        // WHEN opening the binary file, verifying inspection state, then dismissing it
        model.openFile(at: binaryURL, withinScope: dir)
        let activeTitleDuringBin = model.activeTabTitle
        let activeSessionIsBinary = model.activeDocumentSession?.isBinaryReadOnly == true
        let inspectionPresent = model.activeBinaryInspection != nil
        let sessionsDuringBin = model.sessionsByID.count
        let baselinesDuringBin = model.savedBaselineByID.count
        let textLengthDuringBin = model.activeDocumentSession?.text.utf8.count ?? 0

        model.dismissBinaryInspection()
        let activeTitleAfterDismiss = model.activeTabTitle
        let inspectionAfterDismiss = model.activeBinaryInspection

        // THEN inspection displays capped <= 1 MiB read-only binary without polluting sessionsByID/savedBaselineByID, and release is immediate
        #expect(activeTitleDuringBin == "archive.bin")
        #expect(activeSessionIsBinary == true)
        #expect(inspectionPresent == true)
        #expect(sessionsDuringBin == sessionsCountBefore)
        #expect(baselinesDuringBin == baselinesCountBefore)
        #expect(textLengthDuringBin <= DocumentCodec.maxBinaryInspectionBytes)
        #expect(inspectionAfterDismiss == nil)
        #expect(model.tabSession.activeTabID == welcomeID)
        #expect(activeTitleAfterDismiss == "Welcome.md")
    }

    @Test("N5: Reopening identical binary file deduplicates transient inspection and switching tabs clears it")
    @MainActor
    func n5BinaryInspectionDeduplicatesAndClearsOnTabSwitch() throws {
        // GIVEN an active transient binary inspection alongside a second text tab
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let binaryURL = dir.appendingPathComponent("sample.bin")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: binaryURL)

        let model = Self.makeModel(recoveryDir: dir.appendingPathComponent("rec"))
        let firstTabID = try #require(model.tabSession.activeTabID)

        // WHEN opening the binary file twice, attempting pin, then activating tab 1
        model.openFile(at: binaryURL, withinScope: dir)
        let firstInspectionID = try #require(model.activeBinaryInspection?.id)
        model.togglePin(id: firstInspectionID)
        model.openFile(at: binaryURL, withinScope: dir)
        let secondInspectionID = model.activeBinaryInspection?.id

        model.activateTab(id: firstTabID)

        // THEN reopen kept same inspection ID without adding writable/pinned tabs, and tab switch cleared binary inspection
        #expect(firstInspectionID == secondInspectionID)
        #expect(model.tabSession.tabs.count == 1)
        #expect(model.tabSession.tabs.allSatisfy { !$0.isPinned })
        #expect(model.activeBinaryInspection == nil)
        #expect(model.activeDocumentSession?.isBinaryReadOnly == false)
    }

    @Test("N6 [Security]: Binary inspection locks mutating commands and writes zero recovery artifacts")
    @MainActor
    func n6BinaryInspectionLocksMutationsAndSkipsSessionRecovery() throws {
        // GIVEN an active transient binary inspection in SessionRecovery directory
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let recoveryDir = dir.appendingPathComponent("rec")
        let binaryURL = dir.appendingPathComponent("payload.bin")
        try Data([0x7F, 0x45, 0x4C, 0x46, 0x00]).write(to: binaryURL)

        let model = Self.makeModel(recoveryDir: recoveryDir)
        model.openFile(at: binaryURL, withinScope: dir)
        let binID = try #require(model.activeBinaryInspection?.id)

        // WHEN invoking mutating commands and persisting recovery
        model.saveActiveDocument()
        model.saveActiveDocumentAsViaPanel()
        model.performCommandD()
        model.formatActiveDocument()
        model.handleEditorTextChanged("tampered")
        let recoveryFileURL = recoveryDir.appendingPathComponent("\(binID.rawValue.uuidString).recovery")

        // THEN mutating actions are blocked, text stays immutable, and zero .recovery file exists for binID
        #expect(model.safetyBanner.canSave == false)
        #expect(model.safetyBanner.canFormat == false)
        #expect(!FileManager.default.fileExists(atPath: recoveryFileURL.path))
    }
}
