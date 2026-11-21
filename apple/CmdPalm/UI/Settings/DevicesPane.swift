import SwiftUI

struct DevicesPane: View {
    @Environment(HostController.self) private var host
    @Environment(Preferences.self) private var preferences
    @Environment(Permissions.self) private var permissions
    @State private var confirmForgetAll = false

    var body: some View {
        Form {
            Section("屏幕镜像") {
                VStack(alignment: .leading, spacing: 8) {
                    if !preferences.displayEnabled {
                        Label("这台 Mac 上的屏幕镜像已关闭", systemImage: "display")
                    } else if !permissions.canView {
                        Label("需要屏幕录制权限", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                    } else {
                        Label("可以共享屏幕", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Text("为下方每台设备打开“允许屏幕镜像”。没有此权限的设备仍可使用触控板和键盘。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        if preferences.displayEnabled && !permissions.canView {
                            Button("允许屏幕录制…") { permissions.requestViewing() }
                                .fixedSize()
                        }
                        Button("屏幕镜像设置…") { SettingsNavigation.shared.selection = .general }
                            .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            Section("当前已连接") {
                if host.connected.isEmpty {
                    Text("当前没有已连接的设备。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(host.connected, id: \.session) { device in
                        ConnectedSettingsRow(device: device)
                    }
                }
            }

            Section {
                if host.trusted.isEmpty {
                    Text("配对的设备会显示在这里。在移除之前，它们无需验证码即可重新连接。")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(host.trusted, id: \.id) { device in
                        TrustedDeviceRow(device: device, session: host.connected.first { $0.remembered && $0.deviceId == device.id })
                    }
                }
            } header: {
                Text("已配对设备")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("每台设备的手机设置（如自定义键盘和手势）都保存在这台 Mac 上，移除设备时会被删除。")
                        .fixedSize(horizontal: false, vertical: true)
                    if !host.trusted.isEmpty {
                        HStack {
                            Spacer()
                            Button("全部移除…", role: .destructive) { confirmForgetAll = true }
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .settingsForm()
        .confirmationDialog("移除所有已配对设备？", isPresented: $confirmForgetAll) {
            Button("全部移除", role: .destructive) { host.forgetAllDevices() }
        } message: {
            Text("这些设备将被断开，必须使用二维码、PIN 或批准重新配对。它们在这台 Mac 上保存的手机设置将被删除。")
        }
    }
}

private struct ConnectedSettingsRow: View {
    @Environment(HostController.self) private var host
    let device: ConnectedDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ConnectedDeviceLabel(device: device)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    .accessibilityElement(children: .combine)
                Button("断开") { host.disconnect(device) }
                    .fixedSize()
                    .help("断开此设备；它可从手机重新连接")
            }
            DeviceScreenAccessRow(name: device.name, temporary: !device.remembered, allowed: Binding(
                get: { device.displayAllowed },
                set: {
                    if device.remembered { host.setDisplayAllowed(device.deviceId, allowed: $0) }
                    else { host.setTemporaryDisplayAllowed(device.session, allowed: $0) }
                }
            ))
            .padding(.leading, 38)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrustedDeviceRow: View {
    @Environment(HostController.self) private var host
    let device: TrustedDevice
    let session: ConnectedDevice?
    @State private var name = ""
    @State private var renaming = false
    @State private var confirmForget = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                DeviceIcon(model: device.model, online: session != nil)
                    .help(session != nil ? "已连接" : "未连接")
                VStack(alignment: .leading, spacing: 3) {
                    nameField
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                Button("移除…") { confirmForget = true }
                    .fixedSize()
            }
            DeviceScreenAccessRow(name: device.name, allowed: Binding(get: { device.displayAllowed }, set: { host.setDisplayAllowed(device.id, allowed: $0) }))
                .padding(.leading, 38)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button("重命名") { startRenaming() }
            if let session {
                Button("断开") { host.disconnect(session) }
            }
            Divider()
            Button("移除…", role: .destructive) { confirmForget = true }
        }
        .onAppear { name = device.name }
        .onChange(of: device.name) { _, new in if !renaming { name = new } }
        .confirmationDialog("移除“\(device.name)”？", isPresented: $confirmForget) {
            Button("移除设备", role: .destructive) { host.forget(device) }
        } message: {
            Text(DeviceText.removeMessage)
        }
    }

    @ViewBuilder
    private var nameField: some View {
        if renaming {
            TextField("名称", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
                .focused($nameFocused)
                .onSubmit(commit)
                .onExitCommand {
                    name = device.name
                    renaming = false
                }
                .onChange(of: nameFocused) { _, focused in
                    if !focused { commit() }
                }
                .onAppear { nameFocused = true }
        } else {
            HStack(spacing: 4) {
                Text(device.name)
                    .lineLimit(1)
                    .help(device.name)
                Button(action: startRenaming) {
                    Image(systemName: "pencil")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("重命名")
                .accessibilityLabel("重命名 \(device.name)")
            }
        }
    }

    private func startRenaming() {
        name = device.name
        renaming = true
    }

    private func commit() {
        guard renaming else { return }
        renaming = false
        host.rename(device, to: name)
    }

    private var detail: String {
        var parts: [String] = []
        if !device.model.isEmpty { parts.append(device.model) }
        if session != nil {
            parts.append("已连接")
        } else if device.lastSeen > 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(device.lastSeen))
            parts.append("上次使用：\(date.formatted(.relative(presentation: .named)))")
        }
        let paired = Date(timeIntervalSince1970: TimeInterval(device.pairedAt))
        parts.append("配对于 \(paired.formatted(date: .abbreviated, time: .omitted))")
        return parts.joined(separator: " · ")
    }
}

/// A separate line keeps the form's toggle label sizing from squeezing the
/// device name or destructive action, even at the minimum window width.
private struct DeviceScreenAccessRow: View {
    let name: String
    var temporary = false
    @Binding var allowed: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("允许屏幕镜像")
                Text(temporary ? "仅此次连接" : (allowed ? "屏幕镜像开启时允许" : "此设备的屏幕镜像已关闭"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("允许 \(name) 使用屏幕镜像", isOn: $allowed)
                .labelsHidden()
                .toggleStyle(.switch)
                .fixedSize()
                .accessibilityLabel("允许 \(name) 使用屏幕镜像")
        }
    }
}
