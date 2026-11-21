// Connection status shown in the header (portrait) or side rail (landscape).

import { computed, ref } from 'vue'
import { notify, state } from './connection'
import { releaseHardwareKeys } from './hardware'
import { modifiers, releaseAll } from './input'
import { modsLabel } from './keys'

export const online = computed(() => state.status === 'connected')
/** Modifiers left on (latched or locked), as symbols. */
export const stuck = computed(() => modsLabel(modifiers.state.locked | modifiers.state.latched))

/** True for a moment after `panic`, to confirm it on the button. */
export const released = ref(false)
let releasedTimer: ReturnType<typeof setTimeout> | undefined

export function explainPermission() {
  notify(
    'CmdPalm 需要辅助功能权限才能控制 Mac。请在 Mac 的“系统设置 → 隐私与安全性 → 辅助功能”中开启 CmdPalm。',
    'warning',
    'permission',
  )
}

/** Release every key and button this device holds on the Mac. */
export function panic() {
  releaseHardwareKeys()
  releaseAll()
  notify('已释放 Mac 上的所有按键和按钮。', 'info', 'release')
  released.value = true
  clearTimeout(releasedTimer)
  releasedTimer = setTimeout(() => (released.value = false), 1200)
}
