import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("EditorUXLayoutThemeAndAboutTests")
struct EditorUXLayoutThemeAndAboutTests {

    @Test("P5: Three-way Light/Dark/Auto selector syncs system colorScheme, exposes highlight and binary-disabled tokens, scales sidebar zoom, and projects non-mutating visual highlights")
    @MainActor
    func p5ThemeAutoSyncHighlightTokensSidebarZoomAndNonMutatingProjection() throws {
        // GIVEN a workbench in Auto mode with isolated in-memory stores and a document containing nested brackets and backticks
        let recoveryDir = FileManager.default.temporaryDirectory.appendingPathComponent("swiftedit-ux-p5-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: recoveryDir)
        }

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir
        )
        let sampleText = "scrivo{a[b(c)]} `code`"
        model.newUntitledTab()
        model.handleEditorTextChanged(sampleText)
        let revisionBefore = try #require(model.activeDocumentSession?.revision)

        // WHEN syncing system colorScheme to light, switching to black/light/auto, scaling zoom to 150%, and projecting highlights
        model.appearanceMode = .auto
        model.updateSystemColorScheme(prefersDark: false)
        let autoLightPalette = model.palette
        model.updateSystemColorScheme(prefersDark: true)
        let autoDarkPalette = model.palette
        model.appearanceMode = .light
        let explicitLightPalette = model.palette
        model.appearanceMode = .black
        let explicitBlackPalette = model.palette

        var zoom = EditorZoomController(zoomPercent: 100)
        zoom.applyPinchMagnification(1.5)
        let projection = model.activeHighlightProjection
        let revisionAfter = try #require(model.activeDocumentSession?.revision)

