import SwiftUI

struct WelcomeView: View {
    @Environment(HostController.self) private var host
    @Environment(Permissions.self) private var permissions
    @State private var step = Step.intro
    @State private var pairedAtStart: String?

    enum Step: Int, CaseIterable {
        case intro, permission, screenRecording, connect
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .intro: intro
                case .permission: permission
                case .screenRecording: screenRecording
                case .connect: connect
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
            .padding(.top, 36)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(step)

            footer
                .padding(20)
        }
        .frame(width: 560, height: 600)
        .animation(.snappy(duration: 0.25), value: step)
        .onAppear { pairedAtStart = host.lastPaired }
    }

    private var intro: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("欢迎使用 CmdPalm")
                .font(.largeTitle.bold())
            Text("用手机或 iPad 查看并控制这台 Mac。屏幕镜像、触控板、键盘和快捷面板，手机端无需安装任何应用。")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12) {
                Feature(symbol: "display", title: "屏幕镜像", detail: "在触控板或键盘上方查看 Mac 屏幕。")
                Feature(symbol: "hand.point.up.left", title: "触控板", detail: "用熟悉的手势点击、拖动、滚动和捏合。")
                Feature(symbol: "keyboard", title: "键盘", detail: "输入、语音输入和按下任意快捷键，修饰键可保持按下。")
                Feature(symbol: "square.grid.3x2", title: "快捷面板", detail: "为应用、快捷指令、媒体和文本片段设置按钮。")
            }
            .padding(.top, 6)
        }
    }

    private var permission: some View {
        VStack(spacing: 18) {
            Image(systemName: permissions.canControl ? "checkmark.shield.fill" : "hand.raised.fill")
                .font(.system(size: 56))
                .foregroundStyle(permissions.canControl ? .green : .orange)
                .contentTransition(.symbolEffect(.replace))
            Text(permissions.canControl ? "CmdPalm 可以控制这台 Mac" : "允许 CmdPalm 控制这台 Mac")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("任何应用移动指针或输入前，macOS 都会先询问。CmdPalm 仅对你配对的设备执行这些操作。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !permissions.canControl {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. 点按“打开系统设置”。")
                    Text("2. 在“辅助功能”中打开 CmdPalm。可能需要输入密码。")
                    Text("3. 返回这里，此页面会自动更新。")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button("打开系统设置") { permissions.requestControl() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }

    private var screenRecording: some View {
        VStack(spacing: 18) {
            Image(systemName: permissions.canView ? "checkmark.shield.fill" : "display")
                .font(.system(size: 56))
                .foregroundStyle(permissions.canView ? .green : .orange)
                .contentTransition(.symbolEffect(.replace))
            Text(permissions.canView ? "已允许屏幕录制" : "设置屏幕镜像")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("屏幕录制权限允许屏幕镜像在手机上显示这台 Mac 的屏幕。你也可以稍后在“设置 → 通用 → 屏幕镜像”中设置。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !permissions.canView {
                Text("在“系统设置 → 隐私与安全性 → 屏幕录制与系统音频录制”中打开 CmdPalm。返回这里；如果 macOS 提示，请重新打开 CmdPalm。")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .fixedSize(horizontal: false, vertical: true)
                Button("允许屏幕录制…") { permissions.requestViewing() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            Text("要开始查看，请在“通用”中启用“允许屏幕镜像”，并在“设备”中授予手机屏幕访问权限。CmdPalm 不会保存任何屏幕录制内容。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var connect: some View {
        VStack(spacing: 14) {
            if let name = host.lastPaired, name != pairedAtStart {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("\(name) 已连接")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("提示：将 CmdPalm 添加到手机的主屏幕（iPhone 上为“分享 → 添加到主屏幕”，Android 上在浏览器菜单中），即可像应用一样打开。CmdPalm 位于菜单栏，点按图标可配对更多设备。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("连接手机")
                    .font(.title.bold())
                Text("连接到这台 Mac 所在的 Wi-Fi，然后用手机相机扫描二维码。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                PairingCard(qrSize: 168)
                    .frame(width: 300)
            }
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { item in
                    Circle()
                        .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)
            Spacer()
            if step != .intro {
                Button("返回") { step = Step(rawValue: step.rawValue - 1) ?? .intro }
            }
            Button(primaryTitle, action: advance)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
    }

    private var primaryTitle: String {
        switch step {
        case .intro: "开始使用"
        case .permission: permissions.canControl ? "继续" : "稍后"
        case .screenRecording: permissions.canView ? "继续" : "暂时跳过"
        case .connect: host.lastPaired != pairedAtStart && host.lastPaired != nil ? "完成" : "完成"
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        } else {
            WelcomeWindowController.close()
        }
    }
}

private struct Feature: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }
}
