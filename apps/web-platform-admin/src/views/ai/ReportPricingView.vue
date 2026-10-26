<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'
import { isAdminSessionExpired } from '../../../../../packages/admin-ui/session-expiry'
import PageHeader from '@/components/PageHeader.vue'
import { aiProductsApi, type AiReportProduct } from '@/api/aiProducts'

const products = ref<AiReportProduct[]>([]), loading = ref(false), loadError = ref('')
const selected = ref<AiReportProduct>(), priceYuan = ref<number | undefined>(), editing = ref(false), saving = ref(false), saveError = ref('')
const money = (cents: number) => (cents / 100).toFixed(2)
async function load() {
  loading.value = true; loadError.value = ''
  try { products.value = await aiProductsApi.list() }
  catch (error) { if (!isAdminSessionExpired(error)) loadError.value = '报告价格暂未加载，请重试' }
  finally { loading.value = false }
}
function edit(row: AiReportProduct) {
  selected.value = { ...row }; priceYuan.value = row.priceCents / 100; saveError.value = ''; editing.value = true
}
async function refreshPrice() {
  if (!selected.value || saving.value) return
  saving.value = true
  try {
    const rows = await aiProductsApi.list(), row = rows.find(item => item.code === selected.value?.code)
    if (!row) throw new Error('该专题已不可用，请关闭后刷新列表')
    products.value = rows; selected.value = { ...row }; priceYuan.value = row.priceCents / 100; saveError.value = ''
    ElMessage.info(uiText('已重新读取当前价格，请核对后保存'))
  } catch (error) { if (!isAdminSessionExpired(error)) saveError.value = error instanceof Error ? error.message : '读取失败，请重试' }
  finally { saving.value = false }
}
async function save() {
  if (!selected.value || saving.value) return
  const priceCents = Math.round(Number(priceYuan.value) * 100)
  if (priceYuan.value == null || !Number.isSafeInteger(priceCents) || priceCents < 1 || priceCents > 100000000) {
    saveError.value = '请输入 0.01–1,000,000.00 元之间的价格'; return
  }
  saving.value = true; saveError.value = ''
  try {
    const updated = await aiProductsApi.updatePrice(selected.value.code, priceCents, selected.value.revision)
    products.value = products.value.map(row => row.code === updated.code ? updated : row)
    editing.value = false; ElMessage.success(uiText('报告价格已保存，新生成报告采用此价格'))
  } catch (error) { if (!isAdminSessionExpired(error)) saveError.value = error instanceof Error ? error.message : '保存失败，请重试' }
  finally { saving.value = false }
}
onMounted(load)
</script>

<template>
  <div class="page-wrap report-pricing">
    <PageHeader :title="$t('报告定价')" :subtitle="$t('完整报告使用钱包余额支付，可按专题调整每份价格')" />
    <p class="pricing-note">{{ $t('默认 ¥9.90 / 份。修改仅对新生成的报告生效，已生成报告保持原价。') }}</p>
    <div v-if="loadError" class="pricing-error" role="alert">{{ $t(loadError) }}<el-button @click="load">{{ $t('重新加载') }}</el-button></div>
    <el-table v-else :data="products" v-loading="loading" :empty-text="$t('暂无可配置的报告专题')">
      <el-table-column :label="$t('报告专题')" min-width="220"><template #default="{ row }"><strong>{{ $t(row.title) }}</strong><p class="topic-description">{{ $t(row.subtitle) }}</p></template></el-table-column>
      <el-table-column :label="$t('每份价格')" min-width="120"><template #default="{ row }">¥{{ money(row.priceCents) }}</template></el-table-column>
      <el-table-column :label="$t('状态')" min-width="90"><template #default="{ row }">{{ $t(row.enabled ? '已开放' : '未开放') }}</template></el-table-column>
      <el-table-column :label="$t('操作')" width="115"><template #default="{ row }"><el-button link type="primary" @click="edit(row)">{{ $t('调整价格') }}</el-button></template></el-table-column>
    </el-table>
    <el-dialog v-model="editing" :title="$t('调整报告价格')" width="min(480px, 94vw)" :close-on-click-modal="!saving" :close-on-press-escape="!saving" :show-close="!saving" append-to-body>
      <p class="selected-topic">{{ $t(selected?.title) }}</p>
      <el-form label-position="top" @submit.prevent="save"><el-form-item :label="$t('每份价格（元）')" required><el-input-number v-model="priceYuan" :min=".01" :max="1000000" :precision="2" :step=".1" :disabled="saving" /></el-form-item></el-form>
      <p class="pricing-note">{{ $t('新报告采用保存后的价格，已生成报告保持原价。') }}</p>
      <div v-if="saveError" class="pricing-error" role="alert">{{ $t(saveError) }}<el-button :disabled="saving" @click="refreshPrice">{{ $t('重新读取当前价格') }}</el-button></div>
      <template #footer><el-button :disabled="saving" @click="editing = false">{{ $t('取消') }}</el-button><el-button type="primary" :loading="saving" @click="save">{{ $t('保存价格') }}</el-button></template>
    </el-dialog>
  </div>
</template>

<style scoped>
.report-pricing { max-width: 1200px; margin-inline: auto; }
.pricing-note,.topic-description { color: var(--dfx-text-secondary); font-size: var(--type-size-caption); line-height: 1.7; }
.pricing-note { margin: 0 0 24px; }
.topic-description { margin: 5px 0; }
.selected-topic { font-size: var(--type-size-nav); margin: 0 0 20px; }
.pricing-error { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; color: var(--el-color-danger); line-height: 1.7; margin-block: 16px; }
</style>
