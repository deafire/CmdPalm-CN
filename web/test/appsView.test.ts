import { mount, type VueWrapper } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import type { AppEntry } from '../src/lib/protocol'
import { FakeSocket, lastSocket, welcome } from './fakeSocket'

let connection: typeof import('../src/lib/connection')
let wrapper: VueWrapper | undefined

const closedApp: AppEntry = { id: 'com.example.notes', name: 'Notes', running: false, active: false, hidden: false }

beforeEach(async () => {
  vi.useFakeTimers()
  vi.stubGlobal('WebSocket', FakeSocket)
  vi.stubGlobal('fetch', () => Promise.reject(new Error('offline')))
  FakeSocket.all = []
  localStorage.clear()
  localStorage.setItem('cmdpalm.token', 'saved')
  vi.resetModules()
  connection = await import('../src/lib/connection')
  connection.connect()
  lastSocket().open()
  lastSocket().receive(welcome)
})

afterEach(() => {
  wrapper?.unmount()
  wrapper = undefined
  connection.disconnect(false)
  document.body.innerHTML = ''
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

async function mountApps() {
  const { default: AppsView } = await import('../src/views/AppsView.vue')
  wrapper = mount(AppsView, { attachTo: document.body })
  lastSocket().receive({ t: 'apps', apps: [closedApp] })
  await nextTick()
  return wrapper
}

describe('AppsView empty-state recovery', () => {
  it('shows a closed catalog app after switching from Open to All apps', async () => {
    const view = await mountApps()
    expect(view.text()).toContain('没有打开的应用。')
    expect(view.find('button[aria-label="Notes"]').exists()).toBe(false)

    await view
      .findAll('button')
      .find((button) => button.text() === '显示所有应用')!
      .trigger('click')
    expect(view.find('button[aria-label="Notes"]').exists()).toBe(true)
  })

  it('clears an unmatched search and retains the selected filter', async () => {
    const view = await mountApps()
    await view.get('button[role="radio"]:nth-child(2)').trigger('click')
    await view.get('input[aria-label="搜索 Mac 上的应用"]').setValue('missing app')
    expect(view.text()).toContain('清除搜索')
    await view
      .findAll('button')
      .find((button) => button.text() === '清除搜索')!
      .trigger('click')
    expect(view.find('button[aria-label="Notes"]').exists()).toBe(true)
    expect(view.get('[role="radiogroup"]').text()).toContain('所有应用')
    expect(view.get('button[role="radio"]:nth-child(2)').attributes('aria-checked')).toBe('true')
  })
})
