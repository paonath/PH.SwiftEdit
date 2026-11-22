#if os(macOS)
import SwiftEditCore
import SwiftUI

/// In-app documentation (Help → SwiftEdit Help): the bundled README rendered offline by the native Markdown preview.
enum HelpDocumentation {
    /// Bundled README text, or `nil` when the resource is missing.
    static func readme() -> String? {
        guard let url = Bundle.module.url(forResource: "README", withExtension: "md", subdirectory: "Help") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Preview projection of the README (images are not loaded: there is no granted folder scope).
    static func document() -> GFMPreviewDocument? {
        guard let text = readme() else { return nil }
        return MarkdownPreviewProjector.project(snapshot: DocumentSession(text: text).snapshot, showPreview: true)
    }
}

struct HelpDocumentationView: View {
    let palette: PurpleThemePalette
    let onClose: () -> Void
    @State private var document: GFMPreviewDocument? = HelpDocumentation.document()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SwiftEdit Help").appFont(.headline)
                Spacer()
                Button("Done", action: onClose).keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            if document != nil {
                MarkdownNativePreviewView(document: document, palette: palette, gate: nil, activeSourceLine: 0)
            } else {
                Text("The help document is not available in this build.").padding(24)
            }
        }
        .frame(minWidth: 640, idealWidth: 760, minHeight: 520, idealHeight: 680)
        .background(palette.editorCanvasBackground.swiftUIColor)
        .accessibilityLabel("SwiftEdit Help")
    }
}
#endif
