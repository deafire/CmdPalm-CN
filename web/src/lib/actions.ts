import { comboLabel, type LabelMap } from './keys'
import type { Action, AppOp, MediaKey, MouseButton, SystemAction } from './protocol'

export interface Meta {
  label: string
  symbol: string
  group: string
}

export const SYSTEM: Record<SystemAction, Meta> = {
  missionControl: { label: '调度中心', symbol: 'layout-grid', group: '窗口与空间' },
  appExpose: { label: '应用窗口', symbol: 'app-window', group: '窗口与空间' },
  showDesktop: { label: '显示桌面', symbol: 'monitor', group: '窗口与空间' },
  launchpad: { label: '启动台', symbol: 'grid-2x2', group: '窗口与空间' },
  spaceLeft: { label: '左侧空间', symbol: 'arrow-left-to-line', group: '窗口与空间' },
  spaceRight: { label: '右侧空间', symbol: 'arrow-right-to-line', group: '窗口与空间' },
  appSwitcher: { label: '上一个应用', symbol: 'repeat', group: '窗口与空间' },
  fullscreen: { label: '全屏', symbol: 'maximize', group: '窗口与空间' },
  minimize: { label: '最小化', symbol: 'minimize', group: '窗口与空间' },
  closeWindow: { label: '关闭窗口', symbol: 'x', group: '窗口与空间' },
  hideApp: { label: '隐藏应用', symbol: 'eye-off', group: '窗口与空间' },
  quitApp: { label: '退出应用', symbol: 'power', group: '窗口与空间' },
  spotlight: { label: '聚焦', symbol: 'search', group: '系统' },
  lookUp: { label: '查询', symbol: 'book-open', group: '系统' },
  emojiPicker: { label: '表情与符号', symbol: 'smile', group: '系统' },
  screenshot: { label: '截图', symbol: 'camera', group: '系统' },
  screenshotArea: { label: '区域截图', symbol: 'scan', group: '系统' },
  screenshotTool: { label: '截图工具', symbol: 'aperture', group: '系统' },
  forceQuit: { label: '强制退出', symbol: 'octagon-x', group: '系统' },
  lockScreen: { label: '锁定屏幕', symbol: 'lock', group: '系统' },
  sleepDisplay: { label: '关闭显示器', symbol: 'monitor-off', group: '系统' },
  sleep: { label: '睡眠', symbol: 'moon', group: '系统' },
  undo: { label: '撤销', symbol: 'undo', group: '编辑' },
  redo: { label: '重做', symbol: 'redo', group: '编辑' },
  copy: { label: '复制', symbol: 'copy', group: '编辑' },
  cut: { label: '剪切', symbol: 'scissors', group: '编辑' },
  paste: { label: '粘贴', symbol: 'clipboard', group: '编辑' },
  selectAll: { label: '全选', symbol: 'text-select', group: '编辑' },
  find: { label: '查找', symbol: 'search', group: '编辑' },
  newTab: { label: '新建标签页', symbol: 'plus', group: '浏览' },
  closeTab: { label: '关闭标签页', symbol: 'x', group: '浏览' },
  nextTab: { label: '下一个标签页', symbol: 'chevron-right', group: '浏览' },
  previousTab: { label: '上一个标签页', symbol: 'chevron-left', group: '浏览' },
  back: { label: '返回', symbol: 'arrow-left', group: '浏览' },
  forward: { label: '前进', symbol: 'arrow-right', group: '浏览' },
  reload: { label: '重新加载', symbol: 'rotate-cw', group: '浏览' },
  zoomIn: { label: '放大', symbol: 'zoom-in', group: '浏览' },
  zoomOut: { label: '缩小', symbol: 'zoom-out', group: '浏览' },
  actualSize: { label: '实际大小', symbol: 'scan-search', group: '浏览' },
}

export const MEDIA: Record<MediaKey, Meta> = {
  playPause: { label: '播放 / 暂停', symbol: 'play-pause', group: '媒体' },
  next: { label: '下一首', symbol: 'skip-forward', group: '媒体' },
  previous: { label: '上一首', symbol: 'skip-back', group: '媒体' },
  fastForward: { label: '快进', symbol: 'fast-forward', group: '媒体' },
  rewind: { label: '快退', symbol: 'rewind', group: '媒体' },
  volumeUp: { label: '调高音量', symbol: 'volume-2', group: '声音与显示' },
  volumeDown: { label: '调低音量', symbol: 'volume-1', group: '声音与显示' },
  mute: { label: '静音', symbol: 'volume-x', group: '声音与显示' },
  brightnessUp: { label: '调亮', symbol: 'sun', group: '声音与显示' },
  brightnessDown: { label: '调暗', symbol: 'sun-dim', group: '声音与显示' },
  illuminationUp: { label: '调亮背光', symbol: 'lightbulb', group: '声音与显示' },
  illuminationDown: { label: '调暗背光', symbol: 'lightbulb-off', group: '声音与显示' },
  illuminationToggle: { label: '背光开/关', symbol: 'lightbulb', group: '声音与显示' },
}

