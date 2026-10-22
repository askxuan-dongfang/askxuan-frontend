<template>
  <div class="dfx-page payout-sandbox">
    <PageHeader :title="$t('模拟打款测试')" :subtitle="$t('独立模拟流程 · 无真实资金')"><template #actions><el-button type="primary" @click="createVisible = true">{{ $t('新建模拟测试') }}</el-button></template></PageHeader>
    <el-alert :title="$t('模拟环境：所有金额、打款结果和收款对象均为模拟，不产生真实资金交易。')" type="warning" :closable="false" show-icon />
    <p class="sandbox-help">{{ $t('仅使用固定虚拟收款对象；不支持输入真实账号、银行卡或收款人。与真实提现、结算和账本独立。') }}</p>
    <div class="dfx-card sandbox-card">
      <form class="sandbox-filters" @submit.prevent="search">
        <el-select v-model="formStatus" :aria-label="$t('模拟状态')" :placeholder="$t('全部模拟状态')" clearable><el-option v-for="state in states" :key="state.value" :value="state.value" :label="$t(state.label)" /></el-select>
        <el-button native-type="submit" type="primary" :loading="loading">{{ $t('查询模拟记录') }}</el-button><el-button :loading="loading" @click="load">{{ $t('刷新') }}</el-button>
      </form>
      <div v-if="error" class="ax-page-feedback is-error" role="alert"><p>{{ $t('模拟列表读取失败，请重试。') }}</p><el-button @click="load">{{ $t('重新加载') }}</el-button></div>
      <DataTable v-else v-model:page="page" v-model:size="size" :data="rows" :total="total" :loading="loading" @change="load">
        <el-table-column :label="$t('模拟实例')" min-width="310"><template #default="{ row }"><el-tag type="warning" size="small">{{ $t('模拟') }}</el-tag> <button class="sandbox-link" @click="openDetail(row.id)">{{ row.id }}</button></template></el-table-column>
        <el-table-column :label="$t('模拟金额')" min-width="145"><template #default="{ row }">{{ formatMoney(row.amountCents / 100) }} <small>{{ $t('模拟') }}</small></template></el-table-column>
        <el-table-column :label="$t('虚拟收款对象')" min-width="215"><template #default="{ row }">{{ row.recipient }}</template></el-table-column>
        <el-table-column :label="$t('模拟结果')" min-width="145"><template #default="{ row }"><el-tag :type="tone(row.status)">{{ $t(label(row.status)) }}</el-tag></template></el-table-column>
        <el-table-column :label="$t('模拟次数 / 版本')" min-width="130"><template #default="{ row }">{{ row.attempt }} / {{ row.version }}</template></el-table-column>
        <el-table-column :label="$t('模拟创建时间')" min-width="165"><template #default="{ row }">{{ formatDate(row.createdAt) }}</template></el-table-column>
        <el-table-column :label="$t('模拟操作')" width="125" fixed="right"><template #default="{ row }"><el-button link type="primary" @click="openDetail(row.id)">{{ $t('查看模拟流程') }}</el-button></template></el-table-column>
      </DataTable>
    </div>

    <el-dialog v-model="createVisible" :title="$t('新建模拟打款测试')" width="min(480px, calc(100vw - 32px))" :close-on-click-modal="false">
      <el-alert :title="$t('仅创建独立模拟记录，无真实资金')" type="warning" :closable="false" />
      <p>{{ $t('收款对象') }}：{{ $t('虚拟收款对象（无真实账户）') }}</p>
      <label class="sandbox-amount-label" for="sandbox-amount">{{ $t('模拟金额（元）') }}</label>
      <el-input-number id="sandbox-amount" v-model="amountYuan" :min="0.01" :max="10000" :precision="2" :step="1" controls-position="right" />
      <p class="sandbox-help">{{ $t('最高 10000 元，仅用于模拟，无真实资金。') }}</p>
      <template #footer><el-button :disabled="creating" @click="createVisible = false">{{ $t('取消') }}</el-button><el-button type="primary" :loading="creating" @click="create">{{ $t('创建模拟记录') }}</el-button></template>
    </el-dialog>

    <el-drawer v-model="detailVisible" :title="$t('模拟打款流程详情')" size="min(760px, 100vw)">
      <div v-loading="detailLoading" class="sandbox-detail">
        <div v-if="detailError" class="ax-page-feedback is-error" role="alert"><p>{{ $t('模拟详情读取失败，请重试。') }}</p><el-button @click="openDetail(detailId)">{{ $t('重新加载') }}</el-button></div>
        <template v-if="detail">
          <el-alert :title="$t('模拟实例 · 无真实资金')" type="warning" :closable="false" />
          <h3 class="sandbox-id">{{ detail.record.id }}</h3>
          <dl class="sandbox-facts"><dt>{{ $t('模拟金额') }}</dt><dd>{{ formatMoney(detail.record.amountCents / 100) }} {{ $t('（模拟）') }}</dd><dt>{{ $t('虚拟收款对象') }}</dt><dd>{{ detail.record.recipient }}</dd><dt>{{ $t('模拟状态') }}</dt><dd><el-tag :type="tone(detail.record.status)">{{ $t(label(detail.record.status)) }}</el-tag></dd><dt>{{ $t('模拟尝试次数') }}</dt><dd>{{ detail.record.attempt }}</dd><dt>{{ $t('模拟记录版本') }}</dt><dd>{{ detail.record.version }}</dd></dl>
          <section class="sandbox-controls">
            <h3>{{ $t('模拟操作') }}</h3>
            <template v-if="detail.record.status === 'pending_review'"><p>{{ $t('此步骤仅审核当前模拟记录。') }}</p><el-button :loading="acting" type="primary" @click="act('approve')">{{ $t('模拟审核通过') }}</el-button><el-button :disabled="acting" @click="act('reject')">{{ $t('模拟驳回') }}</el-button></template>
            <template v-else-if="['approved', 'failed'].includes(detail.record.status)">
              <label>{{ $t('本次模拟结果') }}</label>
              <el-select v-model="outcome" :aria-label="$t('本次模拟结果')"><el-option :label="$t('模拟成功')" value="success" /><el-option :label="$t('模拟失败')" value="failed" /><el-option :label="$t('模拟超时，结果未知')" value="unknown" /></el-select>
              <el-button :loading="acting" type="primary" @click="act(detail.record.status === 'failed' ? 'retry' : 'submit')">{{ $t(detail.record.status === 'failed' ? '重试模拟打款' : '提交模拟打款') }}</el-button>
            </template>
            <template v-else-if="detail.record.status === 'unknown'">
              <el-alert :title="$t('模拟结果未确认，禁止重新提交或重试。请先模拟查单确认。')" type="error" :closable="false" />
              <label>{{ $t('模拟查单结果') }}</label><el-select v-model="resolvedOutcome" :aria-label="$t('模拟查单结果')"><el-option :label="$t('模拟查单确认成功')" value="success" /><el-option :label="$t('模拟查单确认失败')" value="failed" /></el-select><el-button type="primary" :loading="acting" @click="act('resolve')">{{ $t('模拟查单确认') }}</el-button>
            </template>
            <p v-else class="sandbox-help">{{ $t(detail.record.status === 'success' ? '模拟流程已成功结束，没有真实资金转出。' : '模拟记录已驳回，流程结束。') }}</p>
          </section>
          <section class="sandbox-events"><h3>{{ $t('模拟事件记录') }}</h3><p class="sandbox-help">{{ $t('每一步模拟操作都会保留记录，可在这里核对处理过程和结果。') }}</p>
            <ol><li v-for="event in detail.events" :key="event.id"><strong>{{ $t(eventLabel(event)) }}</strong><div>{{ $t(label(event.fromStatus)) }} → {{ $t(label(event.toStatus)) }}</div><small>{{ formatDate(event.createdAt) }} · {{ $t('模拟次数') }} {{ event.attempt }} · {{ $t('版本') }} {{ event.version }} · {{ $t('操作人') }} {{ event.actorId }}</small></li></ol>
          </section>
        </template>
      </div>
    </el-drawer>
  </div>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import { ElMessage } from '@/i18n'
