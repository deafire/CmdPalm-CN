<script setup lang="ts">
import { Minus, Plus, Trash2 } from '@lucide/vue'
import { computed, ref } from 'vue'
import { MEDIA } from '@/lib/actions'
import { labels } from '@/lib/connection'
import { actionLabel, fits, LIMITS, type CustomAction, type CustomKey, type CustomKeyboard } from '@/lib/customKeyboards'
import { Key, MOD_ORDER, RIGHT_MODS } from '@/lib/keys'
import type { MediaKey, MouseButton } from '@/lib/protocol'
import { symbol } from '@/lib/symbols'
import Segmented from './Segmented.vue'
import Sheet from './Sheet.vue'
import ShortcutField from './ShortcutField.vue'

const props = defineProps<{ board: CustomKeyboard; keyDef: CustomKey; isNew: boolean }>()
const emit = defineEmits<{ save: [key: CustomKey]; remove: []; close: [] }>()

const draft = ref<CustomKey>(JSON.parse(JSON.stringify(props.keyDef)) as CustomKey)

type Kind = CustomAction['kind']
const kind = computed<Kind>({
  get: () => draft.value.action.kind,
  set: (value) => {
    if (value === draft.value.action.kind) return
    draft.value.action =
      value === 'key'
        ? { kind: 'key', code: Key.Space, mods: 0 }
        : value === 'mod'
          ? { kind: 'mod', mod: MOD_ORDER[2]!.mod }
          : value === 'media'
            ? { kind: 'media', key: 'playPause' }
            : { kind: 'mouse', button: 'left' }
  },
})

const shortcut = computed({
  get: () => (draft.value.action.kind === 'key' ? { code: draft.value.action.code, mods: draft.value.action.mods } : { code: Key.Space, mods: 0 }),
  set: (value: { code: number; mods: number }) => {
    draft.value.action = { kind: 'key', code: value.code, mods: value.mods }
  },
})

const mediaKeys = Object.keys(MEDIA) as MediaKey[]
const mouseButtons: { value: MouseButton; label: string }[] = [
  { value: 'left', label: '左' },
  { value: 'right', label: '右' },
  { value: 'middle', label: '中' },
]

const room = computed(() => fits(props.board, draft.value, draft.value.id))
const preview = computed(() => draft.value.label?.trim() || actionLabel(draft.value.action, labels.value))

function grow(axis: 'w' | 'h', by: number) {
  const max = axis === 'w' ? props.board.cols - draft.value.x : props.board.rows - draft.value.y
  draft.value[axis] = Math.min(max, Math.max(1, draft.value[axis] + by))
}

function save() {
  if (!room.value) return
  const key = draft.value
  const label = key.label?.trim().slice(0, LIMITS.label)
  if (label) key.label = label
  else delete key.label
  emit('save', key)
}
</script>

