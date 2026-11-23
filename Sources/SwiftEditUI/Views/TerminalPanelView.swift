#if os(macOS)
import AppKit
import SwiftEditCore
import SwiftUI

/// Bottom embedded Terminal panel (`Cmd+J`): hosts real interactive in-app `SwiftTerm` VT100/xterm-256color PTY sessions
/// accelerated by SwiftTerm's GPU Metal renderer, with a global-coordinate drag handle for smooth vertical resizing.
struct TerminalPanelView: View {
    let model: SwiftEditWorkbenchModel
    @State private var dragStartHeight: CGFloat?
    @State private var isHoveringResize = false

    var body: some View {
        let palette = model.palette
        VStack(alignment: .leading, spacing: 0) {
            // Generous 10pt interactive resize bar using `.global` coordinates so panel growth never oscillates the drag delta.
            ZStack {
                Rectangle()
                    .fill(palette.chromeSurface.swiftUIColor)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(palette.hairlineBorder.swiftUIColor)
                        .frame(height: 1)
                    Spacer(minLength: 0)
                    Capsule()
                        .fill((isHoveringResize ? palette.chromeAccent : palette.hairlineBorder).swiftUIColor)
                        .frame(width: 40, height: 3.5)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering && !isHoveringResize {
                    isHoveringResize = true
                    NSCursor.resizeUpDown.push()
                } else if !hovering && isHoveringResize {
                    isHoveringResize = false
                    NSCursor.pop()
                }
            }
            .onDisappear {
                if isHoveringResize {
                    isHoveringResize = false
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let base = dragStartHeight ?? model.terminalPanelHeight
                        if dragStartHeight == nil { dragStartHeight = base }
                        let maxAvailable = (model.hostWindow?.contentView?.bounds.height ?? 900) * 0.78
                        model.setTerminalPanelHeight(base - value.translation.height, maxAvailableHeight: maxAvailable, persist: false)
                    }
                    .onEnded { _ in
                        dragStartHeight = nil
                        model.setTerminalPanelHeight(model.terminalPanelHeight, persist: true)
                    }
            )
            .onTapGesture(count: 2) {
                let target: CGFloat = model.terminalPanelHeight < 340 ? 440 : 240
                let maxAvailable = (model.hostWindow?.contentView?.bounds.height ?? 900) * 0.78
                model.setTerminalPanelHeight(target, maxAvailableHeight: maxAvailable)
            }
            .help("Drag up or down to resize the terminal (double-click to expand/restore)")
            .accessibilityLabel("Resize terminal panel")

            // Tab bar
            HStack(spacing: 6) {
                ForEach(model.terminalSessions) { session in
                    let selected = session.id == model.selectedTerminalSessionID
                    HStack(spacing: 4) {
                        Button { model.selectedTerminalSessionID = session.id } label: {
                            HStack(spacing: 4) {
                                AppIconView(.terminal, size: 12)
                                Text(session.title)
                                    .appFont(.caption, weight: selected ? .semibold : .regular)
                            }
                            .foregroundStyle((selected ? palette.chromeForeground : palette.secondaryForeground).swiftUIColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(session.title)\(selected ? ", selected" : "")")
                        Button { model.closeTerminalSession(id: session.id) } label: {
                            AppIconView(.close, size: 10).minimumHitTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close \(session.title)")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(selected ? palette.tabActiveSurface.swiftUIColor : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                Button { model.openTerminalSession() } label: { AppIconView(.plus, size: 13).minimumHitTarget() }
                    .buttonStyle(.plain)
                    .help("New embedded terminal session in the current folder")
                    .accessibilityLabel("New terminal session")

                if let active = model.terminalSessions.first(where: { $0.id == model.selectedTerminalSessionID }) {
                    Text(active.directory.path)
                        .appFont(.caption, monospaced: true)
                        .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.leading, 4)
                }

                Spacer()
                if let active = model.terminalSessions.first(where: { $0.id == model.selectedTerminalSessionID }) {
                    Button("Restart") { model.relaunchTerminalSession(id: active.id) }
                        .appFont(.caption)
                        .accessibilityLabel("Restart \(active.title)")
                }
                Button { model.toggleTerminalPanel() } label: { AppIconView(.chevronDown, size: 13).minimumHitTarget() }
                    .buttonStyle(.plain)
                    .help("Close the Terminal panel and stop all shells (Cmd+J)")
                    .accessibilityLabel("Close terminal panel")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(palette.chromeSurface.swiftUIColor)

            Rectangle()
                .fill(palette.hairlineBorder.swiftUIColor)
                .frame(height: 1)

            // Live GPU-accelerated embedded VT100/xterm-256color terminal emulator
            if let session = model.terminalSessions.first(where: { $0.id == model.selectedTerminalSessionID }) {
                switch session.state {
                case .failed(let message):
                    HStack(spacing: 10) {
                        AppIconView(.warning, size: 14, label: "Error")
                            .foregroundStyle(palette.logErrorForeground.swiftUIColor)
                        Text(message)
                            .appFont(.caption)
                            .foregroundStyle(palette.logErrorForeground.swiftUIColor)
                        Spacer()
                        Button("Restart") { model.relaunchTerminalSession(id: session.id) }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(palette.editorCanvasBackground.swiftUIColor)
                case .pending, .running:
                    let termFont = model.typography.nsFont(
                        .editor,
                        size: CGFloat(max(10, min(28, model.zoomController.scaledFontSizePoints)))
                    )
                    EmbeddedTerminalEmulatorView(
                        registry: model.embeddedTerminalRegistry,
                        sessionID: session.id,
                        directory: session.directory,
                        palette: palette,
                        font: termFont,
                        onTitleChange: { _, _ in },
                        onDirectoryChange: { id, dir in
                            model.embeddedTerminalDidUpdateDirectory(id: id, directory: dir)
                        },
                        onTerminated: { id, code in
                            model.embeddedTerminalDidTerminate(id: id, exitCode: code)
                        },
                        onFailedToStart: { id, error in
                            model.embeddedTerminalDidFail(id: id, message: error)
                        }
                    )
                    .id(session.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.editorCanvasBackground.swiftUIColor)
                }
            }
        }
        .frame(height: model.terminalPanelHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.chromeSurface.swiftUIColor)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Terminal panel")
    }
}
#endif