export const ACTION_KINDS: { kind: Action['kind']; label: string; symbol: string }[] = [
  { kind: 'keys', label: '键盘快捷键', symbol: 'command' },
  { kind: 'system', label: 'Mac 操作', symbol: 'laptop' },
  { kind: 'media', label: '媒体与声音', symbol: 'music' },
  { kind: 'app', label: '打开应用', symbol: 'app-window' },
  { kind: 'text', label: '输入文本', symbol: 'type' },
  { kind: 'url', label: '打开链接', symbol: 'link' },
  { kind: 'shortcut', label: '运行快捷指令', symbol: 'workflow' },
  { kind: 'mouse', label: '鼠标点击', symbol: 'mouse-pointer-click' },
  { kind: 'sequence', label: '序列', symbol: 'list-ordered' },
  { kind: 'delay', label: '等待', symbol: 'timer' },
  { kind: 'shell', label: 'Shell 命令', symbol: 'square-terminal' },
]

export function defaultAction(kind: Action['kind']): Action {
  switch (kind) {
    case 'keys':
      return { kind: 'keys', code: 0x08, mods: 1, char: 'c' }
    case 'system':
      return { kind: 'system', name: 'missionControl' }
    case 'media':
      return { kind: 'media', key: 'playPause' }
    case 'app':
      return { kind: 'app', id: '', op: 'toggle' }
    case 'text':
      return { kind: 'text', text: '', enter: false }
    case 'url':
      return { kind: 'url', url: 'https://' }
    case 'shortcut':
      return { kind: 'shortcut', name: '' }
    case 'mouse':
      return { kind: 'mouse', button: 'left', clicks: 1 }
    case 'sequence':
      return { kind: 'sequence', steps: [] }
    case 'delay':
      return { kind: 'delay', ms: 250 }
    case 'shell':
      return { kind: 'shell', command: '' }
  }
}

const APP_OPS: Record<AppOp, string> = { open: '打开', toggle: '显示或隐藏', hide: '隐藏', quit: '退出' }
const CLICKS: Record<MouseButton, string> = { left: '单击', right: '右键单击', middle: '中键单击', back: '后退键单击', forward: '前进键单击' }

/** "单击"、"右键单击"、"双击"、"双击右键"… */
function mouseLabel(button: MouseButton, clicks: number): string {
  const name = CLICKS[button] ?? `${button} 单击`
  if (clicks <= 1) return name
  return `${clicks === 2 ? '双' : '三'}${name}`
}

export function describe(action: Action | null, labels: LabelMap, apps?: Map<string, string>): string {
  if (!action) return '无'
  switch (action.kind) {
    case 'keys':
      return comboLabel(action.code, action.mods, labels)
    case 'system':
      return SYSTEM[action.name]?.label ?? action.name
    case 'media':
      return MEDIA[action.key]?.label ?? action.key
    case 'app':
      return `${APP_OPS[action.op ?? 'toggle']} ${apps?.get(action.id) ?? (action.id.split('.').pop() || '应用')}`
    case 'text':
      return action.text ? `输入“${action.text.length > 18 ? `${action.text.slice(0, 18)}…` : action.text}”` : '输入文本'
    case 'url':
      return action.url.replace(/^https?:\/\//, '')
    case 'shortcut':
      return action.name ? `快捷指令“${action.name}”` : '运行快捷指令'
    case 'mouse':
      return mouseLabel(action.button, action.clicks ?? 1)
    case 'sequence':
      return `${action.steps.length} 个步骤`
    case 'delay':
      return `等待 ${action.ms} 毫秒`
    case 'shell':
      return action.command ? `$ ${action.command}` : 'Shell 命令'
  }
}

export function actionSymbol(action: Action): string {
  switch (action.kind) {
    case 'system':
      return SYSTEM[action.name]?.symbol ?? 'laptop'
    case 'media':
      return MEDIA[action.key]?.symbol ?? 'music'
    default:
      return ACTION_KINDS.find((k) => k.kind === action.kind)?.symbol ?? 'zap'
  }
}
