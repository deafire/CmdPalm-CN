<script setup lang="ts">
import {
  ChevronRight,
  Copy,
  Download,
  Hand,
  Keyboard,
  LayoutGrid,
  Lock,
  LockOpen,
  LogOut,
  Maximize,
  Minimize,
  Monitor,
  RotateCcw,
  Touchpad,
  Unplug,
} from '@lucide/vue'
import { computed, nextTick, ref } from 'vue'
import { appNames } from '@/lib/apps'
import { describe } from '@/lib/actions'
import { disconnect, labels, notify, state } from '@/lib/connection'
import { actionProblem, clone } from '@/lib/deck'
import { deviceModel } from '@/lib/device'
import { canFullscreen, display, install, installHint, toggleFullscreen } from '@/lib/display'
import { hapticsSupported, switchOnly } from '@/lib/haptics'
import type { Action } from '@/lib/protocol'
import { lazy } from '@/lib/reload'
import { screen, startViewing } from '@/lib/screen'
import { DECK_SIZE, resetSettings, settings, type GestureMap, type GestureSlot, type Settings } from '@/lib/settings'
import { wakeLockSupported } from '@/lib/wakeLock'
import { voiceSupported } from '@/lib/voice'
import ActionEditor from './ActionEditor.vue'
import DisplayPreferences from './DisplayPreferences.vue'
import RangeRow from './RangeRow.vue'
import Segmented from './Segmented.vue'
import Sheet from './Sheet.vue'
import Toggle from './Toggle.vue'

const CopySettingsSheet = lazy(() => import('./CopySettingsSheet.vue'))
const BackupSheet = lazy(() => import('./BackupSheet.vue'))
const emit = defineEmits<{ close: [] }>()
const secure = computed(() => state.features.secure || location.protocol === 'https:')
const dictationHelp = computed(() => {
  if (state.features.voice && voiceSupported()) {
    return '语音输入已就绪。点按输入面板中的麦克风按钮，即可在 Mac 上进行听写。'
  }
  if (!secure.value) {
    return state.features.voice
      ? '语音输入需要加密连接，此浏览器才能使用麦克风。在 Mac 上打开 CmdPalm 的“设置 → 手机设置 → 加密连接”。'
      : '要进行听写，请通过加密连接打开 CmdPalm（Mac CmdPalm“设置 → 手机设置 → 加密连接”），并在“通用”中开启“允许来自设备的听写”。'
  }
  if (!state.features.voice) {
    return '此 Mac 上的语音输入已关闭。请在 CmdPalm“设置 → 通用”中开启“允许来自设备的听写”和“语音识别”。'
  }
  return '此浏览器无法在此访问麦克风。请在此设备上信任 CmdPalm 的证书，或使用支持通过 HTTPS 采集麦克风的浏览器。'
})
const confirmForget = ref(false)
const confirmReset = ref(false)
const showCopy = ref(false)
const showBackup = ref(false)
const sheet = ref<InstanceType<typeof Sheet>>()
const features = [
  { id: 'trackpad', label: '触控板', icon: Touchpad },
  { id: 'gestures', label: '手势', icon: Hand },
  { id: 'keyboard', label: '键盘', icon: Keyboard },
  { id: 'display', label: '屏幕镜像', icon: Monitor },
  { id: 'deck', label: '快捷面板', icon: LayoutGrid },
] as const
type Feature = (typeof features)[number]['id']
const feature = ref<Feature>(features.some((item) => item.id === settings.tab) ? (settings.tab as Feature) : 'trackpad')
const gestureFingers = ref<'3' | '4'>('3')
const fingers = computed(() => (gestureFingers.value === '3' ? 3 : 4))

async function selectFeature(id: Feature) {
  feature.value = id
  confirmForget.value = false
  confirmReset.value = false
  await nextTick()
  sheet.value?.resetScroll()
}
function featureKey(event: KeyboardEvent, index: number) {
  if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return
  let next: number
  if (event.key === 'ArrowRight') next = (index + 1) % features.length
  else if (event.key === 'ArrowLeft') next = (index - 1 + features.length) % features.length
  else if (event.key === 'Home') next = 0
  else if (event.key === 'End') next = features.length - 1
  else return
  event.preventDefault()
  void selectFeature(features[next]!.id)
  const tabs = (event.currentTarget as HTMLElement).parentElement?.querySelectorAll<HTMLButtonElement>('[role="tab"]')
  tabs?.[next]?.focus()
}
function quality(value: Settings['displayQuality']) {
  const resume = screen.active && (screen.status === 'connecting' || screen.status === 'live') && value !== settings.displayQuality
  settings.displayQuality = value
  if (resume) void startViewing()
}

