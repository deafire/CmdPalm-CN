import SwiftUI

struct AdvancedPane: View {
    @Environment(HostController.self) private var host
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section("服务器") {
                LabeledContent("状态") {
                    HStack(spacing: 6) {
                        StatusDot(color: statusColor)
                        Text(statusText)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                }
                if let pairing = host.pairing, host.isRunning, !pairing.addresses.isEmpty {
                    LabeledContent(pairing.addresses.count == 1 ? "IP 地址" : "IP 地址") {
                        Text(pairing.addresses.map { pairing.vpnAddresses.contains($0) ? "\($0) (VPN)" : $0 }.joined(separator: "\n"))
                            .font(.body.monospaced())
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                }
                DescribedToggle(
                    "接受通过这台 Mac 上的代理建立的连接",
                    detail: "仅适用于你在这台 Mac 上运行的反向代理，例如 Caddy、nginx 或 VPN 的 HTTPS 共享。启用后，CmdPalm 会信任代理提供的设备信息和加密状态。其他情况请保持关闭。",
                    isOn: $preferences.allowLocalProxy
                )
                LabeledContent {
                    Button("重启服务器") { host.restart() }
                } label: {
                    Text("重启服务器")
                    Text("所有设备会短暂断开，然后自动重新连接。")
                }
            }

            Section("故障排查") {
                Picker(selection: $preferences.logLevel) {
                    ForEach(Preferences.LogLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                } label: {
                    Text("日志详细程度")
                    Text("下次打开 CmdPalm 时生效。")
                }
                LabeledContent {
                    HStack {
                        Button("显示日志") {
                            NSWorkspace.shared.activateFileViewerSelecting([SystemInfo.logFile])
                        }
                        Button("显示数据文件夹") {
                            NSWorkspace.shared.open(SystemInfo.dataDirectory)
                        }
                    }
                } label: {
                    Text("文件")
                    Text("日志中绝不会包含你输入的内容。")
                }
                LabeledContent {
                    Button("显示使用指南") { WelcomeWindowController.show() }
                } label: {
                    Text("欢迎指南")
                    Text("重新引导你完成权限设置和配对。")
                }
            }
        }
        .settingsForm()
    }

    private var statusText: String {
        switch host.status {
        case .starting: "正在启动…"
        case .stopped: "已停止"
        case let .failed(message): "无法启动：\(message)"
        case let .running(port): host.paused ? "已在端口 \(String(port)) 上暂停" : "正在端口 \(String(port)) 上运行"
        }
    }

    private var statusColor: Color {
        switch host.status {
        case .running: host.paused ? .orange : .green
        case .starting: .yellow
        case .stopped: .gray
        case .failed: .red
        }
    }
}
