<script setup lang="ts">
import { AppWindowMac, LaptopMinimal, MoonStar, Power, RefreshCw, Wifi, WifiOff } from '@lucide/vue'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { disconnect, retryNow, state } from '@/lib/connection'
import { deviceModel, lastHost } from '@/lib/device'

// Shown while the phone can't reach the Mac: at launch, and over the app
// when the connection has been gone for a while. Reconnecting carries on in
// the background; this only explains what to check.

const props = withDefaults(defineProps<{ patience?: number }>(), { patience: 2500 })

const mac = computed(() => state.hostName || lastHost.get() || '你的 Mac')
/** A moment to connect before saying the Mac can't be reached. */
const waiting = ref(props.patience > 0)
const phoneOnline = ref(navigator.onLine)
const retrying = ref(false)

let patienceTimer: ReturnType<typeof setTimeout> | undefined
let retryTimer: ReturnType<typeof setTimeout> | undefined
const onOnline = () => (phoneOnline.value = true)
const onOffline = () => (phoneOnline.value = false)

onMounted(() => {
  if (props.patience > 0) patienceTimer = setTimeout(() => (waiting.value = false), props.patience)
  addEventListener('online', onOnline)
  addEventListener('offline', onOffline)
})
onBeforeUnmount(() => {
  clearTimeout(patienceTimer)
  clearTimeout(retryTimer)
  removeEventListener('online', onOnline)
  removeEventListener('offline', onOffline)
})

const connecting = computed(() => waiting.value && phoneOnline.value)

function retry() {
  retrying.value = true
  clearTimeout(retryTimer)
  retryTimer = setTimeout(() => (retrying.value = false), 1500)
  retryNow()
}

const checks = computed(() => [
  { icon: Power, text: `${mac.value} 已开机并处于唤醒状态` },
  { icon: AppWindowMac, text: 'CmdPalm 正在菜单栏中运行' },
  { icon: Wifi, text: `这台 ${deviceModel()} 连接的是同一个 Wi-Fi` },
])
</script>

<template>
  <div class="offline relative flex h-full flex-col items-center overflow-y-auto overscroll-contain bg-bg px-8 text-center" role="status" aria-live="polite">
    <div class="glow pointer-events-none absolute inset-x-0 top-0 h-2/3" aria-hidden="true" />
    <div class="relative flex w-full max-w-sm flex-1 flex-col items-center justify-center py-10">
      <div class="relative mb-8 grid size-36 place-items-center" aria-hidden="true">
        <span class="ring" :class="!connecting && 'slow'" />
        <span class="ring late" :class="!connecting && 'slow'" />
        <div class="device relative grid size-24 place-items-center rounded-[30px] border border-line-strong bg-surface-2">
          <LaptopMinimal :size="44" :stroke-width="1.5" :class="connecting ? 'text-text' : 'text-muted'" />
          <Transition name="pop">
            <span
              v-if="!connecting"
              class="absolute -right-2 -bottom-2 grid size-10 place-items-center rounded-full border-[3px] border-bg"
              :class="phoneOnline ? 'bg-surface-3 text-warn' : 'bg-bad text-white'"
            >
              <MoonStar v-if="phoneOnline" :size="18" :stroke-width="2" />
              <WifiOff v-else :size="18" :stroke-width="2" />
            </span>
          </Transition>
        </div>
      </div>

      <Transition name="fade" mode="out-in">
        <div v-if="connecting" key="connecting" class="flex flex-col items-center">
          <h1 class="text-[22px] font-semibold tracking-tight">正在连接到 {{ mac }}…</h1>
          <p class="mt-2 text-[15px] text-muted">只需片刻。</p>
        </div>

        <div v-else key="offline" class="flex w-full flex-col items-center">
          <h1 class="text-[24px] font-semibold tracking-tight">
            {{ phoneOnline ? `无法连接到 ${mac}` : '此手机处于离线状态' }}
          </h1>
          <p class="mt-2 max-w-xs text-[15px] leading-relaxed text-muted">
            {{
              phoneOnline
                ? '它可能处于睡眠、关机状态，或连接到了其他网络。Mac 恢复后 CmdPalm 会自动重新连接。'
                : `请连接到 Mac 所在的 Wi-Fi。此 ${deviceModel()} 恢复联网后，CmdPalm 会自动重新连接。`
            }}
          </p>

          <ul v-if="phoneOnline" class="mt-7 w-full space-y-1.5 text-left">
            <li v-for="check in checks" :key="check.text" class="flex min-h-12 items-center gap-3 rounded-2xl bg-surface px-4 py-2.5">
              <span class="grid size-8 shrink-0 place-items-center rounded-full bg-accent-soft text-accent">
                <component :is="check.icon" :size="16" :stroke-width="2" />
              </span>
              <span class="text-[14px] leading-snug">{{ check.text }}</span>
            </li>
          </ul>

          <button
            type="button"
            class="mt-7 flex h-12 w-full items-center justify-center gap-2 rounded-2xl bg-accent text-[16px] font-semibold text-accent-text transition-transform active:scale-[0.98]"
            @click="retry"
          >
            <RefreshCw :size="18" :class="retrying && 'animate-spin'" />
            重试
          </button>
          <button type="button" class="mt-2 h-11 w-full rounded-2xl text-[15px] font-medium text-accent" @click="disconnect(true)">
            与其他 Mac 配对
          </button>
        </div>
      </Transition>
    </div>

    <p v-if="!connecting" class="safe-bottom relative flex items-center gap-2 pb-6 text-[13px] text-faint">
      <span class="size-1.5 animate-pulse rounded-full bg-warn" />
      正在尝试重新连接
    </p>
  </div>
</template>

<style scoped>
.glow {
  background: radial-gradient(ellipse 70% 55% at 50% 30%, var(--accent-soft), transparent 70%);
  opacity: 0.7;
}
.device {
  box-shadow:
    0 18px 40px rgb(0 0 0 / 0.35),
    inset 0 1px 0 rgb(255 255 255 / 0.06);
}
:root[data-theme='light'] .device {
  box-shadow:
    0 14px 32px rgb(0 0 0 / 0.12),
    inset 0 1px 0 rgb(255 255 255 / 0.8);
}
.ring {
  position: absolute;
  inset: 18px;
  border-radius: 999px;
  border: 1.5px solid color-mix(in srgb, var(--accent) 55%, transparent);
  animation: ripple 2.4s cubic-bezier(0.2, 0.6, 0.3, 1) infinite;
}
.ring.late {
  animation-delay: 1.2s;
}
.ring.slow {
  border-color: var(--line-strong);
  animation-duration: 4s;
}
.ring.slow.late {
  animation-delay: 2s;
}
@keyframes ripple {
  from {
    transform: scale(0.75);
    opacity: 0.9;
  }
  to {
    transform: scale(1.35);
    opacity: 0;
  }
}
.fade-enter-active,
.fade-leave-active {
  transition:
    opacity 220ms ease,
    transform 220ms ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(6px);
}
.pop-enter-active {
  transition: transform 260ms cubic-bezier(0.3, 1.6, 0.5, 1);
}
.pop-enter-from {
  transform: scale(0);
}
</style>