const SLOTS: { slot: GestureSlot; label: string }[] = [
  { slot: 'up', label: '向上轻扫' },
  { slot: 'down', label: '向下轻扫' },
  { slot: 'left', label: '向左轻扫' },
  { slot: 'right', label: '向右轻扫' },
  { slot: 'tap', label: '轻点' },
  { slot: 'pinchIn', label: '捏合' },
  { slot: 'pinchOut', label: '张开' },
]
const gesture = ref<{ fingers: 3 | 4; slot: GestureSlot; label: string; draft: Action | null } | null>(null)
const gestureProblem = computed(() => (gesture.value?.draft ? actionProblem(gesture.value.draft) : ''))
function mapFor(count: 3 | 4): GestureMap {
  return count === 3 ? settings.threeFinger : settings.fourFinger
}
function editGesture(count: 3 | 4, slot: GestureSlot, label: string) {
  const current = mapFor(count)[slot]
  gesture.value = { fingers: count, slot, label, draft: current ? clone(current) : null }
}
function saveGesture() {
  const g = gesture.value
  if (!g || gestureProblem.value) return
  mapFor(g.fingers)[g.slot] = g.draft
  gesture.value = null
}
function forget() {
  disconnect(true)
  emit('close')
}
function reset() {
  resetSettings()
  confirmReset.value = false
  notify('设置已恢复默认值。')
}
const pct = (v: number) => `${Math.round(v * 100)}%`
const times = (v: number) => `${v.toFixed(1)}×`
</script>

