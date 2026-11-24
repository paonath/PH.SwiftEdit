import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("WorkbenchSubControllersDecompositionTests")
struct WorkbenchSubControllersDecompositionTests {

    @Test("P2: Isolated workbench sub-controllers execute domain operations deterministically and sync with SwiftEditWorkbenchModel")
    @MainActor
    func p2IsolatedSubControllersExecuteAndSyncWithFacade() throws {
        // GIVEN isolated instances of the 5 extracted @MainActor workbench sub-controllers
        let wordCompletion = WorkbenchWordCompletionController()
        let findNav = WorkbenchFindAndNavigationController()
        let terminal = WorkbenchTerminalSessionController()
        let fs = InMemoryFileSystemFake()
        let parentURL = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let rootURL = try fs.createDirectory(named: "swiftedit-subctrl-p2", in: parentURL, withinScope: nil)
        let sidebar = WorkbenchSidebarFileController(fileSystem: fs)
        let updates = WorkbenchUpdateController(updateChecker: GitHubReleaseUpdateChecker())

        // WHEN exercising each controller directly
        let docID = DocumentID()
        wordCompletion.rebuildIndexNow(documentID: docID, revision: BufferRevision(1), text: "architecture modularity architecture", caretLocation: 0)
        let suffix = wordCompletion.completionSuffix(forPrefix: "modu", documentID: docID, isEligible: true)

        findNav.presentFindBar(mode: .findAndReplace)
        findNav.state.query = "alpha"
        let searchSnap = DocumentSession(text: "alpha beta alpha").snapshot
        let firstMatch = findNav.executeFind(in: searchSnap)
        let lineSnap = DocumentSession(text: "line1\nline2\nline3").snapshot
        let goToLineRange = findNav.resolveGoToLineRange(query: "2", in: lineSnap)

        let session = terminal.openSession(initialDirectory: rootURL)
        let singleOutcome = terminal.evaluateSendSelection(selection: SwiftEditCore.TextRange(location: 0, length: 6), in: "ls -la")

        let createdURL = sidebar.createFile(named: "notes.md", in: rootURL, scopeRoot: rootURL)
        updates.dismissDialog()

        // THEN every sub-controller produces deterministic state and SwiftEditWorkbenchModel exposes matching facade behavior
        #expect(suffix == "larity")
        #expect(findNav.state.mode == .findAndReplace)
        #expect(findNav.state.matches.count == 2)
        #expect(firstMatch == SwiftEditCore.TextRange(location: 0, length: 5))
        #expect(goToLineRange?.location == 6)
        #expect(terminal.sessions.contains(where: { $0.id == session.id }))
        if case .deliverImmediately(let payload) = singleOutcome {
            #expect(payload.text == "ls -la")
        } else {
            Issue.record("Expected immediate single-line terminal delivery")
        }
        #expect(createdURL?.lastPathComponent == "notes.md")
        #expect(updates.isDialogPresented == false)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            fileSystem: fs,
            systemDarkDetector: { false }
        )
        model.newUntitledTab()
        model.handleEditorTextChanged("architecture modularity")
        model.rebuildWordCompletionIndexNow()
        #expect(model.wordCompletionSuffix(forPrefix: "modu") == "larity")

