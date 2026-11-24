#if os(macOS)
import AppKit
import SwiftEditCore
import SwiftTerm

/// `LocalProcessTerminalView` subclass that activates SwiftTerm's GPU Metal renderer once attached to a window (`AR-005`).
@MainActor
final class SwiftEditTerminalView: LocalProcessTerminalView {
    private var didAttemptMetalActivation = false
    private(set) var isMetalActive = false

    override func viewDidMoveToWindow() {
        let shouldActivate = (window != nil && !didAttemptMetalActivation)
        super.viewDidMoveToWindow()
        guard shouldActivate, window != nil else { return }
        didAttemptMetalActivation = true
        wantsLayer = true
        layer?.isOpaque = true
        optionAsMetaKey = true
        allowMouseReporting = true
        do {
            try setUseMetal(true)
            isMetalActive = true
        } catch {
            isMetalActive = false
        }
    }
}

/// Owns live `SwiftTerm.LocalProcessTerminalView` instances keyed by `TerminalPanelSession.id` so switching between terminal tabs preserves each shell's PTY and scrollback (`AR-005`, `AR-006`, `SEC-004`).
@MainActor
public final class EmbeddedTerminalRegistry {
    private final class Entry: NSObject, LocalProcessTerminalViewDelegate {
        let sessionID: UUID
        let terminalView: SwiftEditTerminalView
        let onTitleChange: (UUID, String) -> Void
        let onDirectoryChange: (UUID, String?) -> Void
        let onTerminated: (UUID, Int32?) -> Void
        let onFailedToStart: (UUID, String) -> Void
        var hasStarted = false
        var isReadyForInput = false
        var isTerminated = false
        var lastPalette: PurpleThemePalette?
        var lastFont: NSFont?

        init(
            sessionID: UUID,
            terminalView: SwiftEditTerminalView,
            onTitleChange: @escaping (UUID, String) -> Void,
            onDirectoryChange: @escaping (UUID, String?) -> Void,
            onTerminated: @escaping (UUID, Int32?) -> Void,
            onFailedToStart: @escaping (UUID, String) -> Void
        ) {
            self.sessionID = sessionID
            self.terminalView = terminalView
            self.onTitleChange = onTitleChange
            self.onDirectoryChange = onDirectoryChange
            self.onTerminated = onTerminated
            self.onFailedToStart = onFailedToStart
            super.init()
            terminalView.processDelegate = self
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                onTitleChange(sessionID, trimmed)
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            onDirectoryChange(sessionID, directory)
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            isTerminated = true
            onTerminated(sessionID, exitCode)
        }

        func processFailedToStart(source: TerminalView, error: LocalProcessError) {
            isTerminated = true
            onFailedToStart(sessionID, "\(error)")
        }
    }

    private var entriesByID: [UUID: Entry] = [:]
    private var pendingPayloadsBySessionID: [UUID: [TerminalSelectionPayload]] = [:]
    private var terminatedSessionIDs: Set<UUID> = []
    private var appTerminateObserver: (any NSObjectProtocol)?
    /// Delay after `startProcess` before flushing queued input so login shells finish prompt/bracketed-paste init.
    public var shellReadinessDelayMilliseconds: Int = 250
    /// Diagnostic hook invoked with `(sessionID, wireText)` whenever sanitized text is written to a live PTY.
    public var onDeliveredWireText: ((UUID, String) -> Void)?
    /// Number of queued payloads awaiting PTY readiness for `sessionID` (diagnostics and tests).
    public func pendingPayloadCount(for sessionID: UUID) -> Int {
        pendingPayloadsBySessionID[sessionID]?.count ?? 0
    }
    private static let cachedBaseEnvironment: [String] = {
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("COLORTERM=truecolor")
        env.append("LANG=en_US.UTF-8")
        if let path = ProcessInfo.processInfo.environment["PATH"], !path.isEmpty {
            env.removeAll { $0.hasPrefix("PATH=") }
            env.append("PATH=\(path)")
        }
        if let home = ProcessInfo.processInfo.environment["HOME"], !home.isEmpty {
            env.removeAll { $0.hasPrefix("HOME=") }
            env.append("HOME=\(home)")
        }
        return env
    }()