<template>
  <Sheet :title="isNew ? '新建按键' : '编辑按键'" full @close="emit('close')">
    <template #actions>
      <button
        type="button"
        class="h-8 rounded-full bg-accent px-4 text-[14px] font-semibold text-accent-text disabled:opacity-40"
        :disabled="!room"
        @click="save"
      >
        {{ isNew ? '添加' : '保存' }}
      </button>
    </template>

    <div class="flex items-center gap-4 pb-4">
      <div class="grid size-20 shrink-0 place-items-center rounded-2xl border border-line bg-key px-1 text-center text-[17px] leading-tight break-all">
        {{ preview }}
      </div>
      <label class="min-w-0 flex-1">
        <span class="text-[13px] text-muted">标签（可选）</span>
        <input
          v-model="draft.label"
          :maxlength="LIMITS.label"
          autocomplete="off"
          :placeholder="actionLabel(draft.action, labels)"
          class="mt-1 h-11 w-full rounded-xl border border-line bg-surface-2 px-3 text-[15px] outline-none focus:border-accent"
        />
      </label>
    </div>

    <section class="border-t border-line py-4">
      <h3 class="mb-1 text-[13px] font-medium tracking-wide text-muted uppercase">发送</h3>
      <Segmented
        v-model="kind"
        :options="[
          { value: 'key', label: '按键' },
          { value: 'mod', label: '修饰键' },
          { value: 'media', label: '媒体' },
          { value: 'mouse', label: '鼠标' },
        ]"
      />
      <div class="mt-2">
        <template v-if="draft.action.kind === 'key'">
          <ShortcutField v-model="shortcut" />
          <p class="mt-2 text-[13px] text-faint">按住时持续按下。开启上方的修饰键可发送组合键。</p>
        </template>

        <template v-else-if="draft.action.kind === 'mod'">
          <div class="grid grid-cols-5 gap-1.5">
            <button
              v-for="m in [...MOD_ORDER, ...RIGHT_MODS]"
              :key="m.mod"
              type="button"
              class="flex h-12 flex-col items-center justify-center rounded-xl text-[18px] leading-none transition-colors"
              :class="draft.action.mod === m.mod ? 'bg-accent text-accent-text' : 'bg-surface-3 text-muted'"
              :aria-label="m.name"
              @click="draft.action = { kind: 'mod', mod: m.mod }"
            >
              {{ m.symbol }}
              <span v-if="RIGHT_MODS.includes(m)" class="mt-0.5 text-[10px]">右</span>
            </button>
          </div>
          <p class="mt-2 text-[13px] text-faint">
            按住时在 Mac 上按下，因此可与此键盘上的其他按键组合。底行使用右侧的按键，某些应用对它们的处理不同，例如将右侧 ⌘ 设置为 hyper 键。
          </p>
        </template>

        <div v-else-if="draft.action.kind === 'media'" class="grid grid-cols-2 gap-1.5">
          <button
            v-for="media in mediaKeys"
            :key="media"
            type="button"
            class="flex h-11 items-center gap-2 rounded-xl px-3 text-left text-[14px] transition-colors"
            :class="draft.action.key === media ? 'bg-accent-soft text-accent' : 'bg-surface-2 text-text'"
            @click="draft.action = { kind: 'media', key: media }"
          >
            <component :is="symbol(MEDIA[media].symbol)" :size="16" class="shrink-0" />
            <span class="truncate">{{ MEDIA[media].label }}</span>
          </button>
        </div>

        <template v-else>
          <Segmented
            :model-value="draft.action.button"
            :options="mouseButtons"
            @update:model-value="(button: MouseButton) => (draft.action = { kind: 'mouse', button })"
          />
          <p class="text-[13px] text-faint">按住按键时鼠标按键保持按下，因此可在触控板上拖动。</p>
        </template>
      </div>
    </section>

    <section class="border-t border-line py-4">
      <h3 class="mb-2 text-[13px] font-medium tracking-wide text-muted uppercase">大小</h3>
      <div class="grid grid-cols-2 gap-3">
        <div v-for="axis in ['w', 'h'] as const" :key="axis" class="flex items-center justify-between rounded-xl bg-surface-2 px-2 py-1.5">
          <button type="button" class="grid size-9 place-items-center rounded-lg text-muted active:bg-surface-3" :aria-label="`缩小${axis === 'w' ? '宽度' : '高度'}`" @click="grow(axis, -1)">
            <Minus :size="17" />
          </button>
          <span class="text-[14px] tabular-nums">{{ axis === 'w' ? '宽度' : '高度' }} {{ draft[axis] }}</span>
          <button type="button" class="grid size-9 place-items-center rounded-lg text-muted active:bg-surface-3" :aria-label="`放大${axis === 'w' ? '宽度' : '高度'}`" @click="grow(axis, 1)">
            <Plus :size="17" />
          </button>
        </div>
      </div>
      <p v-if="!room" class="mt-2 text-[13px] text-bad">有其他按键挡住了。请缩小此按键，或先移动其他按键。</p>
      <p v-else class="mt-2 text-[13px] text-faint">编辑时可在键盘上拖动按键以移动位置。</p>
    </section>

    <section v-if="!isNew" class="border-t border-line pt-4">
      <button type="button" class="flex h-11 w-full items-center justify-center gap-2 rounded-xl bg-surface-2 text-[14px] text-bad" @click="emit('remove')">
        <Trash2 :size="16" /> 删除按键
      </button>
    </section>
  </Sheet>
</template>
