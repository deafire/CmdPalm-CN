import AppKit
import SwiftUI

/// Extra folders for the phone's app list, such as apps kept on an external drive.
struct AppFoldersSection: View {
    @Environment(Preferences.self) private var preferences
    /// Path → app count, or nil while the folder is unavailable.
    @State private var counts: [String: Int?] = [:]

    var body: some View {
        Section {
            ForEach(preferences.appFolders, id: \.self) { path in
                FolderRow(path: path, count: counts[path] ?? .some(-1)) {
                    preferences.removeAppFolder(path)
                }
            }
            LabeledContent {
                Button("添加文件夹…", action: choose)
                    .disabled(preferences.appFolders.count >= Preferences.maxAppFolders)
            } label: {
                Text("手机会在“应用程序”中列出应用。添加其他文件夹（例如外接磁盘上的文件夹），即可同时列出其中的应用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("应用文件夹")
        }
        .task(id: preferences.appFolders) { await count() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in
            Task { await count() }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in
            Task { await count() }
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "添加"
        panel.message = "选择包含应用的文件夹。"
        panel.directoryURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { preferences.addAppFolder(url) }
    }

    private func count() async {
        let paths = preferences.appFolders
        let result = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: paths.map { path in
                (path, AppCatalog.apps(in: URL(fileURLWithPath: path, isDirectory: true)).map(\.count))
            })
        }.value
        // A slower scan of an older folder list must not replace a newer one.
        guard !Task.isCancelled, paths == preferences.appFolders else { return }
        counts = result
    }
}

private struct FolderRow: View {
    let path: String
    /// -1 while counting, nil when the folder cannot be found.
    let count: Int?
    let remove: () -> Void

    var body: some View {
        LabeledContent {
            Button(role: .destructive, action: remove) {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("移除此文件夹")
            .accessibilityLabel("移除 \(FileManager.default.displayName(atPath: path))")
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(FileManager.default.displayName(atPath: path))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(count == nil ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } icon: {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 20, height: 20)
            }
        }
        .contextMenu {
            Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
                .disabled(count == nil)
        }
    }

    private var detail: String {
        let shown = (path as NSString).abbreviatingWithTildeInPath
        switch count {
        case nil: return "不可用。连接磁盘后即可列出其中的应用。· \(shown)"
        case -1: return shown
        case 1: return "1 个应用 · \(shown)"
        case let n?: return "\(n) 个应用 · \(shown)"
        }
    }
}