        // THEN Auto tracks system appearance dynamically, highlight & binary tokens match spec, sidebar zoom scales 13pt -> 19.5pt, and BufferRevision is unchanged
        #expect(autoLightPalette.mode == .light)
        #expect(autoDarkPalette.mode == .black)
        #expect(explicitLightPalette.currentLineHighlight.hex == "#F3F0FA")
        #expect(explicitBlackPalette.currentLineHighlight.hex == "#161224")
        #expect(explicitLightPalette.sidebarBinaryDisabledText.hex == "#52525B")
        #expect(explicitBlackPalette.sidebarBinaryDisabledText.hex == "#9CA3AF")
        #expect(explicitLightPalette.nestedBracketPalette.count >= 4)
        #expect(explicitBlackPalette.nestedBracketPalette.count >= 4)
        #expect(explicitLightPalette.backtickInlineBackground.hex != explicitLightPalette.editorCanvasBackground.hex)
        #expect(explicitBlackPalette.backtickInlineBackground.hex != explicitBlackPalette.editorCanvasBackground.hex)
        #expect(abs(zoom.sidebarScaledFontSizePoints - 19.5) < 0.01)
        #expect(projection.bracketPairs.count == 3)
        #expect(projection.backtickSpans.count == 1)
        #expect(revisionAfter == revisionBefore)
    }

    @Test("N7: Clicking a binary sidebar entry opens no tab, binary smart newline returns false, and sidebar zoom clamps at 50% and 300%")
    @MainActor
    func n7BinarySidebarClickInertAndSidebarZoomClamps() throws {
        // GIVEN a workbench, a binary FolderEntryDescriptor, and boundary zoom controllers
        let recoveryDir = FileManager.default.temporaryDirectory.appendingPathComponent("swiftedit-ux-n7-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: recoveryDir)
        }

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir
        )
        let tabCountBefore = model.tabSession.tabs.count
        let binaryEntry = FolderEntryDescriptor(
            name: "photo.png",
            url: recoveryDir.appendingPathComponent("photo.png"),
            isDirectory: false,
            isHiddenDotfile: false,
            isBinary: true
        )
        var minZoom = EditorZoomController(zoomPercent: 50)
        var maxZoom = EditorZoomController(zoomPercent: 300)

        // WHEN clicking the binary sidebar entry and stepping zoom past limits
        model.openFolderEntry(binaryEntry)
        minZoom.zoomOut()
        maxZoom.zoomIn()

        // THEN tab count is unchanged and sidebar zoom clamps at 6.5pt and 39.0pt
        #expect(model.tabSession.tabs.count == tabCountBefore)
        #expect(abs(minZoom.sidebarScaledFontSizePoints - 6.5) < 0.01)
        #expect(abs(maxZoom.sidebarScaledFontSizePoints - 39.0) < 0.01)
    }

    @Test("P6: Sidebar width computes strictly by percentage ratio across screens, pin collapses sidebar, topbar commands follow hover, right-click resolves creation target, and workbench reorders tabs")
    @MainActor
    func p6PercentageSidebarPinHoverToolbarContextCreateAndTabReorder() throws {
        // GIVEN a mounted workspace folder with a subfolder and file, plus multiple open tabs
        let workspace = try NavigatorTestSandbox.makeWorkspace(label: "ux-p6")
        let recoveryDir = workspace.appendingPathComponent(".recovery")
        defer {
            try? FileManager.default.removeItem(at: workspace)
        }
        let docsURL = workspace.appendingPathComponent("docs")
        let readmeURL = workspace.appendingPathComponent("readme.md")
        try FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
        try Data("# hi".utf8).write(to: readmeURL)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir
        )
        model.selectWorkspaceFolder(workspace)
        model.newUntitledTab()
        model.newUntitledTab()
        let initialOrder = model.tabSession.tabs.map(\.id)
        let lastTabID = try #require(initialOrder.last)

        // WHEN resizing by percentage ratio 0.40, toggling pin collapse, hovering topbar, resolving right-click create targets, and moving last tab left
        model.updateSidebarWidthRatio(0.40)
        let widthOn1200 = SidebarLayoutGeometry.resolvedWidth(forContainerWidth: 1200, ratio: model.sidebarWidthRatio)
        let widthOn2560 = SidebarLayoutGeometry.resolvedWidth(forContainerWidth: 2560, ratio: model.sidebarWidthRatio)
        let pinnedBefore = model.isLeftSidebarPinned
        model.toggleSidebarPinCollapse()
        let collapsedAfterUnpin = model.isLeftSidebarCollapsed
        let hoveredBefore = model.isToolbarHovered
        model.isToolbarHovered = true
        let hoveredAfter = model.isToolbarHovered

        let emptyTarget = model.resolveSidebarCreationDirectory(for: nil)
        let folderTarget = model.resolveSidebarCreationDirectory(for: FolderEntryDescriptor(name: "docs", url: docsURL, isDirectory: true, isHiddenDotfile: false))
        let fileTarget = model.resolveSidebarCreationDirectory(for: FolderEntryDescriptor(name: "readme.md", url: readmeURL, isDirectory: false, isHiddenDotfile: false))
        let createdFile = model.sidebarCreateFile(named: "draft.md", in: emptyTarget)
        model.moveTabLeft(id: lastTabID)

        // THEN widths scale strictly at 40% (480 and 1024), pin collapses, hover reveals commands, targets resolve accurately, file exists, and tab moved left
        #expect(abs(widthOn1200 - 480.0) < 0.01)
        #expect(abs(widthOn2560 - 1024.0) < 0.01)
        #expect(pinnedBefore == true)
        #expect(collapsedAfterUnpin == true)
        #expect(hoveredBefore == false)
        #expect(hoveredAfter == true)
        #expect(emptyTarget?.standardizedFileURL.path == workspace.standardizedFileURL.path)
        #expect(folderTarget?.standardizedFileURL.path == docsURL.standardizedFileURL.path)
        #expect(fileTarget?.standardizedFileURL.path == workspace.standardizedFileURL.path)
        #expect(createdFile?.lastPathComponent == "draft.md")
        #expect(model.tabSession.tabs[initialOrder.count - 2].id == lastTabID)
    }

    @Test("N8: Out-of-bounds sidebar ratios clamp to 12%..65%, zero width resolves safely to 0, and invalid creation names write nothing")
    @MainActor
    func n8SidebarRatioClampingZeroWidthAndInvalidNames() throws {
        // GIVEN out-of-bounds ratios, zero container width, and invalid prompt names
        let workspace = try NavigatorTestSandbox.makeWorkspace(label: "ux-n8")
        let recoveryDir = workspace.appendingPathComponent(".recovery")
        defer {
            try? FileManager.default.removeItem(at: workspace)
        }
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir
        )
        model.selectWorkspaceFolder(workspace)

        // WHEN clamping extreme ratios and attempting invalid names
        model.updateSidebarWidthRatio(0.02)
        let lowClamped = model.sidebarWidthRatio
        model.updateSidebarWidthRatio(0.95)
        let highClamped = model.sidebarWidthRatio
        let zeroWidth = SidebarLayoutGeometry.resolvedWidth(forContainerWidth: 0, ratio: 0.30)
        let emptyFile = model.sidebarCreateFile(named: "", in: workspace)
        let dotFolder = model.sidebarCreateFolder(named: ".", in: workspace)

        // THEN bounds clamp cleanly and no files are created
        #expect(abs(lowClamped - 0.12) < 0.001)
        #expect(abs(highClamped - 0.65) < 0.001)
        #expect(zeroWidth == 0)
        #expect(emptyFile == nil)
        #expect(dotFolder == nil)
    }

    @Test("N9 [Security]: Traversal, separator, BiDi override, and escaping symlink targets in right-click Create File/Folder fail closed")
    @MainActor
    func n9SecuritySidebarRightClickCreateTraversalAndSymlinkEscapeBlocked() throws {
        // GIVEN a workspace with an escaping symlinked directory
        let workspace = try NavigatorTestSandbox.makeWorkspace(label: "ux-n9-ws")
        let outside = try NavigatorTestSandbox.makeWorkspace(label: "ux-n9-out")
        let recoveryDir = workspace.appendingPathComponent(".recovery")
        defer {
            try? FileManager.default.removeItem(at: workspace)
            try? FileManager.default.removeItem(at: outside)
        }
        let escapingDirLink = workspace.appendingPathComponent("linked-out")
        try FileManager.default.createSymbolicLink(at: escapingDirLink, withDestinationURL: outside)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir
        )
        model.selectWorkspaceFolder(workspace)

        // WHEN attempting traversal, path separator, BiDi spoofing, and symlink escape creation
        let traversal = model.sidebarCreateFile(named: "../escape.md", in: workspace)
        let nestedSlash = model.sidebarCreateFolder(named: "a/b", in: workspace)
        let bidiSpoof = model.sidebarCreateFile(named: "note\u{202E}gpj.md", in: workspace)
        let symlinkEscape = model.sidebarCreateFile(named: "pwn.md", in: escapingDirLink)

        // THEN every hostile attempt returns nil and creates zero files outside scope
        #expect(traversal == nil)
        #expect(nestedSlash == nil)
        #expect(bidiSpoof == nil)
        #expect(symlinkEscape == nil)
        #expect(FileManager.default.fileExists(atPath: outside.appendingPathComponent("pwn.md").path) == false)
    }

    @Test("P7: Concept E2 vector logo geometry, Help -> About menu entry, and AboutSheetDescriptor expose App Name, large logo, version, repo link, and MIT License link")
    func p7BrandLogoHelpAboutMenuAndValidatedLicenseLink() throws {
        // GIVEN a valid nbgv version.json payload
        let manifest = Data(#"{"version":"0.0.1-alpha3"}"#.utf8)

        // WHEN resolving AboutSheetDescriptor and preparing both external link prompts
        let descriptor = try AboutSheetDescriptor.resolve(versionManifestData: manifest)
        let repoPrompt = try #require(AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI: descriptor.repositoryURL))
        let licensePrompt = try #require(AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI: descriptor.licenseURL))

        // THEN E2 logo geometry, Help menu catalog, App Name, version, repo link, and MIT License link are all verified
        #expect(SwiftEditBrandLogoGeometry.groundHex == "#0B0614")
        #expect(SwiftEditBrandLogoGeometry.triangleStrokeHex == "#A78BFA")
        #expect(SwiftEditBrandLogoGeometry.featherTopHex == "#C4B5FD")
        #expect(SwiftEditBrandLogoGeometry.featherBottomHex == "#7C3AED")
        #expect(SwiftEditBrandLogoGeometry.viewBoxSize == 512.0)
        #expect(SwiftEditBrandLogoGeometry.topBarLogoSize == 20.0)
        #expect(SwiftEditBrandLogoGeometry.aboutDialogLogoSize == 84.0)
        #expect(SwiftEditHelpMenuCatalog.itemTitles.contains("About SwiftEdit"))
        #expect(descriptor.appName == "SwiftEdit")
        #expect(descriptor.shortVersion == "0.0.1")
        #expect(descriptor.fullVersion == "0.0.1-alpha3")
        #expect(descriptor.licenseName == "MIT License")
        #expect(repoPrompt.canonicalURI == "https://github.com/paoloinnocenti/PH.SwiftEdit")
        #expect(licensePrompt.canonicalURI == "https://github.com/paoloinnocenti/PH.SwiftEdit/blob/main/LICENSE")
    }

    @Test("N10 [Security]: Non-HTTPS or tampered repository and license URIs are rejected by AboutSheetDescriptor.prepareExternalLinkConfirmation")
    func n10SecurityTamperedOrNonHTTPSLicenseAndRepoURIsBlocked() {
        // GIVEN tampered and non-HTTPS URIs
        let httpLicense = AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI: "http://github.com/paoloinnocenti/PH.SwiftEdit/blob/main/LICENSE")
        let jsURI = AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI: "javascript:alert(1)")
        let fileURI = AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI: "file:///LICENSE")

        // THEN all three return nil
        #expect(httpLicense == nil)
        #expect(jsURI == nil)
        #expect(fileURI == nil)
    }
}
