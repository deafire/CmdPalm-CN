import Speech
import SwiftUI

struct GeneralPane: View {
    @Environment(HostController.self) private var host
    @Environment(Preferences.self) private var preferences
    @Environment(Permissions.self) private var permissions
    @Environment(LoginItem.self) private var loginItem
    @Environment(Updater.self) private var updater

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                DescribedToggle(
                    "允许设备控制",
                    detail: "关闭后可停止所有设备的输入和屏幕镜像，而无需断开设备。",
                    isOn: Binding(get: { !host.paused }, set: { host.setPaused(!$0) })
                )
                .disabled(!host.isRunning)
                DescribedToggle(
                    "登录时打开",
                    detail: "登录时在菜单栏启动 CmdPalm。",
                    isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.set($0) })
                )
                if loginItem.needsApproval {
                    LabeledContent("只有在“登录项”中允许后，CmdPalm 才会在登录时打开。") {
                        Button("打开登录项") { loginItem.openSettings() }
                    }
                    .font(.caption)
                }
                if let error = loginItem.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section("权限") {
                PermissionRow(
                    title: "辅助功能",
                    detail: "允许 CmdPalm 移动指针、点击和输入。必需。",
                    granted: permissions.canControl,
                    action: "打开设置…"
                ) { permissions.requestControl() }
                if !permissions.canControl {
                    Text("如果 CmdPalm 已在列表中且已打开，请选中它，用“–”按钮移除后重新添加。更新到签名不同的版本后可能出现这种情况。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PermissionRow(
                    title: "语音识别",
                    detail: "将手机麦克风中的语音转换为文字。可选。",
                    granted: permissions.speech == .authorized,
                    action: permissions.speech == .notDetermined ? "允许…" : "打开设置…"
                ) { permissions.requestSpeech() }
            }

            Section("语音输入") {
                DescribedToggle(
                    "允许设备使用语音输入",
                    detail: "手机会将麦克风的音频流式传输到这台 Mac，由 Mac 进行转写。语音不会发送到其他任何地方。需要“手机设置”中的加密连接。",
                    isOn: $preferences.voiceEnabled
                )
            }

            Section {
                DescribedToggle(
                    "允许屏幕镜像",
                    detail: "在你允许的设备上显示 Mac 屏幕。离开手机上的“屏幕镜像”标签页后会停止捕获。",
                    isOn: $preferences.displayEnabled
                )
                PermissionRow(
                    title: "屏幕录制",
                    detail: "查看屏幕所必需。授予权限后，macOS 可能会要求你重新打开 CmdPalm。",
                    granted: permissions.canView,
                    action: "允许 / 打开设置…"
                ) { permissions.requestViewing() }
                Button("管理设备访问权限…") { SettingsNavigation.shared.selection = .devices }
                    .help("选择哪些已配对或已连接的设备可以查看屏幕")
            } header: {
                Text("屏幕镜像")
            } footer: {
                Text("设备查看期间，Mac 屏幕会保持唤醒。锁定或让 Mac 进入睡眠会停止镜像。视频通过 HTTP 和 HTTPS 加密传输。使用 HTTPS 还可保护网页和连接设置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AppFoldersSection()

            Section("更新") {
                if updater.isConfigured {
                    Toggle("自动检查更新", isOn: Binding(get: { updater.automaticallyChecks }, set: { updater.automaticallyChecks = $0 }))
                    Toggle("自动下载并安装更新", isOn: Binding(get: { updater.automaticallyDownloads }, set: { updater.automaticallyDownloads = $0 }))
                        .disabled(!updater.automaticallyChecks)
                    LabeledContent {
                        Button("立即检查") { updater.checkForUpdates() }
                            .disabled(!updater.canCheck)
                    } label: {
                        Text("版本 \(SystemInfo.appVersion)")
                        if let last = updater.lastChecked {
                            Text("上次检查：\(last.formatted(.relative(presentation: .named)))")
                        }
                    }
                } else {
                    LabeledContent("版本 \(SystemInfo.appVersion)") {
                        Text("开发版本中未启用更新。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .settingsForm()
        .onAppear {
            loginItem.refresh()
            permissions.refresh()
        }
    }
}