import { isAdminSessionExpired } from '@/api/client'
import { actSandboxPayout, createSandboxPayout, getSandboxPayout, getSandboxPayouts, type SandboxAction, type SandboxCommand, type SandboxDetail, type SandboxEvent, type SandboxOutcome, type SandboxPayout, type SandboxState } from '@/api/payoutSandbox'
import { formatDate, formatMoney } from '@/utils/format'

const states: Array<{ value: SandboxState; label: string }> = [{ value: 'pending_review', label: '模拟待审核' }, { value: 'approved', label: '模拟审核通过' }, { value: 'rejected', label: '模拟已驳回' }, { value: 'success', label: '模拟成功' }, { value: 'failed', label: '模拟失败' }, { value: 'unknown', label: '模拟结果未知' }]
const label = (state: string) => state === 'processing' ? '模拟处理中' : states.find(item => item.value === state)?.label || '—'
function tone(state: string): 'warning' | 'success' | 'danger' | 'info' { return state === 'success' ? 'success' : ['failed', 'unknown'].includes(state) ? 'danger' : state === 'pending_review' ? 'warning' : 'info' }
function eventLabel(event: SandboxEvent) { return event.stage === 'processing' ? '模拟处理中' : event.stage === 'result' ? '模拟回执' : event.action === 'resolve' ? '模拟查单确认' : event.action === 'approve' ? '模拟审核通过' : event.action === 'reject' ? '模拟驳回' : '创建模拟记录' }
const formStatus = ref<SandboxState | ''>(''), appliedStatus = ref<SandboxState | ''>('')
const rows = ref<SandboxPayout[]>([]), page = ref(1), size = ref(20), total = ref(0), loading = ref(false), error = ref(false)
const createVisible = ref(false), creating = ref(false), amountYuan = ref(100)
const detailVisible = ref(false), detailId = ref(''), detailLoading = ref(false), detailError = ref(false), detail = ref<SandboxDetail | null>(null), acting = ref(false)
const outcome = ref<SandboxOutcome>('success'), resolvedOutcome = ref<'success' | 'failed'>('success')
let alive = true, listSequence = 0, detailSequence = 0
let createPending: { amount: number; requestId: string } | null = null
let actionPending: { id: string; command: SandboxCommand } | null = null

