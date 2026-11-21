import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

private struct StubHTTPFetcher: HTTPDataFetching {
    let responses: [String: (Data, Int)]

    func fetch(request: URLRequest) async throws -> (Data, Int) {
        let key = request.url?.absoluteString ?? ""
        return responses[key] ?? (Data("{\"message\":\"Not Found\"}".utf8), 404)
    }
}

@MainActor
private final class SpyTerminalWorkspaceFake: DesktopWorkspaceIntegrating {
    private(set) var launchedBundles: [String?] = []
    private(set) var launchedDirectories: [URL] = []

    func revealInFinder(itemURL: URL, withinScope scopeURL: URL?) throws {
        try DesktopWorkspaceValidator.verifyItemConfinement(targetURL: itemURL, withinScope: scopeURL)
    }

    func openFolderInFinder(folderURL: URL, withinScope scopeURL: URL?) throws {
        try DesktopWorkspaceValidator.verifyDirectoryConfinement(folderURL: folderURL, withinScope: scopeURL)
    }

    func openInTerminal(
        targetURL: URL,
        withinScope scopeURL: URL?,
        explicitBundleIdentifier: String?
    ) throws -> TerminalLaunchResolution {
        let resolution = try DesktopWorkspaceValidator.resolveTerminalLaunch(
            targetURL: targetURL,
            withinScope: scopeURL,
            explicitBundleIdentifier: explicitBundleIdentifier,
            isITerm2Installed: true,
            isITerm2Preferred: true
        )
        launchedBundles.append(explicitBundleIdentifier)
        launchedDirectories.append(resolution.directoryURL)
        return resolution
    }
}

private struct DummyFamiliesSource: FontFamilySource {
    func familyNames() -> [String] { ["Avenir Next", "Menlo"] }
}

@Suite("SwiftEditBrandingSettingsUpdatesTests")
struct SwiftEditBrandingSettingsUpdatesTests {

    @Test("P1: TabTitleDeriver extracts first 4 space-separated words and preserves spaces")
    func p1UntitledTabTitleExtractsFirstFourWordsWithSpaces() {
        // GIVEN plain prose exceeding 4 words
        let source = "Hello world from SwiftEdit extra ignored words"

        // WHEN deriving the untitled tab title
        let derived = TabTitleDeriver.untitledTitle(from: source)

        // THEN exactly the first 4 words joined by spaces are returned
        #expect(derived == "Hello world from SwiftEdit")
    }

    @Test("P2: TabTitleDeriver strips leading Markdown heading, list, task, and blockquote markers")
    func p2UntitledTabTitleStripsMarkdownMarkers() {
        // GIVEN Markdown inputs with headings, checkboxes, ordered lists, and quotes
        let heading = TabTitleDeriver.untitledTitle(from: "## My Project Notes for Today")
        let checklist = TabTitleDeriver.untitledTitle(from: "- [x] Finish release checklist immediately")
        let ordered = TabTitleDeriver.untitledTitle(from: "1. First ordered item stays clean")
        let quoted = TabTitleDeriver.untitledTitle(from: "> Quoted thought about speed")

        // THEN leading markers are excluded and spaces separate the extracted words
        #expect(heading == "My Project Notes for")
        #expect(checklist == "Finish release checklist immediately")
        #expect(ordered == "First ordered item stays")
        #expect(quoted == "Quoted thought about speed")
    }

    @Test("N1: TabTitleDeriver falls back to Untitled when empty/marker-only and clamps long titles with ellipsis")
    func n1UntitledTabTitleEmptyFallbackAndTruncation() {
        // GIVEN empty, marker-only, and overlong 4-word inputs
        let emptyTitle = TabTitleDeriver.untitledTitle(from: "")
        let markersOnly = TabTitleDeriver.untitledTitle(from: "### \n - [ ] \n ---\n")
        let longTitle = TabTitleDeriver.untitledTitle(from: "Supercalifragilisticexpialidocious extraordinary documentation guide")

        // THEN empty/marker-only inputs yield "Untitled" and overlong titles clamp to <= 36 chars ending with ellipsis
        #expect(emptyTitle == "Untitled")
        #expect(markersOnly == "Untitled")
        #expect(longTitle.count <= TabTitleDeriver.defaultMaxCharacters)
        #expect(longTitle.hasSuffix("…"))
    }

