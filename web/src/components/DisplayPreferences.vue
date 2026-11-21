<script setup lang="ts">
import { Check } from '@lucide/vue'
import { computed } from 'vue'
import { state } from '@/lib/connection'
import { releaseAll } from '@/lib/input'
import { settings, type Settings } from '@/lib/settings'
import RangeRow from './RangeRow.vue'
import Segmented from './Segmented.vue'

withDefaults(defineProps<{ showLayout?: boolean }>(), { showLayout: true })
const emit = defineEmits<{ quality: [value: Settings['displayQuality']] }>()
const mode = computed({
  get: () => settings.displayControls,
  set: (value) => {
    releaseAll()
    settings.displayControls = value
  },
})
const qualities = [
  { value: 'auto', label: '自动', detail: '根据连接情况自动调整，画面流畅。' },
  { value: 'battery', label: '省电', detail: '占用带宽更少，帧率更低。' },
  { value: 'sharp', label: '更清晰的文字', detail: '阅读和输入时细节更丰富。' },
  { value: 'original', label: '高清文字 · 无损', detail: '保留原始细节，最高 4K。每秒最多更新 4 次，占用带宽更多。' },
] as const
</script>

<template>
  <Segmented
    v-if="showLayout"
    v-model="mode"
    label="屏幕镜像时的控制方式"
    :options="[
      { value: 'view', label: '仅查看' },
      { value: 'trackpad', label: '触控板' },
      { value: 'keyboard', label: '键盘' },
    ]"
  />
  <fieldset class="mt-3 min-w-0">
    <legend class="mb-2 text-[15px] font-medium">观看画质</legend>
    <button
      v-for="choice in qualities"
      :key="choice.value"
      type="button"
      class="mb-2 flex min-h-16 w-full items-center gap-3 rounded-2xl border px-4 py-3 text-left disabled:opacity-50"
      :class="settings.displayQuality === choice.value ? 'border-accent bg-accent-soft' : 'border-transparent bg-surface-2'"
      :disabled="choice.value === 'original' && !state.features.displayOriginal"
      :aria-pressed="settings.displayQuality === choice.value"
      @click="emit('quality', choice.value)"
    >
      <span class="min-w-0 flex-1">
        <span class="block text-[15px] font-medium">{{ choice.label }}</span>
        <span class="mt-0.5 block text-[13px] leading-snug text-muted">{{ choice.detail }}</span>
        <span v-if="choice.value === 'original' && !state.features.displayOriginal" class="mt-1 block text-[12px] text-muted">
          当前 Mac 的设置不支持此选项。
        </span>
      </span>
      <Check v-if="settings.displayQuality === choice.value" :size="19" class="shrink-0 text-accent" aria-hidden="true" />
    </button>
  </fieldset>
  <RangeRow
    v-if="settings.displayControls !== 'view'"
    v-model="settings.displaySplit"
    label="预览区域"
    :min="0.3"
    :max="0.7"
    :step="0.01"
    :format="(value) => `${Math.round(value * 100)}%`"
  />
  <p class="mt-3 text-[13px] leading-relaxed text-muted">
    捏合或拖动放大的预览以查看不同区域。使用触控板或键盘控制 Mac。
  </p>
</template>
