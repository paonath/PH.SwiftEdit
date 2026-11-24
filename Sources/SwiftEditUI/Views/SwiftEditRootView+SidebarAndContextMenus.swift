import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Workspace folder sidebar, context menus, and inline create/rename prompts for `SwiftEditRootView` (`UI-001`, `SEC-003`).
extension SwiftEditRootView {
    var sidebarView: some View {
        let metrics = model.chromeMetrics
        let sidebarFont = metrics.navigatorFontSize
        let headerFont = metrics.navigatorHeaderFontSize
        let rowSpacing = max(4, CGFloat(6.0 * model.zoomController.zoomScaleFactor))

        return VStack(alignment: .leading, spacing: rowSpacing) {
            HStack(spacing: 8) {
                Text((model.selectedFolderURL?.lastPathComponent ?? "No Folder Open").uppercased())
                    .appFont(size: headerFont, weight: .semibold)
                    .tracking(0.6)
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    .lineLimit(1)
                Spacer()
                if model.selectedFolderURL != nil {
                    Button(action: { model.navigateToParentFolder() }) {
                        AppIconView(.folderUp, size: headerFont + 3)
                            .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                            .minimumHitTarget()
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canNavigateToParentFolder)
                    .help("Go to parent folder (...)")
                    .accessibilityLabel("Go to parent folder")
                }
                Button(action: { model.toggleSidebarPinCollapse() }) {
                    AppIconView(.sidebar, size: headerFont + 3)
                        .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                        .minimumHitTarget()
                }
                .buttonStyle(.plain)
                .help("Unpin and Collapse Left Navigation Panel (Cmd+B)")
                .accessibilityLabel("Collapse left navigation panel")
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            if model.selectedFolderURL == nil {
                sidebarEmptyState
            }
            List {
                if model.canNavigateToParentFolder {
                    Button(action: { model.navigateToParentFolder() }) {
                        HStack(spacing: rowSpacing) {
                            AppIconView(.folderUp, size: metrics.navigatorIconSize + 1)
                                .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                            Text("...")
                                .appFont(size: sidebarFont, weight: .semibold)
                                .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Parent folder")
                }
                ForEach(model.folderEntries, id: \.url) { entry in
                    let binaryColor = model.palette.sidebarBinaryDisabledText.swiftUIColor
                    let icon: AppIcon = entry.isDirectory
                        ? .folder
                        : (entry.isBinary ? .fileBinary : (entry.isHiddenDotfile ? .eyeOff : .fileText))
                    let isSelected = model.selectedSidebarEntryURL == entry.url.standardizedFileURL
                    HStack(spacing: rowSpacing) {
                        AppIconView(icon, size: metrics.navigatorIconSize + 1)
                            .foregroundStyle(entry.isBinary ? binaryColor : (entry.isDirectory ? model.palette.chromeAccent : model.palette.secondaryForeground).swiftUIColor)
                        Text(entry.name)
                            .appFont(size: sidebarFont)
                            .foregroundStyle(entry.isBinary ? binaryColor : model.palette.chromeForeground.swiftUIColor)
                            .italic(entry.isBinary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: metrics.navigatorRowHeight, alignment: .leading)
                    .padding(.leading, max(0, metrics.navigatorIndent - 12))
                    .background(isSelected ? model.palette.accentSoftSurface.swiftUIColor : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { model.sidebarDoubleClick(entry) }
                    .onTapGesture(count: 1) { model.sidebarPrimaryClick(entry) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(entry.name)
                    .accessibilityAction(named: entry.isDirectory ? "Open Folder" : "Open File") {
                        model.sidebarDoubleClick(entry)
                    }
                    .help(entry.isDirectory
                        ? "Double-click to open folder"
                        : (entry.isBinary ? "Binary file (read-only disabled in sidebar)" : entry.name))
                    .contextMenu {
                        sidebarEntryContextMenu(for: entry)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .contextMenu {
                sidebarBackgroundContextMenu
            }
        }
        .background(model.palette.sidebarSurface.swiftUIColor)
        .contextMenu {
            sidebarBackgroundContextMenu
        }
    }

    /// Empty Folder Navigator: one clear call to action instead of a bare "No Folder Open" label (R-08).
    var sidebarEmptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Open a folder to browse its files.")
                .appFont(.callout)
                .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
            Button(action: { model.openFolderViaPanel() }) {
                HStack(spacing: 6) {
                    AppIconView(.folder, size: 13)
                    Text("Open Folder…")
                        .appFont(.callout, weight: .medium)
                    Spacer(minLength: 4)
                    Text(verbatim: "⇧⌘O")
                        .appFont(.caption, monospaced: true)
                        .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                }
                .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(model.palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Folder")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    @ViewBuilder
    func sidebarEntryContextMenu(for entry: FolderEntryDescriptor) -> some View {
        let targetDir = model.resolveSidebarCreationDirectory(for: entry)
        Button("Reveal in Finder") { model.sidebarRevealInFinder(at: entry.url) }
        if entry.isDirectory {
            Button("Open Folder in Finder") { model.sidebarOpenFolderInFinder(at: entry.url) }
        } else if let currentFolder = model.selectedFolderURL {
            Button("Open Folder in Finder") { model.sidebarOpenFolderInFinder(at: currentFolder) }
        }
        Button("Open Terminal") { model.sidebarOpenInTerminal(at: entry.url) }
        Button("Copy Path to Clipboard") { model.sidebarCopyPathToClipboard(at: entry.url) }
        Divider()
        Button("New File…") { promptCreateFile(in: targetDir) }
            .disabled(targetDir == nil)
        Button("New Folder…") { promptCreateFolder(in: targetDir) }
            .disabled(targetDir == nil)
        Divider()
        if !entry.isBinary {
            Button("Cut") { model.sidebarCutItem(at: entry.url) }
            Button("Copy") { model.sidebarCopyItem(at: entry.url) }
            Button("Paste") { _ = model.sidebarPasteItem(into: targetDir) }
                .disabled(model.sidebarClipboard == nil)
            Divider()
            Button(entry.isDirectory ? "Rename Folder…" : "Rename File…") {
                promptInlineRename(for: entry)
            }
        }
        Button("Delete (Move to Trash)", role: .destructive) {
            model.requestSidebarTrashItem(at: entry.url)
        }
    }

    @ViewBuilder
    var sidebarBackgroundContextMenu: some View {
        let targetDir = model.resolveSidebarCreationDirectory(for: nil)
        Button("New File…") { promptCreateFile(in: targetDir) }
            .disabled(targetDir == nil)
        Button("New Folder…") { promptCreateFolder(in: targetDir) }
            .disabled(targetDir == nil)
        Divider()
        Button("Paste") { _ = model.sidebarPasteItem(into: targetDir) }
            .disabled(model.sidebarClipboard == nil || targetDir == nil)
        if let currentFolder = targetDir {
            Divider()
            Button("Open Folder in Finder") { model.sidebarOpenFolderInFinder(at: currentFolder) }
            Button("Open Terminal") { model.sidebarOpenInTerminal(at: currentFolder) }
            Button("Copy Folder Path to Clipboard") { model.sidebarCopyPathToClipboard(at: currentFolder) }
        }
    }

    /// Prompts for a single-segment name validated via `SidebarItemNameValidator` and creates a new file inside `directory` (`CWE-22`, `BC-012`, `SEC-003`).
    func promptCreateFile(in directory: URL?) {
        guard let directory,
              let name = promptSingleSegmentName(
                title: "New File",
                message: "Enter a single-segment filename to create in \"\(directory.lastPathComponent)\":",
                defaultValue: "Untitled.md",
                confirmTitle: "Create"
              ) else {
            return
        }
        if let created = model.sidebarCreateFile(named: name, in: directory) {
            model.openFile(at: created, withinScope: model.grantedScopeRootURL ?? directory)
        }
    }

    /// Prompts for a single-segment name validated via `SidebarItemNameValidator` and creates a new folder inside `directory` (`CWE-22`, `BC-012`, `SEC-003`).
    func promptCreateFolder(in directory: URL?) {
        guard let directory,
              let name = promptSingleSegmentName(
                title: "New Folder",
                message: "Enter a single-segment folder name to create in \"\(directory.lastPathComponent)\":",
                defaultValue: "New Folder",
                confirmTitle: "Create"
              ) else {
            return
        }
        _ = model.sidebarCreateFolder(named: name, in: directory)
    }

    func promptInlineRename(for entry: FolderEntryDescriptor) {
        guard let newName = promptSingleSegmentName(
            title: entry.isDirectory ? "Rename Folder" : "Rename File",
            message: "Enter a new single-segment name:",
            defaultValue: entry.name,
            confirmTitle: "Rename"
        ) else {
            return
        }
        _ = model.sidebarRenameItem(at: entry.url, to: newName)
    }

    func promptSingleSegmentName(
        title: String,
        message: String,
        defaultValue: String,
        confirmTitle: String
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.stringValue = defaultValue
        alert.accessoryView = input
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        return input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }


}

#endif
