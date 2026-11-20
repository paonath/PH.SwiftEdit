import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
/// Diagnostics popover (`⇧⌘M` or the status-bar `Lint:` button) listing findings with Jump-to-Range, per-item Quick-Fix and a single-Undo Fix All (`UI-005`, `UI-007`).
///
/// Security diagnostics expose no Quick-Fix button; messages are static rule texts and never echo document content (`SEC-012`).
@MainActor
struct MarkdownDiagnosticsPopoverView: View {
    let model: SwiftEditWorkbenchModel

    var body: some View {
        let diagnostics = model.lintDiagnostics
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.activeLintStatus.label).font(.headline)
                Spacer()
                Button("Fix All") { model.applyFixAll() }
                    .disabled(!diagnostics.contains { $0.quickFix != nil })
                    .accessibilityHint("Applies every available fix in a single undo step")
            }
            Divider()
            if diagnostics.isEmpty {
                Text("No Markdown diagnostics").foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(diagnostics.prefix(MarkdownLintAndFormatEngine.maxDiagnostics).enumerated()), id: \.offset) { _, diagnostic in
                            HStack(spacing: 6) {
                                Image(systemName: diagnostic.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle((diagnostic.severity == .error ? model.palette.unbalancedBracketHighlight : model.palette.bidiWarningForeground).swiftUIColor)
                                Button("Ln \(diagnostic.line): \(diagnostic.message)") { model.jumpToDiagnostic(diagnostic) }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if diagnostic.quickFix != nil {
                                    Button("Fix") { model.applyQuickFix(diagnostic) }
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(12)
        .frame(width: 420)
    }
}
#endif
