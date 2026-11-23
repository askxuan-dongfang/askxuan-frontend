<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { CatalogKind, CatalogTranslation, CatalogTranslationApi } from '../catalog-translations'

const props = defineProps<{
  api: CatalogTranslationApi
  kind: CatalogKind
  recordId: string | number
  link?: boolean
}>()

const statusLabels = {
  missing: '待生成', queued: '排队中', translating: '生成中',
  review: '待审核', published: '已发布', failed: '生成失败'
} satisfies Record<CatalogTranslation['status'], string>
const fieldLabels: Record<string, string> = {
  title: '名称', description: '介绍', rules: '活动规则', prizeName: '奖品名称', specialties: '专长', address: '地址'
}
const subtitleLabels: Partial<Record<CatalogKind, string>> = {
  'points-product': '分类', 'diy-material': '规格', master: '职位', belief: '摘要'
}
const pendingLabels = { read: '正在读取', queue: '正在提交翻译任务', draft: '正在保存英文草稿', publish: '正在发布英文' }
const failureLabels = {
  read: '英文状态读取失败，请重试。',
  queue: '英文任务提交失败，请重试。',
  draft: '英文草稿保存失败，已保留输入。',
  publish: '英文发布失败，已保留输入。'
}
type Action = keyof typeof pendingLabels

const open = ref(false)
const translation = ref<CatalogTranslation>()
const draft = ref<Record<string, string>>({})
const pending = ref<Action>()
const error = ref('')
const stale = ref(false)

const status = computed(() => translation.value?.status)
const source = computed(() => Object.entries(translation.value?.source || {}))
const active = computed(() => status.value === 'queued' || status.value === 'translating')
const changed = computed(() => source.value.some(([key]) => (draft.value[key] || '').trim() !== (translation.value?.fields[key] || '').trim()))
const hasText = computed(() => source.value.some(([key]) => draft.value[key]?.trim()))
const complete = computed(() => source.value.length > 0 && source.value.every(([key]) => draft.value[key]?.trim()))
const canEdit = computed(() => !!translation.value?.revision && !active.value && !stale.value)
const buttonLabel = computed(() => props.kind === 'reward-campaign' ? '管理活动英文' : props.kind === 'reward-prize' ? '管理奖品英文' : '管理英文')

function label(key: string) {
  if (key === 'subtitle') return subtitleLabels[props.kind] || '摘要'
  if (key === 'title' && props.kind === 'reward-campaign') return '活动标题'
  return fieldLabels[key] || '内容'
}

async function run(action: Action) {
  if (pending.value) return
  pending.value = action
  error.value = ''
  const { api, kind, recordId } = props
  try {
    if (action === 'read') {
      translation.value = await api.read(kind, recordId)
    } else if (action === 'queue') {
      translation.value = await api.queue(kind, recordId)
    } else if (translation.value) {
      const fields = Object.fromEntries(source.value.flatMap(([key]) => {
        const text = draft.value[key]?.trim()
        return text ? [[key, text]] : []
      }))
      translation.value = await api.save(kind, recordId, translation.value.revision, fields, action === 'publish')
    }
    draft.value = { ...translation.value?.fields }
    stale.value = false
  } catch (cause) {
    const apiCode = (cause as { apiCode?: number } | null)?.apiCode
    if (apiCode === 40932 && (action === 'draft' || action === 'publish')) {
      stale.value = true
      error.value = '中文内容或英文稿已更新。请重新读取并核对。'
    } else if (apiCode === 40417) {
      error.value = '找不到可翻译的中文内容。请核对记录及公开状态。'
    } else if (apiCode === 40016) {
      error.value = '请检查英文栏位。发布前需要填齐所有栏位。'
    } else {
      error.value = failureLabels[action]
    }
  } finally {
    pending.value = undefined
  }
}

watch(open, shown => {
  if (!shown) return
  translation.value = undefined
  draft.value = {}
  stale.value = false
  void run('read')
})

watch([open, active, pending, error], ([shown, inProgress, request, failed], _, onCleanup) => {
  if (!shown || !inProgress || request || failed) return
  const timer = window.setTimeout(() => void run('read'), 3000)
  onCleanup(() => window.clearTimeout(timer))
})
</script>

