import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("DocumentNavigatorWorkbenchTests")
@MainActor
struct DocumentNavigatorWorkbenchTests {

    private static func makeModel() -> (SwiftEditWorkbenchModel, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nav-\(UUID().uuidString)")
        let suite = "it.ph.SwiftEdit.test.nav.\(UUID().uuidString)"
        let model = SwiftEditWorkbenchModel(
            preferencesSuiteName: suite,
            recentFilesSuiteName: "\(suite).recent",
            recoveryDirectoryURL: dir,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        return (model, dir)
    }

    @Test("P1: toggle opens on a Markdown tab, confirm jumps and closes, ESC and second toggle close")
    func p1OpenJumpClose() {
        let (model, dir) = Self.makeModel()
        defer { try? FileManager.default.removeItem(at: dir) }
        model.handleEditorTextChanged("# One\ntext\n## Two\n")
        guard model.isMarkdownMenuEnabled else { Issue.record("default tab is not Markdown"); return }
        model.toggleDocumentNavigator()
        #expect(model.navigatorState?.filtered.count == 2)
        model.navigatorState?.moveDown()
        let token = model.programmaticSelectionToken
        model.confirmDocumentNavigator()
        #expect(model.navigatorState == nil)
        #expect(model.currentSelection.location == 11)
        #expect(model.programmaticSelectionToken == token + 1)
        model.toggleDocumentNavigator()
        #expect(model.handleEscape() == true)
        model.toggleDocumentNavigator()
        model.toggleDocumentNavigator()
        #expect(model.navigatorState == nil)
    }

    @Test("P1/P2/N1: distraction-free toggles full screen only on state change and resyncs on system exit")
    func distractionFree() {
        let (model, dir) = Self.makeModel()
        defer { try? FileManager.default.removeItem(at: dir) }
        var fullScreen = false
        model.windowFullScreenQuery = { fullScreen }
        model.windowFullScreenToggle = { fullScreen.toggle() }
        model.toggleDistractionFree()
        #expect(model.isDistractionFree && fullScreen)
        #expect(model.handleEscape() == true)
        #expect(!model.isDistractionFree && !fullScreen)
        #expect(model.handleEscape() == false)
        fullScreen = true
        model.toggleDistractionFree()
        model.toggleDistractionFree()
        #expect(!model.isDistractionFree && fullScreen)
        model.toggleDistractionFree()
        model.windowDidExitFullScreen()
        #expect(!model.isDistractionFree)
    }
}
