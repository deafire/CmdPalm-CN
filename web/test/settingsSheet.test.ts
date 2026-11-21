import { enableAutoUnmount, flushPromises, mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import { FakeSocket, lastSocket, welcome } from './fakeSocket'

enableAutoUnmount(afterEach)
let connection: typeof import('../src/lib/connection')
let prefs: typeof import('../src/lib/settings')

beforeEach(async () => {
  vi.useFakeTimers()
  vi.stubGlobal('WebSocket', FakeSocket)
  FakeSocket.all = []
  localStorage.clear()
  localStorage.setItem('cmdpalm.token', 'saved')
  vi.resetModules()
  connection = await import('../src/lib/connection')
  prefs = await import('../src/lib/settings')
  connection.connect()
  lastSocket().open()
  lastSocket().receive(welcome)
})
afterEach(() => {
  connection.disconnect(false)
  vi.useRealTimers()
  vi.unstubAllGlobals()
  document.body.innerHTML = ''
})

function button(name: string, scope: ParentNode = document) {
  const found = Array.from(scope.querySelectorAll<HTMLButtonElement>('button')).find((item) => item.textContent?.trim().startsWith(name))
  if (!found) throw new Error(`Missing button: ${name}`)
  return found
}
async function click(name: string) {
  button(name).click()
  await nextTick()
  await nextTick()
}
async function settings() {
  const { default: SettingsSheet } = await import('../src/components/SettingsSheet.vue')
  return mount(SettingsSheet, { attachTo: document.body })
}

describe('settings feature tabs', () => {
  it('keeps Mac details above the feature tabs, device actions below, and edits saved between tabs', async () => {
    connection.state.latency = 8
    await settings()
    expect(document.querySelectorAll('[aria-label="功能设置"] button')).toHaveLength(5)
    const dialog = document.querySelector<HTMLElement>('[role="dialog"]')!
    expect(dialog.textContent).toContain('CmdPalm 1.0 · 已连接 · 8 ms')
    expect(dialog.textContent).toContain('未加密')
    expect(dialog.textContent).toContain('同一 Wi-Fi 下的其他人')
    expect(dialog.querySelector('[role="tabpanel"]')!.getAttribute('aria-labelledby')).toBe('settings-tab-trackpad')
    const scroller = dialog.lastElementChild!
    scroller.scrollTop = 400
    const speed = dialog.querySelector<HTMLInputElement>('input[aria-label="指针速度"]')!
    speed.value = '2'
    speed.dispatchEvent(new Event('input', { bubbles: true }))
    const keyboard = button('键盘')
    keyboard.focus()
    await click('键盘')
    expect(scroller.scrollTop).toBe(0)
    expect(document.activeElement).toBe(keyboard)
    expect(dialog.getAttribute('aria-label')).toBe('设置')
    expect(dialog.querySelector('[role="tabpanel"]')!.getAttribute('aria-labelledby')).toBe('settings-tab-keyboard')
    expect(prefs.settings.pointerSpeed).toBe(2)
    expect(
      button('备份或恢复此设备').compareDocumentPosition(dialog.querySelector('[role="tabpanel"]')!) & Node.DOCUMENT_POSITION_PRECEDING,
    ).toBeTruthy()
    await click('触控板')
    expect(dialog.querySelector<HTMLInputElement>('input[aria-label="指针速度"]')!.value).toBe('2')
    expect(dialog.querySelector('input[aria-label="加速度"]')).not.toBeNull()
    await vi.advanceTimersByTimeAsync(200)
    expect(JSON.parse(localStorage.getItem('cmdpalm.settings')!).pointerSpeed).toBe(2)
  })

  it('shows settings sections without disclosures and keeps dictation setup in Keyboard', async () => {
    await settings()
    const dialog = document.querySelector<HTMLElement>('[role="dialog"]')!
    const hostCard = dialog.querySelector('.card')!
    expect(hostCard.textContent).toContain('已连接')
    expect(hostCard.querySelector('button, input, details, summary')).toBeNull()
    expect(hostCard.textContent).not.toContain('语音输入设置')
    for (const feature of ['触控板', '手势', '键盘', '屏幕镜像', '快捷面板']) {
      await click(feature)
      expect(dialog.querySelector('details, summary')).toBeNull()
      const panel = dialog.querySelector('[role="tabpanel"]')!
      expect(panel.textContent?.includes('语音输入设置')).toBe(feature === '键盘')
      if (feature === '触控板') expect(panel.querySelector('input[aria-label="加速度"]')).not.toBeNull()
      if (feature === '手势') expect(panel.querySelector('[role="radiogroup"][aria-label="捏合"]')).not.toBeNull()
      if (feature === '键盘') expect(panel.querySelector('[role="radiogroup"][aria-label="发送文本为"]')).not.toBeNull()
    }
  })

  it('opens the current feature and switches tabs with a hardware keyboard', async () => {
    prefs.settings.tab = 'keyboard'
    await settings()
    const keyboard = document.querySelector<HTMLButtonElement>('[role="tab"][aria-selected="true"]')!
    expect(keyboard.textContent).toContain('键盘')
    keyboard.dispatchEvent(new KeyboardEvent('keydown', { key: 'End', bubbles: true, cancelable: true }))
    await nextTick()
    expect(document.activeElement?.textContent).toContain('快捷面板')
    expect(document.querySelector('[role="tab"][aria-selected="true"]')!.textContent).toContain('快捷面板')
    document.activeElement!.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true, cancelable: true }))
    await nextTick()
    expect(document.activeElement?.textContent).toContain('触控板')
    expect(document.querySelectorAll('[role="tab"][tabindex="0"]')).toHaveLength(1)
  })

  it('edits just the selected finger map and keeps canceled gesture drafts out of settings', async () => {
    await settings()
    await click('手势')
    await click('四指')
    await click('轻点')
    const editor = document.querySelector<HTMLElement>('[aria-label="四指轻点"]')!
    editor.querySelector<HTMLButtonElement>('[role="switch"]')!.click()
    await nextTick()
    expect(prefs.settings.fourFinger.tap).toBeNull()
    editor.querySelector<HTMLButtonElement>('[aria-label="关闭"]')!.click()
    await nextTick()
    expect(prefs.settings.fourFinger.tap).toBeNull()
    await click('轻点')
    document.querySelector<HTMLButtonElement>('[aria-label="四指轻点"] [role="switch"]')!.click()
    await nextTick()
    await click('保存')
    expect(prefs.settings.fourFinger.tap).toEqual({ kind: 'system', name: 'missionControl' })
    expect(prefs.settings.threeFinger.tap).toEqual({ kind: 'mouse', button: 'middle' })
  })

  it('requires reset confirmation, supports cancel, and preserves the named setup and pairing', async () => {
    const boards = await import('../src/lib/customKeyboards')
    const originalBoards = JSON.stringify(boards.keyboards)
    prefs.settings.pointerSpeed = 3
    prefs.settings.deviceName = 'My phone'
    const deck = JSON.stringify(connection.state.deck)
    await settings()
    await click('重置此设备上的设置')
    expect(prefs.settings.pointerSpeed).toBe(3)
    await click('取消')
    expect(document.body.textContent).not.toContain('将设置恢复为默认值？')
    await click('重置此设备上的设置')
    await click('恢复默认')
    expect(prefs.settings.pointerSpeed).toBe(prefs.defaultSettings().pointerSpeed)
    expect(prefs.settings.deviceName).toBe('My phone')
    expect(localStorage.getItem('cmdpalm.token')).toBe('saved')
    expect(JSON.stringify(boards.keyboards)).toBe(originalBoards)
    expect(JSON.stringify(connection.state.deck)).toBe(deck)
    expect(connection.state.notices.at(-1)?.message).toBe('设置已恢复默认值。')
  })

  it('cancels forget and clears its confirmation when switching tabs, then forgets only on confirmation', async () => {
    const view = await settings()
    await click('忘记此 Mac')
    expect(localStorage.getItem('cmdpalm.token')).toBe('saved')
    await click('取消')
    await click('忘记此 Mac')
    await click('键盘')
    expect(document.body.textContent).not.toContain('忘记并断开')
    await click('忘记此 Mac')
    await click('忘记并断开')
    expect(localStorage.getItem('cmdpalm.token')).toBeNull()
    expect(view.emitted('close')).toHaveLength(1)
  })

  it('opens backup and copy from the bottom actions without losing the current feature', async () => {
    await settings()
    await click('键盘')
    await click('备份或恢复此设备')
    await import('../src/components/BackupSheet.vue')
    await flushPromises()
    expect(document.querySelector('[aria-label="设备备份"]')).not.toBeNull()
    document.querySelector<HTMLButtonElement>('[aria-label="设备备份"] [aria-label="关闭"]')!.click()
    await nextTick()
    expect(document.querySelector('[role="tab"][aria-selected="true"]')!.textContent).toContain('键盘')
    await click('从其他设备复制设置')
    await import('../src/components/CopySettingsSheet.vue')
    await flushPromises()
    expect(document.querySelector('[aria-label="从设备复制"]')).not.toBeNull()
    expect(lastSocket().sent.at(-1)).toMatchObject({ t: 'settingsList' })
  })

  it('keeps quality choices in sync and resumes an active view only for a changed quality', async () => {
    const viewing = await import('../src/lib/screen')
    const start = vi.spyOn(viewing, 'startViewing').mockResolvedValue()
    await settings()
    await click('屏幕镜像')
    expect(button('高清文字').disabled).toBe(true)
    viewing.screen.active = true
    viewing.screen.status = 'live'
    await click('更清晰的文字')
    expect(prefs.settings.displayQuality).toBe('sharp')
    expect(start).toHaveBeenCalledOnce()
    await click('更清晰的文字')
    expect(start).toHaveBeenCalledOnce()
    viewing.screen.active = false
    await click('省电')
    expect(prefs.settings.displayQuality).toBe('battery')
    expect(start).toHaveBeenCalledOnce()
    start.mockRestore()
  })

  it('shows encryption status and tailored dictation setup guidance for each connection and feature state', async () => {
    const sheet = await settings()
    const hostCard = () => document.querySelector<HTMLElement>('[role="dialog"] .card')!
    expect(hostCard().textContent).toContain('未加密')
    expect(hostCard().textContent).toContain('同一 Wi-Fi 下的其他人')

    await click('键盘')
    const panelText = () => document.querySelector<HTMLElement>('[role="tabpanel"]')!.textContent!
    expect(panelText()).toContain('加密连接')
    expect(panelText()).toContain('允许来自设备的听写')

    connection.state.features.voice = true
    await nextTick()
    expect(panelText()).toContain('手机设置 → 加密连接')
    expect(panelText()).not.toContain('允许来自设备的听写')

    connection.state.features.secure = true
    connection.state.features.voice = false
    await nextTick()
    expect(hostCard().textContent).toContain('已加密')
    expect(hostCard().textContent).not.toContain('未加密')
    expect(hostCard().textContent).not.toContain('同一 Wi-Fi 下的其他人')
    expect(panelText()).toContain('此 Mac 上的语音输入已关闭')

    connection.state.features.voice = true
    vi.stubGlobal('isSecureContext', true)
    vi.stubGlobal('navigator', { ...navigator, mediaDevices: { getUserMedia: vi.fn() } })
    vi.stubGlobal('AudioWorkletNode', class {})
    sheet.unmount()
    await settings()
    await click('键盘')
    expect(panelText()).toContain('语音输入已就绪')
  })
})