<template>
  <Sheet ref="sheet" title="设置" full @close="emit('close')">
    <section class="card">
      <div class="flex items-center gap-3 py-3">
        <div class="min-w-0 flex-1">
          <div class="truncate text-[16px] font-semibold">{{ state.hostName || 'Mac' }}</div>
          <div class="text-[13px] text-muted">
            CmdPalm {{ state.hostVersion }} · {{ state.status === 'connected' ? `已连接 · ${state.latency || '<1'} ms` : '正在重新连接…' }}
          </div>
        </div>
        <span
          class="flex shrink-0 items-center gap-1 rounded-full px-2.5 py-1 text-[12px] font-medium"
          :class="secure ? 'bg-good/15 text-good' : 'bg-warn/15 text-warn'"
        >
          <Lock v-if="secure" :size="12" /><LockOpen v-else :size="12" />
          {{ secure ? '已加密' : '未加密' }}
        </span>
      </div>
      <p v-if="!secure" class="pb-3 text-[13px] leading-snug text-muted">
        同一 Wi-Fi 下的其他人可能看到你输入的内容。要设置加密连接，请在 Mac 上打开 CmdPalm 的设置，
        选择<b>“手机设置 → 加密连接”</b>。语音输入和部分手机功能也需要它。
      </p>
    </section>

    <div>
      <div class="sticky top-0 z-10 -mx-1 mt-3 bg-surface px-1 py-2">
        <div class="grid grid-cols-5 rounded-2xl bg-surface-2 p-1" role="tablist" aria-label="功能设置">
          <button
            v-for="(item, index) in features"
            :id="`settings-tab-${item.id}`"
            :key="item.id"
            type="button"
            role="tab"
            :aria-selected="feature === item.id"
            aria-controls="settings-feature-panel"
            :tabindex="feature === item.id ? 0 : -1"
            class="flex min-h-13 min-w-0 flex-col items-center justify-center gap-1 rounded-xl px-0.5 py-2 text-[11px] font-medium transition-colors"
            :class="feature === item.id ? 'bg-surface text-text shadow-sm' : 'text-muted'"
            @click="selectFeature(item.id)"
            @keydown="featureKey($event, index)"
          >
            <component :is="item.icon" :size="18" :class="feature === item.id && 'text-accent'" aria-hidden="true" />
            {{ item.label }}
          </button>
        </div>
      </div>
      <p class="mb-3 mt-1 text-center text-[12px] text-muted">更改会自动保存在本设备上。</p>
      <section id="settings-feature-panel" role="tabpanel" :aria-labelledby="`settings-tab-${feature}`">
        <template v-if="feature === 'trackpad'">
          <h3 class="section mt-0!">指针与点按</h3>
          <section class="card">
            <RangeRow v-model="settings.pointerSpeed" label="指针速度" :min="0.2" :max="4" :step="0.05" :format="times" />
            <Toggle v-model="settings.tapToClick" label="轻点点按" />
            <Toggle v-model="settings.twoFingerTapRightClick" label="双指轻点以右键单击" />
            <Toggle
              v-model="settings.clickButtons"
              label="显示点击按钮"
              hint="在触控板下方显示“单击”和“右键单击”按钮。按住其中一个并移动另一根手指即可拖动。"
            />
          </section>
          <h3 class="section">指针与拖动</h3>
          <section class="card">
            <RangeRow v-model="settings.pointerAcceleration" label="加速度" :min="0" :max="1" :format="pct" />
            <Segmented
              v-model="settings.longPress"
              label="触摸并按住"
              :options="[
                { value: 'drag', label: '拖动' },
                { value: 'rightClick', label: '右键单击' },
                { value: 'off', label: '无' },
              ]"
            />
            <Toggle v-model="settings.tapAndDrag" label="轻点后拖动" hint="轻点后快速再次触摸即可开始拖动。" />
            <Toggle v-model="settings.dragLock" label="拖动锁定" hint="抬起手指后拖动仍会继续，直到你再次轻点。" />
            <Toggle v-model="settings.showTouches" label="显示触摸点" />
          </section>
          <h3 class="section">滚动</h3>
          <section class="card">
            <RangeRow v-model="settings.scrollSpeed" label="滚动速度" :min="0.2" :max="4" :step="0.05" :format="times" />
            <Toggle v-model="settings.naturalScroll" label="自然滚动" hint="内容随手指移动。" />
            <Toggle v-model="settings.momentum" label="惯性滚动" hint="轻扫后继续滚动。" />
            <Segmented
              v-model="settings.scrollStrip"
              label="滚动条"
              :options="[
                { value: 'short', label: '短' },
                { value: 'long', label: '长' },
                { value: 'off', label: '隐藏' },
              ]"
            />
          </section>
          <template v-if="settings.scrollStrip !== 'off'">
            <h3 class="section">滚动条选项</h3>
            <section class="card">
              <Segmented
                v-model="settings.scrollStripWidth"
                label="宽度"
                :options="[
                  { value: 'normal', label: '正常' },
                  { value: 'wide', label: '宽' },
                  { value: 'wider', label: '超宽' },
                ]"
              />
              <Segmented
                v-model="settings.scrollStripSide"
                label="位置"
                :options="[
                  { value: 'right', label: '右' },
                  { value: 'left', label: '左' },
                ]"
              />
              <Toggle
                v-model="settings.scrollStripEdge"
                label="位于屏幕边缘"
                hint="沿手机侧边或保护壳滑动手指，无需查看即可滚动。"
              />
              <Toggle
                v-if="settings.scrollStrip === 'short'"
                v-model="settings.scrollHold"
                label="按住持续滚动"
                hint="将滚动条的滑块拖到顶部或底部并按住。"
              />
            </section>
          </template>
        </template>

        <template v-else-if="feature === 'gestures'">
          <h3 class="section">双指</h3>
          <section class="card">
            <Toggle
              v-model="settings.pinchToZoom"
              label="捏合缩放"
              :hint="settings.pinchStyle === 'keys' ? '发送 ⌘+ 和 ⌘−。' : '流畅缩放照片、地图、PDF 和网页。'"
            />
            <Toggle v-model="settings.rotateGesture" label="旋转" hint="转动双指以旋转照片、地图和 PDF。" />
            <Toggle
              v-model="settings.smartZoom"
              label="智能缩放"
              hint="用双指双击可放大网页或 PDF，再次双击可缩小。右键单击的等待时间会稍长。"
            />
          </section>
          <template v-if="settings.pinchToZoom">
            <h3 class="section">缩放方式</h3>
            <section class="card">
              <Segmented
                v-model="settings.pinchStyle"
                label="捏合"
                :options="[
                  { value: 'smooth', label: '平滑缩放' },
                  { value: 'keys', label: '⌘+ 和 ⌘− 按键' },
                ]"
              />
            </section>
          </template>
          <h3 class="section">三指与四指</h3>
          <section class="card">
            <Toggle
              v-model="settings.threeFingerDrag"
              label="三指拖动"
              hint="移动三根手指可拖动窗口和选择文本。此操作会替代三指轻扫；四指手势仍然可用。"
            />
          </section>
          <Segmented
            v-model="gestureFingers"
            aria-label="自定义手势的手指数量"
            :options="[
              { value: '3', label: '三指' },
              { value: '4', label: '四指' },
            ]"
            class="mt-3"
          />
          <p class="mb-3 text-[13px] text-muted">轻点某个操作可更改或关闭它。</p>
          <p v-if="fingers === 3 && settings.threeFingerDrag" class="mb-3 text-[13px] leading-snug text-warn">
            三指拖动已开启。请先在上方关闭它，才能使用三指轻扫操作。
          </p>
          <section class="card">
            <button
              v-for="s in SLOTS"
              :key="s.slot"
              type="button"
              class="flex min-h-13 w-full items-center gap-2 border-t border-line py-2 text-left first:border-t-0"
              @click="editGesture(fingers, s.slot, `${fingers === 3 ? '三指' : '四指'}${s.label.toLowerCase()}`)"
            >
              <span class="flex-1 text-[15px]">{{ s.label }}</span>
              <span class="max-w-[55%] text-right text-[13px] leading-snug text-muted">
                {{ describe(mapFor(fingers)[s.slot], labels, appNames) }}
              </span>
              <ChevronRight :size="16" class="shrink-0 text-muted" aria-hidden="true" />
            </button>
          </section>
        </template>

        <template v-else-if="feature === 'keyboard'">
          <h3 class="section">键盘布局</h3>
          <section class="card">
            <Segmented
              v-model="settings.keyboard"
              label="键盘"
              :options="[
                { value: 'auto', label: '自动' },
                { value: 'mac', label: 'Mac' },
                { value: 'custom', label: '自定义' },
                { value: 'phone', label: '输入' },
              ]"
            />
            <p class="pb-2 text-[13px] leading-snug text-muted">
              自动模式在小屏幕上使用手机键盘，在屏幕够大时使用 Mac 布局。可在“键盘 → 自定义”中创建自己的布局。
            </p>
            <Segmented
              v-model="settings.functionRow"
              label="顶行按键"
              :options="[
                { value: 'media', label: '媒体与亮度' },
                { value: 'function', label: 'F1 – F12' },
              ]"
            />
            <Toggle
              v-model="settings.sidewaysKeyboard"
              label="横向键盘"
              hint="即使旋转锁定，也能将 Mac 键盘横过来铺满竖屏手机屏幕。"
            />
            <Segmented
              v-if="settings.sidewaysKeyboard"
              v-model="settings.sidewaysTurn"
              label="旋转手机"
              :options="[
                { value: 'left', label: '向左' },
                { value: 'right', label: '向右' },
              ]"
            />
            <Toggle v-model="settings.keyRepeat" label="按键重复" hint="按住按键时重复输入，速度采用 Mac 的设置。" />
          </section>
          <h3 class="section">输入</h3>
          <section class="card">
            <Toggle
              v-model="settings.liveTyping"
              label="实时输入"
              hint="输入时文字即时显示在 Mac 上（包括自动更正）。关闭后可先编辑文字再发送。"
            />
          </section>
          <h3 class="section">语音输入设置</h3>
          <section class="card py-3">
            <p class="text-[13px] leading-relaxed text-muted">
              {{ dictationHelp }}
            </p>
          </section>
          <h3 class="section">文本兼容性</h3>
          <section class="card">
            <Segmented
              v-model="settings.textMode"
              label="发送文本为"
              :options="[
                { value: 'unicode', label: '字符' },
                { value: 'keystrokes', label: '按键' },
                { value: 'paste', label: '粘贴' },
              ]"
            />
            <p class="pb-3 text-[13px] leading-snug text-muted">
              字符模式几乎适用于所有场景。游戏和远程桌面请使用按键模式，超长文本请使用粘贴模式。
            </p>
          </section>
        </template>

        <template v-else-if="feature === 'display'">
          <p class="intro">选择查看 Mac 屏幕的方式。开始观看后，可在“屏幕镜像”标签中选择显示器。</p>
          <DisplayPreferences @quality="quality" />
        </template>

        <template v-else-if="feature === 'deck'">
          <p class="intro">让快捷按钮在此设备上更方便点按。</p>
          <section class="card">
            <RangeRow v-model="settings.deckButtonSize" label="按钮大小" :min="DECK_SIZE.min" :max="DECK_SIZE.max" :step="0.1" :format="pct" />
            <p class="pb-3 text-[13px] leading-snug text-muted">
              按钮越小，每页可容纳越多。屏幕更宽时（如手机横放）可显示更多列。
            </p>
          </section>
          <p class="mt-4 text-[13px] leading-relaxed text-muted">
            要添加或排列快捷方式，请打开“快捷面板”并轻点“编辑”。快捷面板页面在此 Mac 配对的设备间共享；按钮大小在此单独设置。
          </p>
        </template>
      </section>
    </div>
    <h3 class="section">本机（{{ deviceModel() }}）</h3>
    <section class="card">
      <div v-if="!display.standalone" class="border-b border-line py-3">
        <p class="text-[13px] leading-snug text-muted">{{ installHint() }}</p>
        <div v-if="display.installable || canFullscreen()" class="mt-2 flex flex-wrap gap-2">
          <button v-if="display.installable" type="button" class="pill" @click="install">
            <Download :size="15" />
            安装应用
          </button>
          <button v-if="canFullscreen()" type="button" class="pill" @click="toggleFullscreen">
            <Minimize v-if="display.fullscreen" :size="15" />
            <Maximize v-else :size="15" />
            {{ display.fullscreen ? '退出全屏' : '全屏' }}
          </button>
        </div>
      </div>
      <label class="block py-2">
        <span class="text-[15px]">名称</span>
        <input
          v-model="settings.deviceName"
          :placeholder="deviceModel()"
          maxlength="40"
          autocomplete="off"
          aria-label="在 Mac 上显示的名称"
          class="mt-2 h-11 w-full rounded-xl border border-line bg-surface-2 px-3 text-[16px] outline-none focus:border-accent"
        />
        <span class="mt-1 block text-[13px] text-muted">在 Mac 上显示。下次连接时生效。</span>
      </label>
      <Segmented
        v-model="settings.theme"
        label="外观"
        :options="[
          { value: 'system', label: '自动' },
          { value: 'dark', label: '深色' },
          { value: 'light', label: '浅色' },
        ]"
      />
      <template v-if="hapticsSupported">
        <Toggle
          v-model="settings.haptics"
          label="触觉反馈"
          :hint="switchOnly ? 'iPhone 仅在轻点时提供触觉反馈，轻扫或按住时不会。' : undefined"
        />
        <Toggle
          v-if="settings.haptics"
          v-model="settings.keyHaptics"
          label="按键触觉反馈"
          hint="在键盘和修饰键上感受每次按键的反馈。"
        />
      </template>
      <Toggle
        v-model="settings.keepAwake"
        label="保持屏幕常亮"
        :hint="wakeLockSupported ? '连接到 Mac 期间。' : secure ? '此浏览器不支持。' : '需要加密连接。'"
        :disabled="!wakeLockSupported"
      />
      <Toggle v-model="settings.rememberDevice" label="记住此设备" hint="在共用设备上请关闭。下次连接时生效。" />
    </section>

    <h3 class="section">已保存的设置</h3>
    <section class="flex flex-col gap-2">
      <button type="button" class="action" @click="showCopy = true">
        <Copy :size="18" />
        <span class="flex-1">从其他设备复制设置</span>
        <ChevronRight :size="16" />
      </button>
      <button type="button" class="action" @click="showBackup = true">
        <Download :size="18" />
        <span class="flex-1">备份或恢复此设备</span>
        <ChevronRight :size="16" />
      </button>
    </section>
    <h3 class="section">重置与断开</h3>
    <section class="flex flex-col gap-2">
      <button type="button" class="action" :aria-expanded="confirmReset" @click="((confirmReset = !confirmReset), (confirmForget = false))">
        <RotateCcw :size="18" />
        重置此设备上的设置
      </button>
      <div v-if="confirmReset" class="rounded-2xl border border-bad/30 bg-bad/5 p-4">
        <p class="text-[15px] font-semibold">将设置恢复为默认值？</p>
        <p class="mt-1 text-[13px] leading-relaxed text-muted">设备名称、自定义键盘、快捷面板和配对信息将保留。</p>
        <div class="mt-3 flex flex-wrap gap-2">
          <button type="button" class="pill bg-bad! text-white!" @click="reset">恢复默认</button>
          <button type="button" class="pill" @click="confirmReset = false">取消</button>
        </div>
      </div>
      <button type="button" class="action" @click="(disconnect(false), emit('close'))">
        <Unplug :size="18" />
        断开
      </button>
      <button
        type="button"
        class="action text-bad!"
        :aria-expanded="confirmForget"
        @click="((confirmForget = !confirmForget), (confirmReset = false))"
      >
        <LogOut :size="18" />
        忘记此 Mac
      </button>
      <div v-if="confirmForget" class="rounded-2xl border border-bad/30 bg-bad/5 p-4">
        <p class="text-[15px] font-semibold">忘记此 Mac？</p>
        <p class="mt-1 text-[13px] leading-relaxed text-muted">
          断开连接并移除此设备的配对信息。重新连接时需要再次配对。
        </p>
        <div class="mt-3 flex flex-wrap gap-2">
          <button type="button" class="pill bg-bad! text-white!" @click="forget">忘记并断开</button>
          <button type="button" class="pill" @click="confirmForget = false">取消</button>
        </div>
      </div>
    </section>
    <p class="py-6 text-center text-[12px] leading-relaxed text-muted">
      <a href="https://cmdpalm.app" target="_blank" rel="noopener" class="underline underline-offset-2">CmdPalm</a>
      是免费开源软件，遵循
      <a href="https://github.com/rahatsagor/CmdPalm/blob/main/LICENSE" target="_blank" rel="noopener" class="underline underline-offset-2">
        GNU AGPL v3.
      </a>
    </p>

    <CopySettingsSheet v-if="showCopy" @close="showCopy = false" />
    <BackupSheet v-if="showBackup" @close="showBackup = false" />
    <Sheet v-if="gesture" :title="gesture.label" @close="gesture = null">
      <template #actions>
        <button
          type="button"
          class="h-11 rounded-full bg-accent px-4 text-[14px] font-semibold text-accent-text disabled:opacity-40"
          :disabled="!!gestureProblem"
          @click="saveGesture"
        >
          保存
        </button>
      </template>
      <Toggle
        :model-value="gesture.draft !== null"
        label="已启用"
        @update:model-value="(on) => gesture && (gesture.draft = on ? { kind: 'system', name: 'missionControl' } : null)"
      />
      <ActionEditor v-if="gesture.draft" v-model="gesture.draft" class="mt-2" />
      <p v-if="gestureProblem" class="mt-2 text-[13px] text-bad">{{ gestureProblem }}</p>
    </Sheet>
  </Sheet>
</template>

<style scoped>
@reference '../style.css';
.intro {
  @apply mb-4 text-[13px] leading-relaxed text-muted;
}
.section {
  @apply mt-5 mb-2 px-1 text-[13px] font-medium text-muted;
}
.intro + .section {
  @apply mt-0;
}
.card {
  @apply rounded-2xl bg-surface-2 px-4;
}
.action {
  @apply flex min-h-13 w-full items-center gap-3 rounded-xl bg-surface-2 px-4 py-3 text-left text-[14px] font-medium;
}
.action > svg {
  @apply shrink-0;
}
.pill {
  @apply flex min-h-11 items-center justify-center gap-1.5 rounded-xl bg-surface-3 px-3.5 py-2 text-[14px] font-medium;
}
</style>
