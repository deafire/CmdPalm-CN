<script setup lang="ts">
import { Download, FileJson, Upload } from '@lucide/vue'
import { ref } from 'vue'
import { exportBackup, MAX_BACKUP_BYTES, readBackup, restoreBackup, type DeviceBackup } from '@/lib/backup'
import { notify } from '@/lib/connection'
import Sheet from './Sheet.vue'

const emit = defineEmits<{ close: [] }>()
const picker = ref<HTMLInputElement>()
const preview = ref<DeviceBackup | null>(null)
const error = ref('')
const reading = ref(false)

function download() {
  error.value = ''
  try {
    const url = URL.createObjectURL(new Blob([exportBackup()], { type: 'application/json' }))
    const link = document.createElement('a')
    link.href = url
    link.download = `cmdpalm-device-${new Date().toISOString().slice(0, 10)}.json`
    document.body.append(link)
    link.click()
    link.remove()
    setTimeout(() => URL.revokeObjectURL(url), 10_000)
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '无法导出当前设置。'
  }
}

async function choose(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file || reading.value) return
  error.value = ''
  preview.value = null
  reading.value = true
  try {
    if (file.size > MAX_BACKUP_BYTES) throw new Error('此备份文件过大，无法打开。')
    preview.value = readBackup(await file.text())
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '无法读取此备份文件。'
  } finally {
    reading.value = false
  }
}

function restore() {
  if (!preview.value) return
  try {
    if (!restoreBackup(preview.value)) return
    notify('已恢复本设备的设置和自定义键盘。', 'info', 'settings')
    emit('close')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '无法恢复此备份文件。'
  }
}
</script>

<template>
  <Sheet title="设备备份" @close="emit('close')">
    <p class="text-[14px] leading-relaxed text-muted">保存触控板、键盘、手势和外观设置，以及所有自定义键盘。你可以在本设备或其他手机、平板上恢复该文件。</p>
    <div class="mt-4 flex flex-col gap-2">
      <button type="button" class="action" @click="download"><Download :size="18" /> 导出设备备份</button>
      <button type="button" class="action" :disabled="reading" @click="picker?.click()"><Upload :size="18" /> {{ reading ? '正在读取备份…' : '选择要恢复的备份' }}</button>
      <input ref="picker" class="hidden" type="file" accept=".json,application/json" aria-label="设备备份文件" @change="choose" />
    </div>
    <p v-if="error" role="alert" class="mt-3 text-[14px] text-bad">{{ error }}</p>

    <section v-if="preview" class="mt-5 rounded-2xl border border-line bg-surface-2 p-4">
      <div class="flex items-center gap-2 text-[15px] font-semibold"><FileJson :size="20" /> 可以恢复</div>
      <p v-if="preview.exportedAt" class="mt-1 text-[13px] text-muted">保存于 {{ new Date(preview.exportedAt).toLocaleDateString() }}</p>
      <p class="mt-3 text-[14px] leading-relaxed">这将替换本设备的设置及其 {{ preview.setup.keyboards.length }} 个键盘。如需保留副本，请先导出当前设置。</p>
      <ul class="mt-2 list-inside list-disc text-[13px] text-muted">
        <li v-for="board in preview.setup.keyboards" :key="board.id">{{ board.name }}</li>
      </ul>
      <button type="button" class="action mt-4 w-full bg-accent! text-accent-text!" @click="restore">恢复备份</button>
      <button type="button" class="mt-2 h-10 w-full text-[14px] text-muted" @click="preview = null">取消恢复</button>
    </section>
    <p class="mt-4 text-[13px] leading-relaxed text-muted">设备名称和配对信息保持不变。备份不包含配对令牌。快捷面板页面由 Mac 共享；可在 Mac 上的 CmdPalm“设置 → 快捷面板”中导出。</p>
  </Sheet>
</template>

<style scoped>
@reference '../style.css';
.action {
  @apply flex min-h-12 items-center justify-center gap-2 rounded-xl bg-surface-2 px-3 text-[15px] font-medium disabled:opacity-40;
}
</style>
