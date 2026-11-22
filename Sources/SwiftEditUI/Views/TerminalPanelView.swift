#if os(macOS)
import SwiftEditCore
import SwiftUI

/// Bottom Terminal panel (`Cmd+J`): one tab per session; each session runs in the preferred external terminal.
struct TerminalPanelView: View {
    let model: SwiftEditWorkbenchModel

    var body: some View {
        let palette = model.palette
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(model.terminalSessions) { session in
                    let selected = session.id == model.selectedTerminalSessionID
                    HStack(spacing: 4) {
                        Button { model.selectedTerminalSessionID = session.id } label: {
                            Text(session.title)
                                .appFont(.caption, weight: selected ? .semibold : .regular)
                                .foregroundStyle((selected ? palette.chromeForeground : palette.secondaryForeground).swiftUIColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(session.title)\(selected ? ", selected" : "")")
                        Button { model.closeTerminalSession(id: session.id) } label: {
                            Image(systemName: "xmark").appFont(.caption2).minimumHitTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close \(session.title)")
                    }
                    .padding(.horizontal, 8)
                    .background(selected ? palette.tabActiveSurface.swiftUIColor : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                Button { model.openTerminalSession() } label: { Image(systemName: "plus").minimumHitTarget() }
                    .buttonStyle(.plain)
                    .help("New terminal session in the current folder")
                    .accessibilityLabel("New terminal session")
                Spacer()
                Button { model.toggleTerminalPanel() } label: { Image(systemName: "chevron.down").minimumHitTarget() }
                    .buttonStyle(.plain)
                    .help("Close the Terminal panel (Cmd+J)")
                    .accessibilityLabel("Close terminal panel")
            }
            if let session = model.terminalSessions.first(where: { $0.id == model.selectedTerminalSessionID }) {
                sessionDetail(session, palette: palette)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.chromeSurface.swiftUIColor)
        .overlay(alignment: .top) { Rectangle().fill(palette.hairlineBorder.swiftUIColor).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Terminal panel")
    }

    @ViewBuilder
    private func sessionDetail(_ session: TerminalPanelSession, palette: PurpleThemePalette) -> some View {
        HStack(spacing: 10) {
            switch session.state {
            case .pending:
                Text("Starting…").appFont(.caption)
            case .running(let appName, let since):
                Image(systemName: "terminal").accessibilityHidden(true)
                Text("\(appName) · \(session.directory.path)")
                    .appFont(.caption, monospaced: true)
                    .lineLimit(1).truncationMode(.middle)
                Text("since \(since.formatted(date: .omitted, time: .shortened))")
                    .appFont(.caption).foregroundStyle(palette.secondaryForeground.swiftUIColor)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(palette.logErrorForeground.swiftUIColor)
                    .accessibilityHidden(true)
                Text(message).appFont(.caption).foregroundStyle(palette.logErrorForeground.swiftUIColor).lineLimit(2)
            }
            Spacer()
            Button("Open Again") { model.relaunchTerminalSession(id: session.id) }
                .accessibilityLabel("Open \(session.title) again")
        }
        .foregroundStyle(palette.chromeForeground.swiftUIColor)
    }
}
#endif
