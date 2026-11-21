<div align="center">

<img src="web/public/icon.svg" width="112" height="112" alt="CmdPalm app icon" />

# CmdPalm 中文版（CmdPalm-CN）

### 你的 Mac，尽在掌中。

用 iPhone、iPad 或 Android 手机查看和控制你的 Mac：屏幕镜像、触控板、键盘、快捷面板、语音输入，全部在你的浏览器里。<br />
**手机无需安装 App，无需注册账号，免费开源。**

<br />

<a href="https://github.com/deafire/CmdPalm-CN/releases/latest"><img src="https://img.shields.io/badge/下载中文版-f9813d?style=for-the-badge&logo=apple&logoColor=white" alt="下载中文版" height="36" /></a>
&nbsp;
<a href="https://github.com/rahatsagor/CmdPalm"><img src="https://img.shields.io/badge/上游原版-1f1f1f?style=for-the-badge&logo=github&logoColor=white" alt="上游原版" height="36" /></a>

</div>

---

> **这是什么？** 这是 [rahatsagor/CmdPalm](https://github.com/rahatsagor/CmdPalm) 的**非官方简体中文汉化版**，由社区维护。原项目不接受第三方 PR，故独立建仓发布。
>
> **汉化范围**：Mac 原生界面（欢迎引导、菜单栏、设置全部面板、系统权限弹窗）、手机网页端全部界面、Rust 核心提示消息、安装说明，共 100+ 文件约 1440 处文案。
>
> **已知差异**：中文版使用 ad-hoc 签名，首次打开需按 [安装说明](#安装中文版) 解除 macOS 拦截；辅助功能权限在重装后需重新授予。

## 使用 Windows？试试 WinPalm。

原项目作者还开发了 Windows 版：[WinPalm](https://github.com/rahatsagor/WinPalm)。

## 功能一览

- **屏幕镜像**：在触控板或键盘上方实时查看 Mac 屏幕
- **触控板**：点击、拖动、滚动、捏合缩放，手势与 Mac 触控板一致
- **键盘**：输入文字、语音听写、按下任意快捷键，修饰键可保持
- **快捷面板**：类似 Stream Deck 的按钮网格——应用、快捷指令、媒体控制、文本片段、多步序列
- **隐私设计**：全部流量走本地网络，无云端中转，不收集数据

## 系统要求

- macOS 15.0 或更高（Apple Silicon）
- 手机端仅需浏览器（iPhone/iPad Safari、Android Chrome）

## 安装中文版

1. 从 [Releases](https://github.com/deafire/CmdPalm-CN/releases/latest) 下载 `CmdPalm-x.x.x-中文版.dmg`
2. 打开 dmg，将 CmdPalm 拖入「应用程序」文件夹
3. 中文版未用付费开发者签名，首次打开会被 macOS 拦截，二选一：
   - 终端执行：`xattr -dr com.apple.quarantine /Applications/CmdPalm.app`
   - 或先尝试打开一次，然后去「系统设置 → 隐私与安全性」点「仍然打开」
4. 打开 CmdPalm（在菜单栏），按提示授予辅助功能权限并配对手机

## 从源码构建

需要 macOS 15+、Xcode、Rust、Bun 和 XcodeGen：

```sh
brew install xcodegen
scripts/build-app.sh          # build/Release/CmdPalm.app
scripts/package.sh            # dist/CmdPalm-x.x.x.dmg + zip
```

详细开发文档见 [CONTRIBUTING.md](CONTRIBUTING.md)（英文，来自上游）。

## 与上游同步

本仓库定期从上游合并更新并重新汉化。查看上游原始英文说明：[README-EN-Original.md](README-EN-Original.md)。

## 许可证

[GNU AGPL v3](LICENSE)（同上游）。CmdPalm 版权归原作者所有，汉化部分同样以 AGPL v3 发布。

## 致谢

- 上游项目：[rahatsagor/CmdPalm](https://github.com/rahatsagor/CmdPalm) — 所有架构与代码设计的作者
- 本仓库仅提交了本地化文案改动
