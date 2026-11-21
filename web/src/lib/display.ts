// Running as a home screen app, full screen, or in a browser tab, and how to
// get out of the tab on each platform.

import { reactive } from 'vue'
import { deviceModel } from './device'

interface InstallPrompt extends Event {
  prompt(): Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

const standaloneQuery = typeof matchMedia === 'function' ? matchMedia('(display-mode: standalone), (display-mode: fullscreen)') : null

export const display = reactive({
  standalone: standaloneQuery?.matches === true || (navigator as Navigator & { standalone?: boolean }).standalone === true,
  fullscreen: false,
  /** The browser offered to install the app (Chromium, over HTTPS only). */
  installable: false,
})

let installPrompt: InstallPrompt | null = null

export function installDisplayTracking() {
  standaloneQuery?.addEventListener('change', (event) => (display.standalone = event.matches))
  document.addEventListener('fullscreenchange', () => (display.fullscreen = document.fullscreenElement !== null))
  addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault()
    installPrompt = event as InstallPrompt
    display.installable = true
  })
  addEventListener('appinstalled', () => {
    installPrompt = null
    display.installable = false
  })
}

/** Browsers that can hide their own bars for a page (Android, desktop; not iPhone). */
export const canFullscreen = () => typeof document.documentElement.requestFullscreen === 'function' && document.fullscreenEnabled

export async function toggleFullscreen() {
  try {
    if (document.fullscreenElement) await document.exitFullscreen()
    else await document.documentElement.requestFullscreen({ navigationUI: 'hide' })
  } catch {
    // Refused (not from a tap, or blocked by the browser): nothing to undo.
  }
}

export async function install() {
  const prompt = installPrompt
  if (!prompt) return
  installPrompt = null
  display.installable = false
  await prompt.prompt().catch(() => {})
}

/** How to add CmdPalm to the home screen in this browser. */
export function installHint(): string {
  const model = deviceModel()
  const ua = navigator.userAgent
  if (model === 'iPhone' || model === 'iPad' || model === 'iPod touch') {
    return '轻点“分享”，然后选择“添加到主屏幕”，即可像应用一样全屏打开 CmdPalm。'
  }
  if (model.startsWith('Android')) {
    // Android browsers install web apps only over HTTPS; over plain HTTP they
    // offer a shortcut that opens in a browser tab.
    if (!isSecureContext) {
      return '要将 CmdPalm 安装为应用，请使用加密连接：在 Mac 上打开 CmdPalm 的“设置 → 手机设置 → 加密连接”。否则，可添加快捷方式（菜单 ⋮ → 添加到主屏幕）并使用全屏。'
    }
    if (display.installable) return '安装 CmdPalm，即可像应用一样全屏打开。'
    if (/SamsungBrowser/.test(ua)) return '打开菜单 ☰，然后选择“添加页面到 → 主屏幕”。'
    if (/Firefox/.test(ua)) return '打开菜单 ⋮，然后选择“添加到主屏幕”。'
    return '打开浏览器菜单 ⋮，然后选择“添加到主屏幕 → 安装”。'
  }
  if (display.installable) return '安装 CmdPalm，即可在独立窗口中打开。'
  return '使用浏览器的“安装”或“添加到主屏幕”选项，即可在独立窗口中打开 CmdPalm。'
}
