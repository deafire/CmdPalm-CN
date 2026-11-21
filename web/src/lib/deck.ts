// Deck editing helpers. Limits mirror core/src/deck.rs so the editor can
// explain a problem before the Mac rejects the save.

import { reactive, watch } from 'vue'
import { notify, onMessage, send, state } from './connection'
import { MEDIA, SYSTEM } from './actions'
import { equalJson } from './value'
import type { Action, Deck, DeckPage, Tile } from './protocol'

export const LIMITS = { pages: 24, tiles: 64, label: 80, text: 4096, name: 512, steps: 64, depth: 3, delayMs: 10_000 }

export function newId(prefix = 't'): string {
  const bytes = crypto.getRandomValues(new Uint8Array(6))
  return `${prefix}-${Array.from(bytes, (b) => b.toString(36).padStart(2, '0')).join('').slice(0, 10)}`
}

const encoder = new TextEncoder()
/** The Mac limits text by its UTF-8 size. */
const tooLong = (text: string, limit = LIMITS.text) => encoder.encode(text).length > limit

/** Returns a problem with the action, or '' when it can be saved. */
export function actionProblem(action: Action, depth = 0): string {
  if (!action || typeof action !== 'object') return '请选择一个操作。'
  switch (action.kind) {
    case 'keys':
      if (!Number.isInteger(action.code) || action.code < 0 || action.code > 0xff) return '请选择一个按键。'
      if (action.char !== undefined && (typeof action.char !== 'string' || tooLong(action.char, 16))) return '请选择有效的快捷键字符。'
      return !Number.isInteger(action.mods) || action.mods < 0 || action.mods > 0xffff || (action.mods & ~0x1f) !== 0 ? '请选择有效的修饰键。' : ''
    case 'text':
      if (typeof action.text !== 'string' || !action.text) return '请输入要输入的文字。'
      if (action.enter !== undefined && typeof action.enter !== 'boolean') return '请选择是否按回车键。'
      return tooLong(action.text) ? '文字过长。' : ''
    case 'shell':
      if (typeof action.command !== 'string' || !action.command.trim()) return '请输入命令。'
      return tooLong(action.command) ? '命令过长。' : ''
    case 'url':
      if (typeof action.url !== 'string') return '请输入完整链接。'
      if (tooLong(action.url)) return '链接过长。'
      return /^[a-z][\w+.-]*:\S+/i.test(action.url.trim()) ? '' : '请输入完整链接，例如 https://example.com。'
    case 'app':
      return typeof action.id === 'string' && action.id && !tooLong(action.id, LIMITS.name) && (action.op === undefined || ['open', 'toggle', 'hide', 'quit'].includes(action.op)) ? '' : '请选择一个应用。'
    case 'shortcut':
      if (typeof action.name !== 'string' || !action.name.trim()) return '请输入“快捷指令”App 中快捷指令的名称。'
      return tooLong(action.name, LIMITS.name) ? '快捷指令名称过长。' : ''
    case 'delay':
      return Number.isInteger(action.ms) && action.ms >= 0 && action.ms <= LIMITS.delayMs ? '' : '等待时间不能超过 10 秒。'
    case 'mouse':
      return ['left', 'right', 'middle', 'back', 'forward'].includes(action.button) && Number.isInteger(action.clicks ?? 1) && (action.clicks ?? 1) >= 1 && (action.clicks ?? 1) <= 3 ? '' : '请使用一到三次点击和一个鼠标按键。'
    case 'sequence': {
      if (!Array.isArray(action.steps)) return '请至少添加一个步骤。'
      if (depth >= LIMITS.depth - 1 && action.steps.some((s) => s.kind === 'sequence')) return '序列只能嵌套有限的层级。'
      if (action.steps.length === 0) return '请至少添加一个步骤。'
      if (action.steps.length > LIMITS.steps) return `序列最多只能包含 ${LIMITS.steps} 个步骤。`
      for (const [i, step] of action.steps.entries()) {
        const problem = actionProblem(step, depth + 1)
        if (problem) return `步骤 ${i + 1}：${problem}`
      }
      return ''
    }
    case 'media':
      return Object.hasOwn(MEDIA, action.key) ? '' : '请选择一个媒体按键。'
    case 'system':
      return Object.hasOwn(SYSTEM, action.name) ? '' : '请选择一个 Mac 操作。'
    default:
      return '请选择此版本 CmdPalm 支持的操作。'
  }
}

/** Plain deep copy; reactive proxies cannot go through structuredClone. */
export function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T
}

/** The last deck the Mac accepted, restored if a save is rejected. A copy,
 * because editing (dragging tiles) changes the shown deck in place. */
