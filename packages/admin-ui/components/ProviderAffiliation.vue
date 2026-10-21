<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { affiliationProblem, beliefLabel, beliefOptions, normalizeBelief, type AffiliationTag } from '../affiliation'

const props = withDefaults(defineProps<{ belief: string; codes?: string[]; disabled?: boolean; readonly?: boolean; catalogUrl?: string; catalogToken?: string }>(), { codes: () => [], disabled: false, readonly: false, catalogUrl: '/api/v1/beliefs/directory-tags' })
const emit = defineEmits<{ 'update:belief': [value: string]; 'update:codes': [value: string[]] }>()
const loading = ref(false), error = ref(''), tags = ref<AffiliationTag[]>([])
const parent = computed(() => normalizeBelief(props.belief))
const selected = computed(() => props.codes || [])
const options = computed(() => {
  const catalog = tags.value.filter(tag => tag.group === 'tradition' && (normalizeBelief(tag.beliefCode || '') === parent.value || selected.value.includes(tag.code)))
  for (const code of selected.value) if (!catalog.some(tag => tag.code === code)) catalog.push({ code, name: code, group: 'tradition', status: 'unknown', beliefCode: '' })
  return props.readonly ? catalog.filter(tag => selected.value.includes(tag.code)) : catalog
})
const conflict = computed(() => selected.value.some(code => {
  const tag = tags.value.find(item => item.code === code)
  return !tag || tag.status !== 'enabled' || normalizeBelief(tag.beliefCode || '') !== parent.value
}))
async function load() {
  loading.value = true; error.value = ''
  try {
    const response = await fetch(props.catalogUrl, { cache: 'no-store', ...(props.catalogToken ? { headers: { Authorization: `Bearer ${props.catalogToken}` } } : {}) })
    const result = await response.json()
    if (!response.ok || result.code !== 0 || !Array.isArray(result.data?.list)) throw new Error(result.message || '标准宗派目录加载失败，请重试')
    tags.value = result.data.list.filter((tag: AffiliationTag) => tag.group === 'tradition')
  } catch (cause) { error.value = cause instanceof Error ? cause.message : '标准宗派目录加载失败，请重试' }
  finally { loading.value = false }
}
function toggle(code: string, checked: boolean) {
  emit('update:codes', checked ? [...new Set([...selected.value, code])] : selected.value.filter(value => value !== code))
}
function validate(required = true) {
  if (loading.value || error.value) return '标准宗派目录尚未就绪，请加载后再提交'
  return affiliationProblem(parent.value, selected.value, tags.value, required)
}
defineExpose({ validate, reload: load })
onMounted(load)
</script>

<template>
  <div class="provider-affiliation">
    <label class="affiliation-belief"><span>{{ $t('主信仰') }}</span>
      <select :value="parent" :disabled="disabled || readonly" :required="!readonly" @change="emit('update:belief', ($event.target as HTMLSelectElement).value)">
        <option v-if="parent && !beliefOptions.some(item=>item.code===parent)" :value="parent">{{ $t(beliefLabel(parent)) }}{{ $t('（历史关联，需核对）') }}</option>
        <option value="" disabled>{{ $t('请选择主信仰') }}</option>
        <option v-for="item in beliefOptions" :key="item.code" :value="item.code">{{ $t(item.name) }}</option>
      </select>
    </label>
    <fieldset :disabled="disabled || readonly || loading" class="affiliation-choices">
      <legend>{{ $t('标准宗派 / 信俗') }}</legend>
      <p class="affiliation-hint">{{ $t('来自统一标准目录，可多选；修改主信仰不会自动删除已有选择。') }}</p>
      <p v-if="loading" role="status">{{ $t('正在加载标准宗派目录…') }}</p>
      <div v-else class="affiliation-tags">
        <label v-for="tag in options" :key="tag.code" :class="{ 'is-history': tag.status !== 'enabled' || normalizeBelief(tag.beliefCode || '') !== parent }">
          <input type="checkbox" :value="tag.code" :checked="selected.includes(tag.code)" :disabled="(!selected.includes(tag.code) && selected.length >= 12) || (tag.status !== 'enabled' && !selected.includes(tag.code))" @change="toggle(tag.code, ($event.target as HTMLInputElement).checked)">
          <span>{{ $t(tag.name) }}<small v-if="tag.status !== 'enabled'">{{ $t('（历史关联，需核对）') }}</small><small v-else-if="normalizeBelief(tag.beliefCode || '') !== parent">{{ $t(beliefLabel(tag.beliefCode || '')) }}</small></span>
        </label>
      </div>
      <p v-if="!loading && !options.length" class="affiliation-hint">{{ $t(readonly ? '尚未选择标准宗派或信俗' : '请先选择主信仰，再选择对应宗派或信俗') }}</p>
    </fieldset>
    <p v-if="conflict" class="affiliation-warning" role="status">{{ $t(readonly ? '已有历史关联原样保留，不因资料编辑自动更改。' : '已有选择与当前主信仰或有效目录不一致。请明确核对后调整，不会自动清空。') }}</p>
    <div v-if="error" role="alert" class="affiliation-warning">{{ $t(error) }} <button type="button" :disabled="loading" @click="load">{{ $t('重新加载') }}</button></div>
  </div>
</template>

<style scoped>
.provider-affiliation{width:100%;min-width:0;display:grid;gap:16px;color:var(--admin-text,var(--color-text-primary,#24443d))}.affiliation-belief{display:grid;gap:8px;font-size:14px}.affiliation-belief select{width:100%;min-width:0;min-height:44px;padding:10px 12px;border:0;border-bottom:1px solid var(--admin-border,#d7dcd5);border-radius:6px;font:inherit;color:inherit;background:var(--admin-bg,var(--color-bg-secondary,#f6f5ee))}.affiliation-choices{min-width:0;border:0;padding:0;margin:0}.affiliation-choices legend{font-size:14px;font-weight:500;margin-bottom:5px}.affiliation-hint{font-size:12px;line-height:1.7;color:var(--admin-text-secondary,var(--color-text-tertiary,#66736d));margin:0 0 12px}.affiliation-tags{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.affiliation-tags label{display:flex;align-items:center;gap:9px;min-height:42px;padding:9px 10px;border-radius:6px;background:var(--admin-bg,var(--color-bg-secondary,#f6f5ee));font-size:13px;line-height:1.5}.affiliation-tags input{width:17px;height:17px;min-height:17px;accent-color:var(--admin-primary,var(--color-primary,#28574c));flex-shrink:0}.affiliation-tags small{display:block;color:var(--admin-text-secondary,#66736d);font-size:11px}.affiliation-tags .is-history{background:color-mix(in srgb,var(--admin-warning,#a87a3b) 10%,transparent)}.affiliation-warning{font-size:12px;line-height:1.7;color:var(--admin-warning,#a87a3b);margin:0}.affiliation-warning button{border:0;background:transparent;font:inherit;color:inherit;text-decoration:underline;cursor:pointer}:focus-visible{outline:2px solid var(--admin-primary,#28574c);outline-offset:3px}.provider-affiliation :disabled{cursor:default}@media(max-width:360px){.affiliation-tags{grid-template-columns:1fr}}
</style>