    @MainActor
    @Test("P3: SwiftEditWorkbenchModel dynamically updates unsaved tab titles and locks to filename once saved")
    func p3WorkbenchUpdatesUntitledTabTitleAndLocksOnSave() throws {
        // GIVEN an isolated temporary directory and workbench with a fresh untitled tab
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditTabTitle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempRoot.appendingPathComponent("Rec", isDirectory: true)
        )
        model.newUntitledTab()
        let initialTitle = model.activeTabTitle

        // WHEN editing the unsaved buffer and subsequently saving to "notes.md"
        model.handleEditorTextChanged("# Weekly Sync Agenda October")
        let editedTitle = model.activeTabTitle
        model.saveDocument(to: tempRoot.appendingPathComponent("notes.md"))
        let savedTitle = model.activeTabTitle
        model.handleEditorTextChanged("# Completely Different Heading After Save")
        let titleAfterSaveEdit = model.activeTabTitle

        // THEN untitled starts at "Untitled", adopts first 4 words, then locks to "notes.md" after saving
        #expect(initialTitle == "Untitled")
        #expect(editedTitle == "Weekly Sync Agenda October")
        #expect(savedTitle == "notes.md")
        #expect(titleAfterSaveEdit == "notes.md")
    }

    @Test("P4: TerminalCatalog discovers installed allowlisted terminals and resolves explicit or Auto preferences")
    func p4TerminalCatalogDiscoveryAndResolution() {
        // GIVEN a host with Terminal, Ghostty, and iTerm2 installed (and Warp absent)
        let installed: Set<String> = [
            "com.apple.Terminal",
            "com.mitchellh.ghostty",
            "com.googlecode.iterm2",
        ]

        // WHEN enumerating installed terminals and resolving Auto / Ghostty selections
        let discovered = TerminalCatalog.installedTerminals { installed.contains($0) }
        let autoChoice = TerminalCatalog.resolveBundleID(preferredBundleID: nil, installedBundleIDs: installed)
        let explicitChoice = TerminalCatalog.resolveBundleID(preferredBundleID: "com.mitchellh.ghostty", installedBundleIDs: installed)
        let autoWithoutITerm = TerminalCatalog.resolveBundleID(preferredBundleID: nil, installedBundleIDs: ["com.apple.Terminal"])

        // THEN discovered list contains the 3 installed terminals, Auto prefers iTerm2 when present, and explicit choice wins
        #expect(discovered.map(\.bundleIdentifier) == ["com.googlecode.iterm2", "com.apple.Terminal", "com.mitchellh.ghostty"])
        #expect(autoChoice == "com.googlecode.iterm2")
        #expect(explicitChoice == "com.mitchellh.ghostty")
        #expect(autoWithoutITerm == "com.apple.Terminal")
    }

    @Test("N2 [Security]: TerminalCatalog & DesktopWorkspaceValidator fall back from uninstalled apps and block non-allowlisted bundle IDs")
    func n2UninstalledFallsBackAndUntrustedBundleBlocked() throws {
        // GIVEN a temporary file inside workspace and an uninstalled/untrusted terminal bundle ID
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditTermN2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let canonical = tempRoot.resolvingSymlinksInPath().standardizedFileURL
        let noteURL = canonical.appendingPathComponent("doc.md")
        try Data("ok".utf8).write(to: noteURL)

        // WHEN resolving a removed terminal preference and validating a rogue bundle ID
        let fallback = TerminalCatalog.resolveBundleID(
            preferredBundleID: "dev.warp.Warp-Stable",
            installedBundleIDs: ["com.apple.Terminal"]
        )

        // THEN uninstalled falls back safely to Terminal.app and rogue bundle throws securityScopeViolation
        #expect(fallback == "com.apple.Terminal")
        #expect(throws: DomainError.securityScopeViolation(path: "com.untrusted.terminal")) {
            _ = try DesktopWorkspaceValidator.resolveTerminalLaunch(
                targetURL: noteURL,
                withinScope: canonical,
                explicitBundleIdentifier: "com.untrusted.terminal",
                isITerm2Installed: false,
                isITerm2Preferred: false
            )
        }
    }

    @MainActor
    @Test("P5: Settings terminal selection persists in EditorPreferencesStore and drives sidebarOpenInTerminal")
    func p5SettingsTerminalSelectionPersistsAndDrivesOpenInTerminal() throws {
        // GIVEN an in-memory preferences store, spy workspace, and installed Warp + Terminal + iTerm2
        let prefsKV = InMemoryKeyValueStore()
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditTermP5-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let canonical = tempRoot.resolvingSymlinksInPath().standardizedFileURL

        let spyWorkspace = SpyTerminalWorkspaceFake()
        let model = SwiftEditWorkbenchModel(
            preferencesStore: prefsKV,
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempRoot.appendingPathComponent("Rec", isDirectory: true),
            desktopWorkspace: spyWorkspace,
            installedTerminalBundleIDsProvider: {
                ["com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable"]
            }
        )
        let settings = SettingsViewModel(
            model: model,
            catalog: SystemFontCatalog(source: DummyFamiliesSource(), isOpenDyslexicAvailable: { false }),
            installedTerminalsProvider: {
                TerminalCatalog.installedTerminals {
                    ["com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable"].contains($0)
                }
            }
        )
        model.selectWorkspaceFolder(canonical)

        // WHEN selecting Warp in redesigned Settings and opening Terminal from the sidebar
        settings.selectedSection = .terminal
        settings.selectTerminal("dev.warp.Warp-Stable")
        model.sidebarOpenInTerminal(at: canonical)
        let reloaded = EditorPreferencesStore(store: prefsKV).load()

        // THEN Settings section, persistence, and sidebar Open in Terminal all reflect Warp
        #expect(settings.selectedSection == .terminal)
        #expect(reloaded.preferredTerminalBundleID == "dev.warp.Warp-Stable")
        #expect(spyWorkspace.launchedBundles == ["dev.warp.Warp-Stable"])
    }

    @Test("P6: GitHubReleaseUpdateChecker detects newer semantic release and provides verified HTTPS asset URL")
    func p6GitHubReleaseCheckerDetectsNewerVersion() async {
        // GIVEN a GitHub /releases/latest JSON payload for v0.0.1-alpha6
        let payload = """
        {
          "tag_name": "v0.0.1-alpha6",
          "html_url": "https://github.com/paonath/PH.SwiftEdit/releases/tag/v0.0.1-alpha6",
          "draft": false,
          "prerelease": false,
          "assets": [
            {
              "name": "PH.SwiftEdit-v0.0.1-alpha6-macOS-arm64.zip",
              "browser_download_url": "https://github.com/paonath/PH.SwiftEdit/releases/download/v0.0.1-alpha6/PH.SwiftEdit-v0.0.1-alpha6-macOS-arm64.zip"
            }
          ]
        }
        """
        let fetcher = StubHTTPFetcher(responses: [
            GitHubReleaseUpdateChecker.latestReleaseAPIURL.absoluteString: (Data(payload.utf8), 200),
        ])
        let checker = GitHubReleaseUpdateChecker(fetcher: fetcher)

        // WHEN checking from current version 0.0.1-alpha5
        let outcome = await checker.checkForUpdates(currentVersion: "0.0.1-alpha5")

        // THEN updateAvailable is returned with both verified release & download URLs
        #expect(outcome == .updateAvailable(
            currentVersion: "0.0.1-alpha5",
            latestVersion: "0.0.1-alpha6",
            releaseURL: URL(string: "https://github.com/paonath/PH.SwiftEdit/releases/tag/v0.0.1-alpha6")!,
            downloadURL: URL(string: "https://github.com/paonath/PH.SwiftEdit/releases/download/v0.0.1-alpha6/PH.SwiftEdit-v0.0.1-alpha6-macOS-arm64.zip")!
        ))
    }

    @Test("P7: GitHubReleaseUpdateChecker reports upToDate when matching and noReleasesFound when GitHub has no releases")
    func p7GitHubReleaseCheckerUpToDateAndEmptyReleases() async {
        // GIVEN a matching latest release fixture and an empty (404) repository fixture
        let matchingPayload = """
        {
          "tag_name": "v0.0.1-alpha5",
          "html_url": "https://github.com/paonath/PH.SwiftEdit/releases/tag/v0.0.1-alpha5",
          "draft": false
        }
        """
        let upToDateChecker = GitHubReleaseUpdateChecker(fetcher: StubHTTPFetcher(responses: [
            GitHubReleaseUpdateChecker.latestReleaseAPIURL.absoluteString: (Data(matchingPayload.utf8), 200),
        ]))
        let emptyChecker = GitHubReleaseUpdateChecker(fetcher: StubHTTPFetcher(responses: [:]))

        // WHEN checking both
        let sameOutcome = await upToDateChecker.checkForUpdates(currentVersion: "0.0.1-alpha5")
        let noneOutcome = await emptyChecker.checkForUpdates(currentVersion: "0.0.1-alpha5")

        // THEN current version is reported up to date / no releases found
        #expect(sameOutcome == .upToDate(currentVersion: "0.0.1-alpha5"))
        #expect(noneOutcome == .noReleasesFound(currentVersion: "0.0.1-alpha5"))
    }

    @Test("N3 [Security]: GitHubReleaseUpdateChecker rejects untrusted release host URLs and non-HTTPS schemes fail-closed")
    func n3SecurityRejectsUntrustedReleaseAndAssetURLs() async {
        // GIVEN a tampered GitHub JSON pointing html_url / asset download URL to an untrusted or non-HTTPS origin
        let tamperedPayload = """
        {
          "tag_name": "v9.9.9",
          "html_url": "https://evil.example.com/phish",
          "draft": false,
          "assets": [
            {
              "name": "SwiftEdit.zip",
              "browser_download_url": "http://github.com/paonath/PH.SwiftEdit/releases/download/v9.9.9/SwiftEdit.zip"
            }
          ]
        }
        """
        let checker = GitHubReleaseUpdateChecker(fetcher: StubHTTPFetcher(responses: [
            GitHubReleaseUpdateChecker.latestReleaseAPIURL.absoluteString: (Data(tamperedPayload.utf8), 200),
        ]))

        // WHEN checking updates and validating explicit URL helper
        let outcome = await checker.checkForUpdates(currentVersion: "0.0.1-alpha5")
        let verifiedHTTP = GitHubReleaseUpdateChecker.verifiedGitHubHTTPSURL("http://github.com/paonath/PH.SwiftEdit")
        let verifiedJS = GitHubReleaseUpdateChecker.verifiedGitHubHTTPSURL("javascript:alert(1)")

        // THEN tampered host is rejected fail-closed with .error and non-HTTPS schemes return nil
        #expect(outcome == .error(message: "Rejected untrusted release URL in GitHub payload."))
        #expect(verifiedHTTP == nil)
        #expect(verifiedJS == nil)
    }

    @Test("P8: XcodeApp/Info.plist exposes App Name SwiftEdit while preserving Bundle ID it.ph.SwiftEdit")
    func p8InfoPlistExposesSwiftEditAppName() throws {
        // GIVEN XcodeApp/Info.plist on disk
        let plistURL = RepoRootLocator.rootURL.appendingPathComponent("XcodeApp/Info.plist")
        let plistData = try Data(contentsOf: plistURL)
        let dict = try #require(PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any])

        // THEN display/bundle/executable name is SwiftEdit while identifier stays it.ph.SwiftEdit
        #expect((dict["CFBundleName"] as? String) == "SwiftEdit")
        #expect((dict["CFBundleDisplayName"] as? String) == "SwiftEdit")
        #expect((dict["CFBundleExecutable"] as? String) == "SwiftEdit")
        #expect((dict["CFBundleIdentifier"] as? String) == "it.ph.SwiftEdit")
    }
}
