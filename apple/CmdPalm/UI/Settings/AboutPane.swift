import AppKit
import SwiftUI

struct AboutPane: View {
    static let website = URL(string: "https://cmdpalm.app")!
    static let repository = URL(string: "https://github.com/rahatsagor/CmdPalm")!

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)
                Text("CmdPalm")
                    .font(.largeTitle.weight(.bold))
                    .padding(.top, 8)
                Text(versionText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.top, 2)
                    .contextMenu {
                        Button("复制版本") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("CmdPalm \(versionText)", forType: .string)
                        }
                    }
                Text("让你的手机成为 Mac 的触控板、键盘、快捷面板和屏幕镜像。")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)

                links
                    .padding(.top, 24)

                privacy
                    .frame(maxWidth: 440)
                    .padding(.top, 32)

                Text("© 2026 CmdPalm。基于 GNU AGPL v3 协议免费开源。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                if let licenses = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt") {
                    Button("许可证与第三方声明") { openURL(licenses) }
                        .buttonStyle(.link)
                        .font(.caption)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .softScrollEdge()
    }

    private var versionText: String {
        "版本 \(SystemInfo.appVersion) (\(SystemInfo.buildNumber)) · 内核 \(coreVersion())"
    }

    private var links: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                linkButton("网站", symbol: "globe", url: Self.website)
                linkButton("版本说明", symbol: "sparkles", url: Self.repository.appending(path: "releases"))
                linkButton("源代码", symbol: "chevron.left.forwardslash.chevron.right", url: Self.repository)
                linkButton("反馈问题", symbol: "exclamationmark.bubble", url: Self.repository.appending(path: "issues/new/choose"))
            }
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    linkButton("网站", symbol: "globe", url: Self.website)
                    linkButton("版本说明", symbol: "sparkles", url: Self.repository.appending(path: "releases"))
                }
                HStack(spacing: 8) {
                    linkButton("源代码", symbol: "chevron.left.forwardslash.chevron.right", url: Self.repository)
                    linkButton("反馈问题", symbol: "exclamationmark.bubble", url: Self.repository.appending(path: "issues/new/choose"))
                }
            }
        }
        .controlSize(.large)
    }

    private func linkButton(_ title: String, symbol: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            Label(title, systemImage: symbol)
                .fixedSize()
        }
        .glassButtonStyle()
        .help(url.absoluteString)
    }

    private var privacy: some View {
        HStack(alignment: .top, spacing: 12) {
            SymbolBadge(symbol: "lock.fill", color: .blue, size: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("注重隐私")
                    .font(.headline)
                Text("CmdPalm 完全在本地网络运行，没有账户、分析或云服务。只有更新检查会联网访问 GitHub。")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cardBackground(cornerRadius: 12)
    }
}
