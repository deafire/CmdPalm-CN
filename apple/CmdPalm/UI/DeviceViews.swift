import AppKit
import SwiftUI

enum DeviceSymbol {
    static func name(for model: String) -> String {
        let model = model.lowercased()
        if model.contains("ipad") || model.contains("tablet") { return "ipad" }
        if model.contains("iphone") || model.contains("android") || model.contains("phone") { return "iphone" }
        if model.contains("mac") || model.contains("windows") || model.contains("linux") { return "laptopcomputer" }
        return "iphone"
    }
}

enum DeviceText {
    /// A fixed time rather than "5 minutes ago", so the row never needs a
    /// timer to stay correct.
    static func connectedSince(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "自 \(date.formatted(date: .omitted, time: .shortened)) 起"
        }
        return "自 \(date.formatted(.dateTime.month(.abbreviated).day())) 起"
    }

    static let removeMessage = "该设备已断开连接，必须使用二维码、PIN 或批准重新配对。它在这台 Mac 上保存的手机设置（如自定义键盘和手势）将被删除。"

    @MainActor
    static func confirmRemove(_ device: TrustedDevice, host: HostController) {
        let alert = NSAlert()
        alert.messageText = "移除“\(device.name)”？"
        alert.informativeText = removeMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: "移除设备").hasDestructiveAction = true
        alert.addButton(withTitle: "取消")
        if AppActivation.shared.present({ alert.runModal() }) == .alertFirstButtonReturn {
            host.forget(device)
        }
    }
}

struct DeviceIcon: View {
    let model: String
    var online = false

    var body: some View {
        Image(systemName: DeviceSymbol.name(for: model))
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 17))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if online {
                    StatusDot(color: .green)
                        .offset(x: 2, y: 2)
                }
            }
            .accessibilityHidden(true)
    }
}

/// A connected device in the menu bar panel. The disconnect button appears
/// on hover or keyboard focus to keep the list calm.
struct ConnectedDeviceRow: View {
    @Environment(HostController.self) private var host
    let device: ConnectedDevice
    @State private var hovering = false
    @FocusState private var buttonFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            ConnectedDeviceLabel(device: device)
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: "断开") { host.disconnect(device) }
            Spacer(minLength: 4)
            Button {
                host.disconnect(device)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .focused($buttonFocused)
            .opacity(hovering || buttonFocused ? 1 : 0)
            .help("断开 — 设备可从手机重新连接")
            .accessibilityLabel("断开 \(device.name)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .background(HoverBackground(active: hovering))
        .onHover { hovering = $0 }
        .contextMenu {
            Button("断开") { host.disconnect(device) }
            if device.remembered, let trusted = host.trusted.first(where: { $0.id == device.deviceId }) {
                Divider()
                Button("移除设备…") {
                    // Let the context menu finish closing before the modal alert starts.
                    Task { @MainActor in DeviceText.confirmRemove(trusted, host: host) }
                }
            }
        }
    }
}

struct ConnectedDeviceLabel: View {
    let device: ConnectedDevice

    var body: some View {
        HStack(spacing: 10) {
            DeviceIcon(model: device.model, online: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if device.secure {
                        Image(systemName: "lock.fill")
                            .imageScale(.small)
                            .help("加密连接")
                            .accessibilityLabel("已加密")
                    }
                    Text(detail)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }

    private var detail: String {
        let since = DeviceText.connectedSince(Date(timeIntervalSince1970: TimeInterval(device.connectedAt)))
        return device.model.isEmpty ? since : "\(device.model) · \(since)"
    }
}

struct DisplayApprovalRow: View {
    @Environment(HostController.self) private var host
    @Environment(Preferences.self) private var preferences
    let request: DisplayApprovalRequest
    var inMenu = false
    var waitingCount = 0

    var body: some View {
        if inMenu {
            content
                .padding(12)
                .cardBackground(tint: .accentColor)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("允许“\(request.deviceName)”查看这台 Mac 的屏幕？", systemImage: "display")
                .font(inMenu ? .callout.weight(.semibold) : .headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("来自 \(request.address) 的\(request.model.isEmpty ? "设备" : request.model)。只批准你认识的设备。")
                .font(inMenu ? .caption : .callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(request.remembered ? "这台已配对设备将保持允许状态，直到你在“设备”中撤销访问权限。" : "访问权限仅在此次连接期间有效。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !preferences.displayEnabled {
                Text("批准也会在这台 Mac 上打开屏幕镜像。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    if waitingCount > 0 {
                        Text("还有 \(waitingCount) 个等待中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    Spacer(minLength: 8)
                    actionButtons
                        .fixedSize(horizontal: true, vertical: true)
                }
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 8) {
                        Spacer()
                        actionButtons
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    if waitingCount > 0 {
                        Text("还有 \(waitingCount) 个等待中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .controlSize(inMenu ? .small : .regular)
        }
    }

    @ViewBuilder private var actionButtons: some View {
        Button("不允许") { host.respond(to: request, allow: false) }
            .keyboardShortcut(.cancelAction)
        Button("允许屏幕镜像") { host.respond(to: request, allow: true) }
            .buttonStyle(.borderedProminent)
    }
}

struct ApprovalRow: View {
    @Environment(HostController.self) private var host
    let request: ApprovalRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: DeviceSymbol.name(for: request.model))
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 17))
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("“\(request.deviceName)”请求连接")
                        .font(.callout.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Spacer()
                Button("不允许") { host.respond(to: request, allow: false) }
                Button("允许") { host.respond(to: request, allow: true) }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(12)
        .cardBackground(tint: .accentColor)
    }

    private var detail: String {
        let parts = [request.model, request.address].filter { !$0.isEmpty }
        let source = parts.isEmpty ? "" : parts.joined(separator: " · ") + "。"
        return source + "只批准你认识的设备。"
    }
}