    public init() {
        appTerminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.terminateAll()
            }
        }
    }

    isolated deinit {
        if let observer = appTerminateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        terminateAll()
    }

    /// Number of currently tracked live terminal views (diagnostics and tests).
    public var activeViewCount: Int { entriesByID.count }

    /// Resolves the user's preferred interactive shell executable (defaulting to `/bin/zsh`).
    public static func defaultShellPath() -> String {
        if let envShell = ProcessInfo.processInfo.environment["SHELL"],
           !envShell.isEmpty,
           FileManager.default.isExecutableFile(atPath: envShell) {
            return envShell
        }
        return "/bin/zsh"
    }

    /// Returns `nil` if `sessionID` was already terminated (prevents SwiftUI teardown `updateNSView` from resurrecting a closed shell).
    func terminalView(
        for sessionID: UUID,
        directory: URL,
        palette: PurpleThemePalette,
        font: NSFont,
        onTitleChange: @escaping (UUID, String) -> Void,
        onDirectoryChange: @escaping (UUID, String?) -> Void,
        onTerminated: @escaping (UUID, Int32?) -> Void,
        onFailedToStart: @escaping (UUID, String) -> Void
    ) -> LocalProcessTerminalView? {
        guard !terminatedSessionIDs.contains(sessionID) else { return nil }
        if let existing = entriesByID[sessionID] {
            applyStylingIfNeeded(to: existing, palette: palette, font: font)
            return existing.terminalView
        }

        let view = SwiftEditTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 220))
        view.layerContentsRedrawPolicy = .duringViewResize
        let entry = Entry(
            sessionID: sessionID,
            terminalView: view,
            onTitleChange: onTitleChange,
            onDirectoryChange: onDirectoryChange,
            onTerminated: onTerminated,
            onFailedToStart: onFailedToStart
        )
        applyStylingIfNeeded(to: entry, palette: palette, font: font)
        entriesByID[sessionID] = entry
        startShell(for: entry, in: directory)
        return view
    }

    /// Restarts the shell process for `sessionID` in `directory`.
    func restart(sessionID: UUID, directory: URL) {
        guard let entry = entriesByID[sessionID] else { return }
        if !entry.isTerminated {
            let pid = entry.terminalView.process.shellPid
            entry.terminalView.terminate()
            if pid > 0 {
                _ = Darwin.kill(-pid, SIGHUP)
                _ = Darwin.kill(pid, SIGHUP)
            }
        }
        entry.hasStarted = false
        entry.isReadyForInput = false
        entry.isTerminated = false
        startShell(for: entry, in: directory)
    }

    /// Writes `payload` to the live PTY of `sessionID` without appending Return, or queues it until the newly opened shell is ready.
    public func sendPayload(_ payload: TerminalSelectionPayload, to sessionID: UUID) {
        guard !terminatedSessionIDs.contains(sessionID) else { return }
        if let entry = entriesByID[sessionID], !entry.isTerminated, entry.isReadyForInput {
            deliverNow(payload, to: entry)
        } else {
            pendingPayloadsBySessionID[sessionID, default: []].append(payload)
        }
    }

    /// Moves window first-responder focus to the live terminal view of `sessionID`, if mounted.
    public func focusTerminal(for sessionID: UUID) {
        guard let entry = entriesByID[sessionID], !entry.isTerminated else { return }
        let view = entry.terminalView
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
    }

    func flushPendingPayloads(for sessionID: UUID) {
        guard let entry = entriesByID[sessionID], !entry.isTerminated else {
            pendingPayloadsBySessionID.removeValue(forKey: sessionID)
            return
        }
        entry.isReadyForInput = true
        guard let queued = pendingPayloadsBySessionID.removeValue(forKey: sessionID), !queued.isEmpty else { return }
        for payload in queued {
            deliverNow(payload, to: entry)
        }
    }

    private func deliverNow(_ payload: TerminalSelectionPayload, to entry: Entry) {
        let wire = payload.wireText(bracketedPaste: true)
        entry.terminalView.send(txt: wire)
        onDeliveredWireText?(entry.sessionID, wire)
        let view = entry.terminalView
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
    }

    /// Terminates the child PTY process for `sessionID` and releases its view (`SEC-004`).
    public func terminate(sessionID: UUID) {
        pendingPayloadsBySessionID.removeValue(forKey: sessionID)
        if entriesByID.isEmpty && terminatedSessionIDs.count > 256 {
            terminatedSessionIDs.removeAll(keepingCapacity: true)
        }
        terminatedSessionIDs.insert(sessionID)
        guard let entry = entriesByID.removeValue(forKey: sessionID) else { return }
        entry.terminalView.processDelegate = nil
        if entry.hasStarted && !entry.isTerminated {
            let pid = entry.terminalView.process.shellPid
            entry.terminalView.terminate()
            if pid > 0 {
                _ = Darwin.kill(-pid, SIGHUP)
                _ = Darwin.kill(pid, SIGHUP)
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(250)) {
                    if Darwin.kill(pid, 0) == 0 {
                        _ = Darwin.kill(-pid, SIGKILL)
                        _ = Darwin.kill(pid, SIGKILL)
                    }
                }
            }
        }
        entry.isTerminated = true
    }

    /// Terminates every active embedded terminal session and clears the registry.
    public func terminateAll() {
        let allIDs = Array(entriesByID.keys)
        for id in allIDs {
            terminate(sessionID: id)
        }
    }

    private func startShell(for entry: Entry, in directory: URL) {
        let shellPath = Self.defaultShellPath()
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent
        let workingDir = directory.standardizedFileURL.path
        let validDir = FileManager.default.fileExists(atPath: workingDir)
            ? workingDir
            : FileManager.default.homeDirectoryForCurrentUser.path

        entry.hasStarted = true
        entry.isReadyForInput = false
        entry.terminalView.startProcess(
            executable: shellPath,
            args: ["-l"],
            environment: Self.cachedBaseEnvironment,
            execName: "-\(shellName)",
            currentDirectory: validDir
        )
        let sessionID = entry.sessionID
        let delayMs = max(0, shellReadinessDelayMilliseconds)
        if delayMs == 0 {
            flushPendingPayloads(for: sessionID)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) { [weak self] in
                self?.flushPendingPayloads(for: sessionID)
            }
        }
    }

    private func applyStylingIfNeeded(to entry: Entry, palette: PurpleThemePalette, font: NSFont) {
        guard entry.lastPalette != palette || entry.lastFont != font else { return }
        entry.lastPalette = palette
        entry.lastFont = font
        let view = entry.terminalView
        view.font = font
        view.nativeBackgroundColor = palette.editorCanvasBackground.nsColor
        view.nativeForegroundColor = palette.editorCanvasText.nsColor
        view.caretColor = palette.primaryAccent.nsColor
        view.selectedTextBackgroundColor = palette.selectionBackground.nsColor
    }
}
#endif
