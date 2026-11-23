#if os(macOS)
import SwiftEditCore
import SwiftUI

/// Descriptor for one chapter of the bundled offline Help documentation.
struct HelpChapter: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let resourceName: String
    let subdirectory: String
}

/// In-app documentation (Help → SwiftEdit Help): bundled User Guide chapters and README rendered offline by the native Markdown preview.
enum HelpDocumentation {
    /// Ordered chapters bundled in `Sources/SwiftEditUI/Resources/Help/`.
    static let chapters: [HelpChapter] = [
        HelpChapter(id: "00-index", title: "Overview & Getting Started", resourceName: "00-index", subdirectory: "Help/guide"),
        HelpChapter(id: "01-workspace", title: "1. Workspace & Navigation", resourceName: "01-workspace-and-navigation", subdirectory: "Help/guide"),
        HelpChapter(id: "02-editing", title: "2. Editing & Highlighting", resourceName: "02-editing-and-highlighting", subdirectory: "Help/guide"),
        HelpChapter(id: "03-markdown-yaml", title: "3. Markdown & YAML", resourceName: "03-markdown-and-yaml", subdirectory: "Help/guide"),
        HelpChapter(id: "04-logs-terminal", title: "4. Logs & Terminal", resourceName: "04-logs-and-terminal", subdirectory: "Help/guide"),
        HelpChapter(id: "05-settings-shortcuts", title: "5. Settings, Shortcuts & Security", resourceName: "05-settings-shortcuts-and-security", subdirectory: "Help/guide"),
        HelpChapter(id: "readme", title: "Quick Reference (README)", resourceName: "README", subdirectory: "Help"),
    ]

    /// Bundled README text, or `nil` when the resource is missing.
    static func readme() -> String? {
        guard let url = Bundle.module.url(forResource: "README", withExtension: "md", subdirectory: "Help") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Raw Markdown text for `chapter`, or `nil` when the bundled resource is missing.
    static func markdown(for chapter: HelpChapter) -> String? {
        guard let url = Bundle.module.url(forResource: chapter.resourceName, withExtension: "md", subdirectory: chapter.subdirectory) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Preview projection of the README (preserved for existing callers and tests).
    static func document() -> GFMPreviewDocument? {
        guard let text = readme() else { return nil }
        return MarkdownPreviewProjector.project(snapshot: DocumentSession(text: text).snapshot, showPreview: true)
    }

    /// Preview projection of `chapter`, stripping leading YAML metadata frontmatter for clean in-app reading.
    static func document(for chapter: HelpChapter) -> GFMPreviewDocument? {
        guard let raw = markdown(for: chapter) else { return nil }
        let body = stripLeadingYAMLFrontmatter(from: raw)
        return MarkdownPreviewProjector.project(snapshot: DocumentSession(text: body).snapshot, showPreview: true)
    }

    /// Strips a leading `--- ... ---` YAML frontmatter block so the Help reader starts directly at the chapter heading.
    private static func stripLeadingYAMLFrontmatter(from text: String) -> String {
        guard text.hasPrefix("---\n") || text.hasPrefix("---\r\n") else { return text }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > 2 else { return text }
        for index in 1..<lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" || trimmed == "..." {
                return lines[(index + 1)...].joined(separator: "\n")
            }
        }
        return text
    }
}

struct HelpDocumentationView: View {
    let palette: PurpleThemePalette
    let onClose: () -> Void
    @State private var selectedChapterID: String = HelpDocumentation.chapters.first?.id ?? "readme"
    @State private var document: GFMPreviewDocument? = HelpDocumentation.chapters.first.flatMap { HelpDocumentation.document(for: $0) }
        ?? HelpDocumentation.document()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SwiftEdit Help").appFont(.headline)
                    .foregroundStyle(palette.chromeForeground.swiftUIColor)
                Spacer()
                Button("Done", action: onClose).keyboardShortcut(.cancelAction)
            }
            .padding(12)
            .background(palette.topBarSurface.swiftUIColor)
            Rectangle()
                .fill(palette.hairlineBorder.swiftUIColor)
                .frame(height: 1)
            HStack(spacing: 0) {
                chapterSidebar
                Rectangle()
                    .fill(palette.hairlineBorder.swiftUIColor)
                    .frame(width: 1)
                if document != nil {
                    MarkdownNativePreviewView(document: document, palette: palette, gate: nil, activeSourceLine: 0)
                        .id(selectedChapterID)
                } else {
                    Text("The help document is not available in this build.")
                        .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                }
            }
        }
        .frame(minWidth: 780, idealWidth: 940, minHeight: 560, idealHeight: 700)
        .background(palette.editorCanvasBackground.swiftUIColor)
        .accessibilityLabel("SwiftEdit Help")
    }

    private var chapterSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("DOCUMENTATION")
                    .appFont(.caption2, weight: .semibold)
                    .tracking(0.6)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                ForEach(HelpDocumentation.chapters) { chapter in
                    let isSelected = chapter.id == selectedChapterID
                    Button {
                        selectedChapterID = chapter.id
                        document = HelpDocumentation.document(for: chapter)
                    } label: {
                        Text(chapter.title)
                            .appFont(.callout, weight: isSelected ? .semibold : .regular)
                            .foregroundStyle((isSelected ? palette.chromeAccent : palette.chromeForeground).swiftUIColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isSelected ? palette.accentSoftSurface.swiftUIColor : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .frame(width: 230)
        .background(palette.sidebarSurface.swiftUIColor)
    }
}
#endif
