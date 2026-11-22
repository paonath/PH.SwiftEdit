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
            headerView(diagnostics: diagnostics)
            Divider()
            contentView(diagnostics: diagnostics)
        }
        .padding(12)
        .frame(width: 420)
    }

    private func headerView(diagnostics: [MarkdownLintDiagnostic]) -> some View {
        HStack {
            Text(model.activeLintStatus.label).appFont(.headline)
            Spacer()
            Button("Fix All") { model.applyFixAll() }
                .disabled(!diagnostics.contains { $0.quickFix != nil })
                .accessibilityHint("Applies every available fix in a single undo step")
        }
    }

    @ViewBuilder
    private func contentView(diagnostics: [MarkdownLintDiagnostic]) -> some View {
        if diagnostics.isEmpty {
            Text("No Markdown diagnostics").foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(diagnostics.prefix(MarkdownLintAndFormatEngine.maxDiagnostics).enumerated()), id: \.offset) { _, diagnostic in
                        rowView(diagnostic)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
    }

    private func rowView(_ diagnostic: MarkdownLintDiagnostic) -> some View {
        HStack(spacing: 6) {
            Image(systemName: diagnostic.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .accessibilityLabel(diagnostic.severity == .error ? "Error" : "Warning")
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
#endif