let confirmed: Deck | null = state.deck ? clone(state.deck) : null
export const deckHistory = reactive({ saving: false, undo: 0, redo: 0 })
interface Edit { before: Deck; after: Deck }
const undo: Edit[] = []
const redo: Edit[] = []
let historyEpoch = 0
let nextSaveId = 0
let pending: {
  id: number
  next: Deck
  before: Deck
  record: boolean
  resolve: (saved: boolean) => void
  timer: ReturnType<typeof setTimeout>
} | null = null

function counts() {
  deckHistory.undo = undo.length
  deckHistory.redo = redo.length
}

function clearHistory() {
  undo.length = redo.length = 0
  historyEpoch++
  counts()
}

const same = (a: Deck | null, b: Deck) => equalJson(a, b)

function finishSave(ok: boolean, message?: string) {
  const saving = pending
  if (!saving) return
  pending = null
  clearTimeout(saving.timer)
  deckHistory.saving = false
  if (!ok) {
    if (confirmed && !same(confirmed, saving.before)) clearHistory()
    if (confirmed) state.deck = clone(confirmed)
    if (message) notify(message, 'warning', 'deck')
  } else if (saving.record && confirmed && same(confirmed, saving.next) && !same(saving.before, saving.next)) {
    undo.push({ before: saving.before, after: clone(saving.next) })
    redo.length = 0
    // Keep history useful without retaining unbounded snippet contents.
    while (undo.length > 20 || (undo.length > 1 && JSON.stringify(undo).length > 1024 * 1024)) undo.shift()
    counts()
  }
  saving.resolve(ok)
}

onMessage((message) => {
  if (message.t === 'welcome') {
    finishSave(false)
    confirmed = clone(message.deck)
    clearHistory()
  } else if (message.t === 'deck') {
    const ours = pending && same(pending.next, message.deck)
    if (!ours) clearHistory()
    confirmed = clone(message.deck)
    // Older Macs acknowledge a save by echoing the saved deck.
    if (ours && message.revision === undefined) finishSave(true)
  } else if (message.t === 'deckSaved' && message.id === pending?.id) {
    finishSave(message.ok, message.message)
  } else if (message.t === 'notice' && message.code === 'deck') {
    if (confirmed) state.deck = clone(confirmed)
    finishSave(false)
  }
})

watch(() => state.status, (status) => {
  if (status !== 'connected') finishSave(false, '连接已断开。你的修改仍在这里，请重新连接后再次保存。')
}, { flush: 'sync' })

/** Resolve only after the Mac accepted the change, keeping drafts on failure. */
export function saveDeck(deck: Deck, record = true): Promise<boolean> {
  if (pending) {
    notify('请等待当前的快捷面板修改完成。', 'info', 'deck')
    return Promise.resolve(false)
  }
  return new Promise((resolve) => {
    const id = ++nextSaveId
    pending = {
      id, next: clone(deck), before: clone(confirmed ?? deck), record, resolve,
      timer: setTimeout(() => finishSave(false, 'Mac 尚未确认此修改。你的修改仍在这里，请重试保存。'), 8000),
    }
    deckHistory.saving = true
    if (!send({ t: 'deckSave', deck: clone(deck), id, ...(state.deckRevision !== undefined ? { revision: state.deckRevision } : {}) })) {
      finishSave(false, '未连接到 Mac，快捷面板未做更改。')
    }
  })
}

export async function undoDeck(): Promise<boolean> {
  const edit = undo.at(-1)
  if (!edit || deckHistory.saving) return false
  const epoch = historyEpoch
  if (!(await saveDeck(edit.before, false))) return false
  if (epoch === historyEpoch) { undo.pop(); redo.push(edit); counts() }
  return true
}

export async function redoDeck(): Promise<boolean> {
  const edit = redo.at(-1)
  if (!edit || deckHistory.saving) return false
  const epoch = historyEpoch
  if (!(await saveDeck(edit.after, false))) return false
  if (epoch === historyEpoch) { redo.pop(); undo.push(edit); counts() }
  return true
}

export function newPage(name: string, columns = 4): DeckPage {
  return { id: newId('p'), name, columns, tiles: [] }
}

export function newTile(action: Action, label = ''): Tile {
  return { id: newId(), label, action }
}

/** Add a tile to the page the user last looked at. Returns the page name,
 * '' if it is full, or null if it couldn't be saved (already explained). */
export async function addTileToCurrentPage(tile: Tile, pageId: string): Promise<string | null> {
  if (!state.deck) return ''
  const deck = clone(state.deck)
  const page = deck.pages.find((p) => p.id === pageId) ?? deck.pages[0]
  if (!page || page.tiles.length >= LIMITS.tiles) return ''
  page.tiles.push(tile)
  return (await saveDeck(deck)) ? page.name : null
}

export const COLORS = ['#ff8a3d', '#ff5f57', '#f5b942', '#3ecf8e', '#2ec4d6', '#4f8cff', '#8b6cff', '#e85fb5', '#8d949e']
