import SwiftUI
import UniformTypeIdentifiers

struct DeckPane: View {
    @Environment(HostController.self) private var host
    @Environment(Preferences.self) private var preferences
    @State private var summary = ""
    @State private var deckHash: Int?
    @State private var error: String?
    @State private var confirmReset = false
    @State private var confirmShell = false

    var body: some View {
        Form {
            Section {
                Text("快捷面板是手机上的按钮网格，可用于打开应用、触发快捷指令、输入文字等。要修改它，请在手机的“快捷面板”标签页点按“编辑”。所有配对设备共享同一个快捷面板。")
                    .fixedSize(horizontal: false, vertical: true)
                LabeledContent("当前快捷面板", value: summary)
            }

            Section("备份") {
                LabeledContent {
                    HStack {
                        Button("导入…", action: importDeck)
                        Button("导出…", action: exportDeck)
                    }
                } label: {
                    Text("快捷面板文件")
                    Text("导出副本或导入文件。导入会替换所有设备上的快捷面板。")
                }
                LabeledContent {
                    Button("重置…", role: .destructive) { confirmReset = true }
                } label: {
                    Text("恢复默认快捷面板")
                    Text("将替换所有页面和按钮。")
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Shell 命令") {
                DescribedToggle(
                    "允许按钮运行 Shell 命令",
                    detail: "按钮可以以你的用户账户运行任意命令，并打开指向文件、终端和文件服务器的链接。只有在信任所有配对设备时才打开此选项。",
                    isOn: Binding(
                        get: { preferences.allowShell },
                        set: { newValue in
                            if newValue { confirmShell = true } else { preferences.allowShell = false }
                        }
                    )
                )
            }
        }
        .settingsForm()
        .task {
            // Phones edit the deck too, and the core sends no event for that.
            while !Task.isCancelled {
                refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .confirmationDialog("重置快捷面板？", isPresented: $confirmReset) {
            Button("重置快捷面板", role: .destructive) {
                Task {
                    await host.resetDeck()
                    refresh()
                }
            }
        } message: {
            Text("所有设备上的每个页面和按钮都会被替换为默认设置。请先导出以保留副本。")
        }
        .confirmationDialog("允许 Shell 命令？", isPresented: $confirmShell) {
            Button("允许 Shell 命令", role: .destructive) { preferences.allowShell = true }
        } message: {
            Text("快捷面板按钮将能够运行命令，并完全访问你的文件。配对设备可以创建此类按钮。")
        }
    }

    private func refresh() {
        let json = host.deckJSON()
        guard json.hashValue != deckHash else { return }
        deckHash = json.hashValue
        guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let pages = object["pages"] as? [[String: Any]]
        else {
            summary = ""
            return
        }
        let tiles = pages.reduce(0) { $0 + (($1["tiles"] as? [Any])?.count ?? 0) }
        let pageText = pages.count == 1 ? "1 个页面" : "\(pages.count) 个页面"
        let tileText = tiles == 1 ? "1 个按钮" : "\(tiles) 个按钮"
        summary = "\(pageText)，\(tileText)"
    }

    private func exportDeck() {
        error = nil
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "CmdPalm Deck.json"
        panel.allowedContentTypes = [.json]
        let json = host.deckJSON()
        AppActivation.shared.present {
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                try Data(json.utf8).write(to: url, options: .atomic)
            } catch {
                self.error = "无法保存快捷面板：\(error.localizedDescription)"
            }
        }
    }

    private func importDeck() {
        error = nil
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        AppActivation.shared.present {
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                // Checked before reading, so picking a huge file can't stall the app.
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                let data = size < 2_000_000 ? try Data(contentsOf: url) : Data()
                guard !data.isEmpty, data.count < 2_000_000, let json = String(data: data, encoding: .utf8) else {
                    self.error = "该文件不是 CmdPalm 快捷面板文件。"
                    return
                }
                Task {
                    do {
                        try await host.importDeck(json)
                        refresh()
                    } catch let failure as HostError {
                        if case let .Failed(message) = failure { self.error = "无法导入快捷面板：\(message)" }
                    } catch {
                        self.error = "无法导入快捷面板：\(error.localizedDescription)"
                    }
                }
            } catch {
                self.error = "无法读取文件：\(error.localizedDescription)"
            }
        }
    }
}