<template>
  <el-button :link="link" :type="link ? 'primary' : undefined" @click="open = true">{{ $t(buttonLabel) }}</el-button>
  <el-dialog
    v-model="open"
    :title="$t('信众端英文')"
    width="min(760px, 94vw)"
    append-to-body
    destroy-on-close
    :close-on-click-modal="false"
    :close-on-press-escape="!pending"
    :show-close="!pending"
  >
    <div class="catalog-translation-status" role="status">
      <el-tag v-if="status" :type="status === 'published' ? 'success' : status === 'failed' ? 'danger' : status === 'review' ? 'warning' : 'info'">
        {{ $t(status === 'review' && !translation?.reviewRequired ? '待发布' : statusLabels[status]) }}
      </el-tag>
      <span v-if="pending">{{ $t(pendingLabels[pending]) }}…</span>
    </div>
    <p v-if="error" class="catalog-translation-error" role="alert">{{ $t(error) }}</p>
    <p v-if="translation?.publicEligible === false" class="catalog-translation-note">{{ $t('中文内容尚未公开。审核后的英文会在中文公开时显示。') }}</p>
    <p v-if="status === 'failed'" class="catalog-translation-note">{{ $t('可以重试翻译，也可以直接填写英文。') }}</p>

    <div v-for="[key, text] in source" :key="key" class="catalog-translation-field">
      <h3>{{ $t(label(key)) }}</h3>
      <div class="catalog-translation-columns">
        <div>
          <span>{{ $t('已保存的中文') }}</span>
          <p lang="zh-Hans">{{ text }}</p>
        </div>
        <el-input v-model="draft[key]" type="textarea" :autosize="{ minRows: 2, maxRows: 8 }" :aria-label="'英文' + $t(label(key))" :readonly="stale" :disabled="active || !!pending" :placeholder="$t(key === 'specialties' ? '用英文逗号分隔各项专长' : '填写英文')" lang="en" />
      </div>
    </div>

    <template #footer>
      <div class="catalog-translation-actions">
        <el-button :disabled="!!pending" @click="open = false">{{ $t('关闭') }}</el-button>
        <el-button v-if="!translation || active || stale" :loading="pending === 'read'" :disabled="!!pending" @click="run('read')">{{ $t('重新读取') }}</el-button>
        <el-button v-if="status === 'missing' || status === 'failed'" :loading="pending === 'queue'" :disabled="!!pending || changed || stale" @click="run('queue')">
          {{ $t(status === 'failed' ? '重新生成英文' : '生成英文') }}
        </el-button>
        <el-button v-if="canEdit" :loading="pending === 'draft'" :disabled="!!pending || !changed || !hasText" @click="run('draft')">{{ $t('保存英文草稿') }}</el-button>
        <el-button v-if="canEdit" type="primary" :loading="pending === 'publish'" :disabled="!!pending || !complete || status === 'published' && !changed" @click="run('publish')">{{ $t('审核并发布') }}</el-button>
      </div>
    </template>
  </el-dialog>
</template>

<style scoped>
.catalog-translation-status, .catalog-translation-actions { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.catalog-translation-actions { justify-content: flex-end; }
.catalog-translation-actions .el-button { margin: 0; }
.catalog-translation-note { color: var(--el-text-color-secondary); margin: 12px 0; }
.catalog-translation-error { color: var(--el-color-danger); margin: 12px 0; }
.catalog-translation-field { border-top: 1px solid var(--el-border-color-lighter); margin-top: 16px; padding-top: 12px; }
.catalog-translation-field h3 { font-size: var(--type-size-body); margin: 0 0 8px; }
.catalog-translation-columns { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; align-items: start; }
.catalog-translation-columns span { color: var(--el-text-color-secondary); font-size: var(--type-size-caption); }
.catalog-translation-columns p { margin: 4px 0 0; white-space: pre-wrap; overflow-wrap: anywhere; }
@media (max-width: 580px) { .catalog-translation-columns { grid-template-columns: 1fr; gap: 8px; } }
</style>
