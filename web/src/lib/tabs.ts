import { AppWindow, Keyboard, LayoutGrid, Monitor, Music, Touchpad } from '@lucide/vue'
import { haptic } from './haptics'
import { settings, type Tab } from './settings'

export const TABS: { id: Tab; label: string; icon: typeof Touchpad }[] = [
  { id: 'trackpad', label: '触控板', icon: Touchpad },
  { id: 'keyboard', label: '键盘', icon: Keyboard },
  { id: 'display', label: '屏幕镜像', icon: Monitor },
  { id: 'deck', label: '快捷面板', icon: LayoutGrid },
  { id: 'apps', label: '应用', icon: AppWindow },
  { id: 'media', label: '媒体', icon: Music },
]

export function selectTab(id: Tab) {
  if (settings.tab === id) return
  settings.tab = id
  haptic('select')
}
