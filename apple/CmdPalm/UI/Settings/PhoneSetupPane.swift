import SwiftUI
import UniformTypeIdentifiers

struct PhoneSetupPane: View {
    @Environment(HostController.self) private var host
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Step(1, "连接到这台 Mac 所在的 Wi-Fi 网络。")
                    Step(2, "用手机相机扫描二维码，或在手机浏览器中输入地址并输入 PIN。")
                    Step(3, "将 CmdPalm 添加到主屏幕即可全屏使用：iPhone 和 iPad 上为“分享 → 添加到主屏幕”，Android 上在浏览器菜单中添加。")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                PairingCard(qrSize: 180)
                    .frame(maxWidth: 320)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } header: {
                Text("连接设备")
            }

            Section("配对") {
                DescribedToggle(
                    "允许使用 PIN 配对",
                    detail: "设备可输入二维码旁边显示的六位 PIN 进行配对。PIN 仅在此处显示期间及之后几分钟内有效。扫描二维码始终可用。",
                    isOn: $preferences.allowPin
                )
                DescribedToggle(
                    "允许设备请求配对",
                    detail: "设备无需验证码即可请求访问，由你在这台 Mac 上批准。",
                    isOn: $preferences.allowApproval
                )
            }

            Section("网络") {
                Picker(selection: $preferences.linkAddress) {
                    ForEach(Preferences.LinkAddress.allCases) { option in
                        Text(option.label(
                            hostName: SystemInfo.bonjourHostName,
                            addresses: host.pairing?.addresses ?? [],
                            custom: preferences.customLinkAddress
                        ))
                        .tag(option)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("二维码中的地址")
                        Text("IP 地址变化时，“Mac 名称”仍然可用。部分 Android 手机无法打开 .local 名称，可为它们选择“IP 地址”。“自定义”适用于你自己设置的 VPN 或代理。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if preferences.linkAddress == .custom {
                    CustomAddressField()
                }
                PortField()
            }

            EncryptedConnectionSection()
        }
        .settingsForm()
        .onAppear { if host.isRunning { host.refreshPairing() } }
    }
}

private struct Step: View {
    let number: Int
    let text: String

