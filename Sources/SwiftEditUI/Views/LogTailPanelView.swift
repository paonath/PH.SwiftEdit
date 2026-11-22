#if os(macOS)
import SwiftEditCore
import SwiftUI

/// Compact Log function header shown inside the editing area (`REQ-LOG`): Stop/Resume, Direct/Inverse, line count, Close.
struct LogTailPanelView: View {
    let model: SwiftEditWorkbenchModel
    let tail: LogTailController
    @State private var lineText = ""

    var body: some View {
        let palette = model.palette
        HStack(spacing: 10) {
            Image(systemName: tail.isRunning ? "dot.radiowaves.left.and.right" : "pause.circle")
                .foregroundStyle((tail.isRunning ? palette.logInfoForeground : palette.secondaryForeground).swiftUIColor)
                .accessibilityHidden(true)
            Text(tail.isRunning ? "Log · live" : "Log · stopped")
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(palette.chromeForeground.swiftUIColor)
                .accessibilityLabel(tail.isRunning ? "Log tail running" : "Log tail stopped")
            Picker("Order", selection: Binding(get: { tail.mode }, set: { tail.setMode($0) })) {
                Text("Direct").tag(LogTailMode.direct)
                Text("Inverse").tag(LogTailMode.inverse)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityLabel("Tail order")
            HStack(spacing: 4) {
                Text("Lines").appFont(.caption).foregroundStyle(palette.secondaryForeground.swiftUIColor)
                TextField("80", text: $lineText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                    .onSubmit { if let value = Int(lineText) { tail.setLineCount(value) }; lineText = String(tail.lineCount) }
                    .accessibilityLabel("Number of tail lines")
                Stepper("", value: Binding(get: { tail.lineCount }, set: { tail.setLineCount($0); lineText = String($0) }), in: 1...LogTailBuffer.maxLines, step: 10)
                    .labelsHidden()
                    .accessibilityLabel("Adjust number of tail lines")
            }
            Text("\(tail.visibleLineCount) shown")
                .appFont(.caption, monospaced: true)
                .foregroundStyle(palette.secondaryForeground.swiftUIColor)
            if let error = tail.errorMessage {
                Text(error).appFont(.caption).foregroundStyle(palette.logErrorForeground.swiftUIColor).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(tail.isRunning ? "Stop" : "Resume") {
                if tail.isRunning { model.stopLogTail() } else { model.startLogTail(mode: tail.mode) }
            }
            .accessibilityLabel(tail.isRunning ? "Stop log tail" : "Resume log tail")
            if !model.logTailOnlyTabIDs.contains(tail.tabID) {
                Button { model.closeLogTail() } label: { Image(systemName: "xmark").minimumHitTarget() }
                    .buttonStyle(.plain)
                    .help("Close the Log panel and return to the editor")
                    .accessibilityLabel("Close log panel")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(palette.chromeSurface.swiftUIColor)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.hairlineBorder.swiftUIColor).frame(height: 1) }
        .onAppear { lineText = String(tail.lineCount) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Log panel")
    }
}
#endif