async function load() {
  const sequence = ++listSequence; loading.value = true; error.value = false
  try { const result = await getSandboxPayouts({ page: page.value, size: size.value, status: appliedStatus.value || undefined }); if (!alive || sequence !== listSequence) return; rows.value = result.list; total.value = result.total; page.value = result.page; size.value = result.size }
  catch (e) { if (alive && sequence === listSequence && !isAdminSessionExpired(e)) { error.value = true; rows.value = []; total.value = 0 } }
  finally { if (alive && sequence === listSequence) loading.value = false }
}
function search() { appliedStatus.value = formStatus.value; page.value = 1; void load() }
async function openDetail(id: string) {
  const sequence = ++detailSequence; detailId.value = id; detailVisible.value = true; detailLoading.value = true; detailError.value = false; detail.value = null; outcome.value = 'success'; resolvedOutcome.value = 'success'
  try { const result = await getSandboxPayout(id); if (alive && sequence === detailSequence) detail.value = result }
  catch (e) { if (alive && sequence === detailSequence && !isAdminSessionExpired(e)) detailError.value = true }
  finally { if (alive && sequence === detailSequence) detailLoading.value = false }
}
async function create() {
  if (creating.value) return
  const amountCents = Math.round(amountYuan.value * 100)
  if (!Number.isFinite(amountYuan.value) || amountYuan.value < 0.01 || amountYuan.value > 10000 || !Number.isSafeInteger(amountCents) || amountCents < 1 || amountCents > 1000000) { ElMessage.error('请输入 0.01 至 10000 元的模拟金额'); return }
  if (!createPending || createPending.amount !== amountCents) createPending = { amount: amountCents, requestId: crypto.randomUUID() }
  creating.value = true
  try { const record = await createSandboxPayout({ amountCents: createPending.amount, requestId: createPending.requestId }); createPending = null; if (!alive) return; createVisible.value = false; ElMessage.success('模拟记录已创建，无真实资金'); void load(); await openDetail(record.id) }
  catch { /* Shared request client reports the failure; the key survives a retry. */ }
  finally { if (alive) creating.value = false }
}
async function act(action: SandboxAction) {
  if (acting.value || !detail.value) return
  const record = detail.value.record
  const result = action === 'resolve' ? resolvedOutcome.value : ['submit', 'retry'].includes(action) ? outcome.value : undefined
  const previous = actionPending
  const command: SandboxCommand = previous && previous.id === record.id && previous.command.version === record.version && previous.command.action === action && previous.command.outcome === result ? previous.command : { requestId: crypto.randomUUID(), version: record.version, action, outcome: result }
  actionPending = { id: record.id, command }; acting.value = true
  try { await actSandboxPayout(record.id, command); actionPending = null; if (!alive) return; ElMessage.success('模拟操作已完成，无真实资金'); void load(); if (detailVisible.value && detailId.value === record.id) await openDetail(record.id) }
  catch { /* Same command key is reused after a network failure, avoiding duplicate attempts. */ }
  finally { if (alive) acting.value = false }
}
onMounted(load)
onBeforeUnmount(() => { alive = false; ++listSequence; ++detailSequence })
</script>

<style scoped>
.sandbox-card{padding:20px}.sandbox-help{font-size:13px;color:var(--admin-text-secondary);line-height:1.7}.sandbox-filters{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:20px}.sandbox-filters .el-select{width:210px}.sandbox-link{font:inherit;color:var(--admin-primary);border:0;background:none;padding:0;cursor:pointer;text-decoration:underline;text-underline-offset:3px;overflow-wrap:anywhere}.sandbox-id{font-size:16px;overflow-wrap:anywhere}.sandbox-amount-label{display:block;margin:20px 0 10px}.sandbox-facts{display:grid;grid-template-columns:125px minmax(0,1fr);gap:14px}.sandbox-facts dt{color:var(--admin-text-secondary)}.sandbox-facts dd{margin:0;overflow-wrap:anywhere}.sandbox-controls{border-top:1px solid var(--admin-border);padding:20px 0;margin-top:24px}.sandbox-controls label{display:block;margin:16px 0 8px}.sandbox-controls .el-select{max-width:260px;margin:0 12px 12px 0}.sandbox-events{border-top:1px solid var(--admin-border);padding-top:20px}.sandbox-events ol{padding-left:20px}.sandbox-events li{padding:8px 0 16px;line-height:1.7}.sandbox-events small{color:var(--admin-text-secondary)}.sandbox-detail{min-height:180px}.payout-sandbox :deep(td small){color:var(--admin-text-secondary)}
@media(max-width:600px){.sandbox-card{padding:12px}.sandbox-facts{grid-template-columns:100px minmax(0,1fr)}.sandbox-filters{gap:8px}.sandbox-filters .el-select{width:100%}.sandbox-controls .el-select{max-width:100%;width:100%}}
</style>
