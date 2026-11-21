<script setup lang="ts">
import { ArrowLeft, ChevronRight, LoaderCircle, MonitorSmartphone, Smartphone, Tablet } from '@lucide/vue'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { keyboards } from '@/lib/customKeyboards'
import type { SettingsSource } from '@/lib/protocol'
import { ago, cancelCopy, copier, COPY_CATEGORIES, copyFrom, listDevices, requestCopy, type CopyCategory, type CopyPreview } from '@/lib/settingsSync'
import Sheet from './Sheet.vue'

const emit = defineEmits<{ close: [] }>()
const chosen = ref<SettingsSource | null>(null)
const preview = ref<CopyPreview | null>(null)
const categories = ref<CopyCategory[]>([])
const boards = ref<string[]>([])
const available = computed(() => COPY_CATEGORIES.filter((category) => category.keys.some((key) => Object.hasOwn(preview.value?.settings ?? {}, key))))
const selectedCount = computed(() => categories.value.length + boards.value.length)

onMounted(listDevices)
onBeforeUnmount(cancelCopy)

function icon(model: string) {
  if (/iPad|tablet|平板/i.test(model)) return Tablet
  if (/iPhone|iPod|phone|手机/i.test(model)) return Smartphone
  return MonitorSmartphone
}

async function choose(device: SettingsSource) {
  chosen.value = device
  preview.value = null
  categories.value = []
  boards.value = []
  const result = await requestCopy(device)
  if (chosen.value?.id === device.id) preview.value = result
}

function back() {
  cancelCopy()
  chosen.value = null
  preview.value = null
}

function copySelected() {
  if (preview.value && copyFrom(preview.value, { categories: categories.value, keyboards: boards.value })) emit('close')
}

function selectAll() {
  const all = selectedCount.value === available.value.length + (preview.value?.keyboards.length ?? 0)
  categories.value = all ? [] : available.value.map((category) => category.id)
  boards.value = all ? [] : (preview.value?.keyboards.map((board) => board.id) ?? [])
}
</script>