        let contextualExtURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+ContextualMenuAndShortcuts.swift")
        #expect(FileManager.default.fileExists(atPath: contextualExtURL.path))
    }

    @Test("P2: SwiftEditWorkbenchModel (<=22), WorkspaceEditorCoordinator (<=20), DocumentSession (<=20), and LogTailController (<=20) satisfy sub-struct flattened budgets")
    @MainActor
    func p2WorkbenchCoordinatorDocumentSessionAndLogTailStayWithinFlattenedMemberBudgets() throws {
        // GIVEN the 4 domain/workbench nominal source files and their strict <=20..22 member budgets
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workbenchSource = try String(contentsOf: repoRoot.appendingPathComponent("Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel.swift"), encoding: .utf8)
        let coordinatorSource = try String(contentsOf: repoRoot.appendingPathComponent("Sources/SwiftEditUI/Coordinators/WorkspaceEditorAndDiffCoordinators.swift"), encoding: .utf8)
        let docSessionSource = try String(contentsOf: repoRoot.appendingPathComponent("Sources/SwiftEditCore/DocumentCore/DocumentSession.swift"), encoding: .utf8)
        let logTailSource = try String(contentsOf: repoRoot.appendingPathComponent("Sources/SwiftEditUI/Workspace/LogTailController.swift"), encoding: .utf8)

        // WHEN scanning each file against its target nominal member ceiling and exercising facade state
        let workbenchViolations = CodeModularityFitnessScanner.scanSource(
            content: workbenchSource,
            filePath: "SwiftEditUI/Workbench/SwiftEditWorkbenchModel.swift",
            budgets: CodeModularityBudgets(maxFileLines: 800, maxNominalBlockLines: 400, maxNominalMembers: 22)
        )
        let coordinatorViolations = CodeModularityFitnessScanner.scanSource(
            content: coordinatorSource,
            filePath: "SwiftEditUI/Coordinators/WorkspaceEditorAndDiffCoordinators.swift",
            budgets: CodeModularityBudgets(maxFileLines: 800, maxNominalBlockLines: 400, maxNominalMembers: 20)
        )
        let docSessionViolations = CodeModularityFitnessScanner.scanSource(
            content: docSessionSource,
            filePath: "SwiftEditCore/DocumentCore/DocumentSession.swift",
            budgets: CodeModularityBudgets(maxFileLines: 800, maxNominalBlockLines: 400, maxNominalMembers: 20)
        )
        let logTailViolations = CodeModularityFitnessScanner.scanSource(
            content: logTailSource,
            filePath: "SwiftEditUI/Workspace/LogTailController.swift",
            budgets: CodeModularityBudgets(maxFileLines: 800, maxNominalBlockLines: 400, maxNominalMembers: 20)
        )
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            fileSystem: InMemoryFileSystemFake(),
            systemDarkDetector: { true }
        )
        model.isCheatSheetPresented = true
        model.showMarkdownPreview = true

        // THEN zero nominal member violations occur and observable facade properties synchronize
        #expect(workbenchViolations.isEmpty, "Expected <= 22 members in SwiftEditWorkbenchModel.swift, got: \(workbenchViolations)")
        #expect(coordinatorViolations.isEmpty, "Expected <= 20 members in WorkspaceEditorCoordinator, got: \(coordinatorViolations)")
        #expect(docSessionViolations.isEmpty, "Expected <= 20 members in DocumentSession, got: \(docSessionViolations)")
        #expect(logTailViolations.isEmpty, "Expected <= 20 members in LogTailController, got: \(logTailViolations)")
        #expect(model.isCheatSheetPresented == true)
        #expect(model.showMarkdownPreview == true)
    }

    @Test("N3: Invalid prefix, out-of-scope sidebar path, invalid go-to-line, and unconfirmed multiline terminal send are rejected")
    @MainActor
    func n3InvalidInputsAndBoundariesAreRejectedWithoutMutation() throws {
        // GIVEN isolated sub-controllers with valid root scope
        let wordCompletion = WorkbenchWordCompletionController()
        let findNav = WorkbenchFindAndNavigationController()
        let terminal = WorkbenchTerminalSessionController()
        let fs = InMemoryFileSystemFake()
        let parentURL = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let rootURL = try fs.createDirectory(named: "swiftedit-subctrl-n3", in: parentURL, withinScope: nil)
        let outsideURL = try fs.createDirectory(named: "outside-scope", in: parentURL, withinScope: nil)
        let sidebar = WorkbenchSidebarFileController(fileSystem: fs)
        let lineSnap = DocumentSession(text: "line1\nline2").snapshot

        // WHEN submitting boundary/invalid inputs
        let docID = DocumentID()
        wordCompletion.rebuildIndexNow(documentID: docID, revision: BufferRevision(1), text: "architecture", caretLocation: 0)
        let singleCharSuffix = wordCompletion.completionSuffix(forPrefix: "a", documentID: docID, isEligible: true)
        let ineligibleSuffix = wordCompletion.completionSuffix(forPrefix: "arch", documentID: docID, isEligible: false)
        let invalidLine = findNav.resolveGoToLineRange(query: "0", in: lineSnap)
        let nonNumericLine = findNav.resolveGoToLineRange(query: "abc", in: lineSnap)
        let outOfScopeCreate = sidebar.createFile(named: "evil.md", in: outsideURL, scopeRoot: rootURL)
        let multilineOutcome = terminal.evaluateSendSelection(selection: SwiftEditCore.TextRange(location: 0, length: 13), in: "echo 1\necho 2")

        // THEN all invalid/boundary requests fail closed without mutating state
        #expect(singleCharSuffix == nil)
        #expect(ineligibleSuffix == nil)
        #expect(invalidLine == nil)
        #expect(nonNumericLine == nil)
        #expect(outOfScopeCreate == nil)
        #expect(sidebar.lastErrorMessage != nil)
        if case .requiresMultilineConfirmation(let payload) = multilineOutcome {
            #expect(payload.isMultiline == true)
            #expect(terminal.pendingMultilineSend == payload)
        } else {
            Issue.record("Expected multiline confirmation gate")
        }
    }
}