    init(_ number: Int, _ text: String) {
        self.number = number
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(.tint, in: Circle())
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PortField: View {
    @Environment(HostController.self) private var host
    @Environment(Preferences.self) private var preferences
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField("端口", text: $text, prompt: Text(String(Preferences.defaultPort)))
                    .labelsHidden()
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .onSubmit(apply)
                if parsed != preferences.port {
                    Button("应用", action: apply).disabled(parsed == nil)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("端口")
                Group {
                    if host.preferredPortTaken, let port = host.port {
                        Text("端口 \(String(preferences.port)) 已被其他应用占用，因此 CmdPalm 正在使用 \(String(port))。")
                    } else if parsed == nil, !text.isEmpty {
                        Text("请输入 1024 到 65535 之间的数字。").foregroundStyle(.red)
                    } else {
                        Text("设备通过此端口连接。修改后配对链接也会变化。")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear { text = String(preferences.port) }
    }

    private var parsed: Int? {
        Int(text.trimmingCharacters(in: .whitespaces)).flatMap(Preferences.validPort)
    }

    private func apply() {
        guard let port = parsed else { return }
        preferences.port = port
        focused = false
    }
}

private struct CustomAddressField: View {
    @Environment(HostController.self) private var host
    @Environment(Preferences.self) private var preferences
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField("自定义地址", text: $text, prompt: Text(verbatim: "mac.example.com"))
                    .labelsHidden()
                    .frame(minWidth: 180)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onSubmit(apply)
                if let addresses = host.pairing?.addresses, !addresses.isEmpty {
                    Menu {
                        ForEach(addresses, id: \.self) { address in
                            Button(menuTitle(address)) {
                                text = address
                                apply()
                            }
                        }
                    } label: {
                        Image(systemName: "network")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("使用这台 Mac 的某个地址")
                    .accessibilityLabel("使用这台 Mac 的某个地址")
                }
                if trimmed != preferences.customLinkAddress {
                    Button("应用", action: apply)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("自定义地址")
                Text("这台 Mac 的另一个地址，例如 VPN 地址、你自己的 DNS 中为这台 Mac 设置的名称，或你搭建的代理的 https 地址。未指定端口时，会自动加上 CmdPalm 的端口。CmdPalm 也接受使用该名称的连接。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { text = preferences.customLinkAddress }
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func menuTitle(_ address: String) -> String {
        host.pairing?.vpnAddresses.contains(address) == true ? "\(address) (VPN)" : address
    }

    private func apply() {
        preferences.customLinkAddress = trimmed
        focused = false
    }
}

/// Steps for trusting CmdPalm's certificate, which phones need before they
/// allow the microphone and other features on a local address.
private struct EncryptedConnectionSection: View {
    @Environment(HostController.self) private var host
    @State private var platform = Platform.apple

    enum Platform: String, CaseIterable, Identifiable {
        case apple, android
        var id: Self { self }
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("语音输入和部分手机功能只能通过加密（HTTPS）连接使用。在手机上一次性安装 CmdPalm 的证书即可启用。证书在这台 Mac 上生成，仅涵盖本地网络地址，绝不用于网站。")
                    .fixedSize(horizontal: false, vertical: true)
                Label("在 Android 上，要将 CmdPalm 作为应用安装（而非主屏幕快捷方式），需要加密连接，因为 Chrome 只通过 HTTPS 安装 Web 应用。",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("手机", selection: $platform) {
                Text("iPhone 和 iPad").tag(Platform.apple)
                Text("Android").tag(Platform.android)
            }
            .pickerStyle(.segmented)

            if let pairing = host.pairing, host.isRunning {
                let certificateLink = "\(pairing.address)/cmdpalm.crt"
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 6) {
                        QRCodeView(text: certificateLink, size: 110, label: "证书二维码")
                        Text("证书").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(steps(certificateLink).enumerated()), id: \.offset) { index, step in
                            Step(index + 1, step)
                        }
                    }
                }
                .padding(.vertical, 4)

                LabeledContent {
                    VStack(spacing: 6) {
                        QRCodeView(text: secureLink(pairing), size: 110)
                        Text("加密链接").font(.caption).foregroundStyle(.secondary)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("然后扫描此二维码，通过加密连接完成配对。")
                        AddressRow(address: pairing.secureAddress)
                        if !pairing.caFingerprint.isEmpty {
                            Text("SHA-256 指纹：\(pairing.caFingerprint)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            LabeledContent {
                Button("保存证书…", action: saveCertificate)
                    .disabled(!host.isRunning)
            } label: {
                Text("证书文件")
                Text("供无法扫描二维码的设备使用。")
            }
        } header: {
            Text("加密连接")
        }
    }

    private func steps(_ link: String) -> [String] {
        switch platform {
        case .apple:
            [
                "扫描证书二维码，或在 Safari 中打开 \(link)，然后点按“允许”。",
                "打开“设置 → 通用 → VPN 与设备管理”，选择 CmdPalm 描述文件并点按“安装”。",
                "打开“设置 → 通用 → 关于本机 → 证书信任设置”，打开 CmdPalm。",
            ]
        case .android:
            [
                "扫描证书二维码，或在 Chrome 中打开 \(link) 以下载证书。",
                "打开“设置 → 安全 → 更多安全设置 → 加密与凭据 → 安装证书 → CA 证书”。",
                "选择下载的 cmdpalm.crt 文件。",
            ]
        }
    }

    private func secureLink(_ pairing: PairingInfo) -> String {
        guard let fragment = pairing.link.range(of: "/#") else { return pairing.secureAddress }
        return pairing.secureAddress + pairing.link[fragment.lowerBound...]
    }

    private func saveCertificate() {
        let data = host.certificate()
        guard !data.isEmpty else {
            AppActivation.shared.present {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "证书不可用"
                alert.informativeText = "暂时无法加载 CmdPalm 的证书。请等待 CmdPalm 启动完成，或检查“加密连接”设置后重试。"
                alert.runModal()
            }
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "CmdPalm.crt"
        panel.allowedContentTypes = [UTType(filenameExtension: "crt") ?? .x509Certificate]
        AppActivation.shared.present {
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
