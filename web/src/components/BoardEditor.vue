<script setup lang="ts">
import { ArrowLeft, ArrowRight, Copy, Minus, Plus, Trash2 } from '@lucide/vue'
import { computed, ref } from 'vue'
import { canResize, keyboards, LIMITS, type CustomKeyboard } from '@/lib/customKeyboards'
import Sheet from './Sheet.vue'
import Toggle from './Toggle.vue'

const props = defineProps<{ board: CustomKeyboard }>()
const emit = defineEmits<{ duplicate: []; remove: []; close: [] }>()

const name = ref(props.board.name)
const confirming = ref(false)
const blocked = ref<'cols' | 'rows' | null>(null)
const index = computed(() => keyboards.boards.findIndex((board) => board.id === props.board.id))

function move(by: number) {
  const from = index.value
  const to = from + by
  if (from < 0 || to < 0 || to >= keyboards.boards.length) return
  const [board] = keyboards.boards.splice(from, 1)
  keyboards.boards.splice(to, 0, board!)
}

const steppers = computed(() => [
  { axis: 'cols' as const, label: '列数', value: props.board.cols, min: LIMITS.minCols, max: LIMITS.maxCols },
  { axis: 'rows' as const, label: '行数', value: props.board.rows, min: LIMITS.minRows, max: LIMITS.maxRows },
])

function step(axis: 'cols' | 'rows', by: number) {
  const cols = axis === 'cols' ? props.board.cols + by : props.board.cols
  const rows = axis === 'rows' ? props.board.rows + by : props.board.rows
  if (!canResize(props.board, cols, rows)) {
    blocked.value = axis
    return
  }
  blocked.value = null
  props.board.cols = cols
  props.board.rows = rows
}

function saveName() {
  props.board.name = name.value.trim().slice(0, LIMITS.name) || '键盘'
}

function close() {
  saveName()
  emit('close')
}

// The sheet closes without `close`, so a new name typed first would be lost.
function duplicate() {
  saveName()
  emit('duplicate')
}
</script>

<template>
  <Sheet title="键盘" @close="close">
    <label class="block py-2">
      <span class="text-[13px] text-muted">名称</span>
      <input
        v-model="name"
        :maxlength="LIMITS.name"
        autocomplete="off"
        class="mt-1 h-11 w-full rounded-xl border border-line bg-surface-2 px-3 text-[15px] outline-none focus:border-accent"
        @keydown.enter="close"
      />
    </label>

    <div v-for="s in steppers" :key="s.axis" class="flex items-center justify-between py-3">
      <span class="text-[15px]">{{ s.label }}</span>
      <div class="flex items-center gap-3">
        <button
          type="button"
          class="grid size-9 place-items-center rounded-full bg-surface-3 disabled:opacity-40"
          :disabled="s.value <= s.min"
          :aria-label="`减少${s.label.toLowerCase()}`"
          @click="step(s.axis, -1)"
        >
          <Minus :size="16" />
        </button>
        <span class="w-5 text-center text-[17px] font-semibold tabular-nums">{{ s.value }}</span>
        <button
          type="button"
          class="grid size-9 place-items-center rounded-full bg-surface-3 disabled:opacity-40"
          :disabled="s.value >= s.max"
          :aria-label="`增加${s.label.toLowerCase()}`"
          @click="step(s.axis, 1)"
        >
          <Plus :size="16" />
        </button>
      </div>
    </div>
    <p v-if="blocked" class="pb-2 text-[13px] text-bad">
      请先移动或删除最后一{{ blocked === 'cols' ? '列' : '行' }}的按钮。
    </p>

    <Toggle v-model="board.trackpad" label="触控板" hint="在按键旁显示触控板，方便在按住按键时移动指针。" />

    <div v-if="keyboards.boards.length > 1" class="flex gap-2 py-3">
      <button type="button" class="flex h-11 flex-1 items-center justify-center gap-2 rounded-xl bg-surface-2 text-[14px] disabled:opacity-40" :disabled="index <= 0" @click="move(-1)">
        <ArrowLeft :size="16" /> 左移
      </button>
      <button type="button" class="flex h-11 flex-1 items-center justify-center gap-2 rounded-xl bg-surface-2 text-[14px] disabled:opacity-40" :disabled="index < 0 || index >= keyboards.boards.length - 1" @click="move(1)">
        右移 <ArrowRight :size="16" />
      </button>
    </div>

    <div class="flex gap-2 py-3">
      <button
        type="button"
        class="flex h-11 flex-1 items-center justify-center gap-2 rounded-xl bg-surface-2 text-[14px] disabled:opacity-40"
        :disabled="keyboards.boards.length >= LIMITS.boards"
        @click="duplicate"
      >
        <Copy :size="16" /> 复制
      </button>
      <button
        v-if="keyboards.boards.length > 1"
        type="button"
        class="flex h-11 flex-1 items-center justify-center gap-2 rounded-xl text-[14px] font-medium"
        :class="confirming ? 'bg-bad text-white' : 'bg-surface-2 text-bad'"
        @click="confirming ? emit('remove') : (confirming = true)"
      >
        <Trash2 :size="16" />
        {{ confirming ? '再次点按以删除' : '删除' }}
      </button>
    </div>

    <button type="button" class="mt-2 h-12 w-full rounded-2xl bg-accent text-[16px] font-semibold text-accent-text" @click="close">完成</button>
  </Sheet>
</template>