<template>
  <Sheet title="从设备复制" @close="emit('close')">
    <template v-if="chosen">
      <button type="button" class="mb-3 flex min-h-10 items-center gap-1.5 text-[14px] font-medium text-muted" @click="back"><ArrowLeft :size="16" /> 设备</button>
      <p class="text-[16px] font-semibold break-words">选择要从 {{ chosen.name }} 复制的内容</p>
      <p class="mt-1.5 text-[14px] leading-snug text-muted">仅更改你选择的内容，其余设置保持不变。</p>

      <div v-if="copier.copying" class="flex items-center justify-center gap-3 py-10 text-muted" aria-live="polite">
        <LoaderCircle :size="20" class="animate-spin" /> 正在读取已保存的设置…
      </div>
      <div v-else-if="!preview" class="py-6 text-center">
        <p class="text-[14px] text-muted">无法读取此设备的设置。请检查连接后重试。</p>
        <button type="button" class="action mt-4 w-full" @click="choose(chosen)">重试</button>
      </div>
      <template v-else>
        <div class="mt-3 flex min-h-10 items-center justify-between">
          <span class="text-[13px] text-muted">{{ selectedCount ? `已选择 ${selectedCount} 项` : '选择需要的项目' }}</span>
          <button v-if="available.length || preview.keyboards.length" type="button" class="px-2 py-2 text-[13px] font-medium text-accent" @click="selectAll">
            {{ selectedCount === available.length + preview.keyboards.length ? '取消全选' : '全选' }}
          </button>
        </div>
        <div v-if="available.length" class="rounded-2xl bg-surface-2 px-4">
          <label v-for="category in available" :key="category.id" class="choice border-t border-line first:border-t-0">
            <span class="min-w-0 flex-1">
              <span class="block text-[15px] font-medium">{{ category.label }}</span>
              <span class="block text-[13px] leading-snug text-muted">{{ category.hint }}</span>
            </span>
            <input v-model="categories" type="checkbox" :value="category.id" :aria-label="category.label" />
          </label>
        </div>

        <template v-if="preview.keyboards.length">
          <p class="mt-5 text-[15px] font-semibold">自定义键盘</p>
          <p class="mt-1 mb-3 text-[13px] leading-snug text-muted">将添加新键盘，已复制过的键盘会就地更新，其他键盘保持不变。</p>
          <div class="rounded-2xl bg-surface-2 px-4">
            <label v-for="board in preview.keyboards" :key="board.id" class="choice border-t border-line first:border-t-0">
              <span class="min-w-0 flex-1">
                <span class="block text-[15px] font-medium break-words">{{ board.name }}</span>
                <span class="block text-[13px] text-muted">{{ keyboards.boards.some((b) => b.id === board.id) ? '更新现有' : '添加键盘' }} · {{ board.cols }} × {{ board.rows }} · {{ board.keys.length }} 个按键</span>
              </span>
              <input v-model="boards" type="checkbox" :value="board.id" :aria-label="`复制 ${board.name}`" />
            </label>
          </div>
        </template>
        <p class="mt-4 text-[13px] leading-snug text-muted">快捷面板的页面和按钮已与此 Mac 配对的所有设备共享，无需复制。</p>
        <p v-if="!available.length && !preview.keyboards.length" class="py-4 text-[14px] text-muted">此设备没有可复制的已保存选项。</p>
        <div class="sticky -bottom-5 -mx-5 mt-4 bg-surface px-5 pt-2 pb-5">
          <button type="button" class="action w-full bg-accent! text-accent-text!" :disabled="!selectedCount" @click="copySelected">复制所选</button>
        </div>
      </template>
    </template>

    <div v-else-if="copier.loading" class="flex flex-col items-center gap-3 py-10 text-muted" aria-live="polite">
      <LoaderCircle :size="24" class="animate-spin" />
      <span class="text-[14px]">正在查找设备…</span>
    </div>
    <div v-else-if="copier.failed" class="py-8 text-center">
      <p class="text-[15px] font-medium">无法从 Mac 获取设备列表。</p>
      <p class="mt-1 text-[14px] text-muted">请检查连接后重试。</p>
      <button type="button" class="action mt-4 w-full" @click="listDevices">重试</button>
    </div>
    <div v-else-if="!copier.devices?.length" class="py-8 text-center">
      <MonitorSmartphone :size="30" class="mx-auto text-faint" />
      <p class="mt-3 text-[15px] font-medium">没有其他可复制的设备</p>
      <p class="mx-auto mt-1 max-w-xs text-[14px] leading-snug text-muted">其他手机和平板连接到此 Mac 并更改设置后，其设置会显示在此处。</p>
    </div>
    <template v-else>
      <p class="pb-3 text-[14px] leading-snug text-muted">选择一台已配对的设备，然后选择要复制的设置或自定义键盘。</p>
      <ul class="rounded-2xl bg-surface-2 px-4">
        <li v-for="device in copier.devices" :key="device.id" class="border-t border-line first:border-t-0">
          <button type="button" class="flex min-h-14 w-full items-center gap-3 py-2 text-left" @click="choose(device)">
            <component :is="icon(device.model)" :size="20" class="shrink-0 text-muted" />
            <span class="min-w-0 flex-1">
              <span class="block truncate text-[15px] font-medium">{{ device.name }}</span>
              <span class="block truncate text-[13px] text-muted">{{ device.model }} · 更新于 {{ ago(device.updatedAt) }}</span>
            </span>
            <ChevronRight :size="16" class="shrink-0 text-faint" />
          </button>
        </li>
      </ul>
    </template>
  </Sheet>
</template>

<style scoped>
@reference '../style.css';
.action {
  @apply flex h-12 items-center justify-center gap-2 rounded-xl bg-surface-2 text-[15px] font-medium disabled:opacity-40;
}
.choice {
  @apply flex min-h-16 cursor-pointer items-center gap-3 py-3;
}
.choice input {
  @apply size-5 shrink-0 accent-accent;
}
</style>
