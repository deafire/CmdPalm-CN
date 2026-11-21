<script setup lang="ts">
import {
  FastForward, Lightbulb, LightbulbOff, Pause, Play, Rewind, SkipBack, SkipForward, Sun, SunDim, Volume1, Volume2, VolumeX,
} from '@lucide/vue'
import { computed, onBeforeUnmount, onDeactivated, ref, watch } from 'vue'
import { send, state } from '@/lib/connection'
import { haptic } from '@/lib/haptics'
import { onPageHidden } from '@/lib/heldPointers'
import { pressMedia } from '@/lib/input'
import type { MediaKey } from '@/lib/protocol'

// Media keys act on whatever the Mac's Now Playing app is.
const held = ref<MediaKey | null>(null)
let holder: number | null = null
let release: (() => void) | null = null

function down(key: MediaKey, event: PointerEvent) {
  event.preventDefault()
  if (held.value) return
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
  held.value = key
  holder = event.pointerId
  release = pressMedia(key)
  haptic('light')
}
function up(key: MediaKey, event: PointerEvent) {
  // A second finger on a held key mustn't let go of it when it lifts.
  if (held.value !== key || event.pointerId !== holder) return
  letGo()
}
function letGo() {
  held.value = null
  holder = null
  release?.()
  release = null
}
// Taps act on pointerdown, and their click has a detail of 1 or more. A
// click from a keyboard or screen reader has none, so it taps the key here.
function activate(key: MediaKey, event: MouseEvent) {
  if (event.detail !== 0 || held.value) return
  pressMedia(key)()
  haptic('light')
}
// The slider shows our own value while dragging, then follows the Mac.
const dragging = ref(false)
const local = ref(state.volume?.value ?? 0.5)
watch(
  () => state.volume?.value,
  (value) => {
    if (!dragging.value && value !== undefined) local.value = value
  },
)

// The finger may still be down when the tab changes; its lift never arrives.
function letGoAll() {
  letGo()
  dragging.value = false
}
onDeactivated(letGoAll)
onBeforeUnmount(letGoAll)
onPageHidden(letGoAll)
let sendTimer: ReturnType<typeof setTimeout> | undefined
let lastSent = 0
function setVolume(value: number) {
  local.value = value
  const now = performance.now()
  clearTimeout(sendTimer)
  const flush = () => {
    lastSent = performance.now()
    send({ t: 'volume', value: local.value, muted: false })
  }
  if (now - lastSent > 60) flush()
  else sendTimer = setTimeout(flush, 60)
}
onBeforeUnmount(() => clearTimeout(sendTimer))

const muted = computed(() => state.volume?.muted ?? false)
const VolumeIcon = computed(() => (muted.value || local.value === 0 ? VolumeX : local.value < 0.5 ? Volume1 : Volume2))

function toggleMute() {
  send({ t: 'volume', muted: !muted.value })
  haptic('light')
}

const transport = [
  { key: 'previous' as const, icon: SkipBack, label: '上一首', size: 26 },
  { key: 'playPause' as const, icon: null, label: '播放或暂停', size: 34 },
  { key: 'next' as const, icon: SkipForward, label: '下一首', size: 26 },
]

const extra = [
  { key: 'rewind' as const, icon: Rewind, label: '快退', name: '快退' },
  { key: 'fastForward' as const, icon: FastForward, label: '快进', name: '快进' },
  { key: 'brightnessDown' as const, icon: SunDim, label: '调暗', name: '降低屏幕亮度' },
  { key: 'brightnessUp' as const, icon: Sun, label: '调亮', name: '提高屏幕亮度' },
  { key: 'illuminationDown' as const, icon: LightbulbOff, label: '背光 −', name: '降低键盘背光亮度' },
  { key: 'illuminationUp' as const, icon: Lightbulb, label: '背光 +', name: '提高键盘背光亮度' },
]
</script>

<template>
  <div class="no-scrollbar flex h-full flex-col items-center overflow-y-auto px-5 pt-2 pb-6">
    <div class="flex w-full max-w-md flex-1 flex-col justify-center gap-8">
      <div class="flex items-center justify-center gap-6">
        <button
          v-for="item in transport"
          :key="item.key"
          type="button"
          class="grid touch-none place-items-center rounded-full transition-all active:scale-95"
          :class="[
            item.key === 'playPause' ? 'size-24 bg-text text-bg' : 'size-16 bg-surface-3 text-text',
            held === item.key && 'scale-95 opacity-80',
          ]"
          :aria-label="item.label"
          @pointerdown="down(item.key, $event)"
          @pointerup="up(item.key, $event)"
          @pointercancel="up(item.key, $event)"
          @click="activate(item.key, $event)"
        >
          <span v-if="!item.icon" class="flex items-center">
            <Play :size="22" fill="currentColor" /><Pause :size="22" fill="currentColor" />
          </span>
          <component :is="item.icon" v-else :size="item.size" fill="currentColor" />
        </button>
      </div>

      <div class="rounded-3xl border border-line bg-surface p-4">
        <div class="flex items-center gap-3">
          <button
            type="button"
            class="grid size-10 shrink-0 place-items-center rounded-full"
            :class="muted ? 'bg-bad/15 text-bad' : 'bg-surface-3 text-text'"
            :aria-label="muted ? '取消静音' : '静音'"
            :aria-pressed="muted"
            @click="toggleMute"
          >
            <component :is="VolumeIcon" :size="20" />
          </button>
          <input
            v-if="state.volume"
            class="slider flex-1"
            type="range"
            min="0"
            max="1"
            step="0.01"
            :value="local"
            :style="{ '--fill': `${local * 100}%` }"
            aria-label="音量"
            @pointerdown="dragging = true"
            @pointerup="dragging = false"
            @pointercancel="dragging = false"
            @input="setVolume(Number(($event.target as HTMLInputElement).value))"
          />
          <div v-else class="flex flex-1 gap-2">
            <button
              v-for="key in ['volumeDown', 'volumeUp'] as const"
              :key="key"
              type="button"
              class="h-10 flex-1 touch-none rounded-xl bg-surface-3 text-[18px]"
              :aria-label="key === 'volumeUp' ? '调高音量' : '调低音量'"
              @pointerdown="down(key, $event)"
              @pointerup="up(key, $event)"
              @pointercancel="up(key, $event)"
              @click="activate(key, $event)"
            >
              {{ key === 'volumeUp' ? '+' : '−' }}
            </button>
          </div>
          <span v-if="state.volume" class="w-9 text-right text-[13px] text-muted tabular-nums">{{ Math.round(local * 100) }}</span>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <button
          v-for="item in extra"
          :key="item.key"
          type="button"
          class="flex h-14 touch-none items-center gap-3 rounded-2xl border border-line px-4 text-left text-[14px] transition-colors"
          :class="held === item.key ? 'bg-surface-3' : 'bg-surface'"
          :aria-label="item.name"
          @pointerdown="down(item.key, $event)"
          @pointerup="up(item.key, $event)"
          @pointercancel="up(item.key, $event)"
          @click="activate(item.key, $event)"
        >
          <component :is="item.icon" :size="19" class="shrink-0 text-muted" />
          {{ item.label }}
        </button>
      </div>
    </div>
  </div>
</template>
