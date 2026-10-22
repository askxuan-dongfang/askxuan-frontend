<template>
  <div class="dfx-page service-overview">
    <PageHeader :title="$t('服务监管')" :subtitle="$t('全平台预约、即时咨询与履约记录')">
      <template #actions><el-button :loading="current.loading" @click="load(active)">{{ $t('刷新') }}</el-button></template>
    </PageHeader>

    <div class="service-scope-note" role="note">
      <el-tag type="info">{{ $t('只读监管') }}</el-tag>
      <p>{{ $t('订单处理仍由原业务端完成；此处不提供确认、完成、取消或退款操作。') }}</p>
    </div>

    <div class="dfx-card service-card">
      <el-tabs v-model="active" @tab-change="onTabChange">
        <el-tab-pane :label="$t('预约服务')" name="bookings" />
        <el-tab-pane :label="$t('即时咨询')" name="consultations" />
      </el-tabs>

      <form class="service-filters" @submit.prevent="search">
        <el-input v-model="current.form.q" :aria-label="$t('搜索订单')" :placeholder="$t(active === 'bookings' ? '订单号、寺院、师傅或服务' : '订单号、寺院或师傅')" maxlength="100" clearable />
        <el-input v-model="current.form.templeId" :aria-label="$t('寺院编码')" :placeholder="$t('寺院编码')" maxlength="64" clearable />
        <el-input v-model="current.form.masterId" :aria-label="$t('师傅编码')" :placeholder="$t('师傅编码')" maxlength="64" clearable />
        <el-select v-model="current.form.status" :aria-label="$t('业务状态')" :placeholder="$t('业务状态')" clearable>
          <el-option v-for="option in statusOptions" :key="option.value" :value="option.value" :label="$t(option.label)" />
        </el-select>
        <el-select v-model="current.form.paymentStatus" :aria-label="$t('支付状态')" :placeholder="$t('支付状态')" clearable>
          <el-option v-for="option in paymentOptions" :key="option.value" :value="option.value" :label="$t(option.label)" />
        </el-select>
        <el-date-picker v-model="current.form.dates" type="daterange" value-format="YYYY-MM-DD" :aria-label="$t('创建日期范围')" :start-placeholder="$t('创建开始日')" :end-placeholder="$t('创建结束日')" :range-separator="$t('至')" />
        <div class="service-filter-actions">
          <el-button native-type="submit" type="primary" :loading="current.loading">{{ $t('查询') }}</el-button>
          <el-button @click="reset">{{ $t('重置') }}</el-button>
        </div>
      </form>
      <p class="service-help">{{ $t('筛选查询全部订单；创建日期包含所选起止日。两个业务列表分别保存筛选和页码。') }}</p>

      <div v-if="current.error" class="ax-page-feedback is-error" role="alert">
        <div class="ax-page-feedback__copy"><strong>{{ $t(current.error) }}</strong><p>{{ $t('本列表暂时不可用，另一业务列表不受影响。') }}</p></div>
        <el-button @click="load(active)">{{ $t('重新加载') }}</el-button>
      </div>
      <template v-else>
        <p v-if="current.total !== null" class="service-results" role="status">{{ $t('查询结果') }}：{{ current.total }} {{ $t('条') }}</p>
        <DataTable v-model:page="current.page" v-model:size="current.size" :data="current.list" :total="current.total ?? 0" :loading="current.loading" @change="load(active)">
          <el-table-column :label="$t('订单号')" min-width="185"><template #default="{ row }"><router-link :to="orderLink(row.id)" class="service-order-link">{{ row.id }}</router-link></template></el-table-column>
          <el-table-column :label="$t('寺院与师傅')" min-width="205"><template #default="{ row }"><div>{{ row.templeName || $t('独立执业') }}</div><small>{{ row.templeId || '—' }}</small><div>{{ row.masterName || $t('未分配师傅') }}</div><small>{{ row.masterId || '—' }}</small></template></el-table-column>
          <el-table-column :label="$t(active === 'bookings' ? '服务与预约时间' : '咨询有效时间')" min-width="190"><template #default="{ row }"><template v-if="active === 'bookings'"><div>{{ row.serviceName || row.serviceId || '—' }}</div><small>{{ row.bookingDate }} {{ row.timeSlot }}</small></template><template v-else><div>{{ $t('即时咨询') }}</div><small>{{ row.validFrom ? formatDate(row.validFrom) : $t('尚未生效') }}</small><div v-if="row.expiresAt"><small>{{ $t('到期') }} {{ formatDate(row.expiresAt) }}</small></div></template></template></el-table-column>
          <el-table-column :label="$t('金额')" width="140" align="right"><template #default="{ row }"><strong>{{ formatMoney(amount(row, active)) }}</strong><div v-if="isSimulated(row)"><el-tag size="small" type="info">{{ $t('演示支付') }}</el-tag></div></template></el-table-column>
          <el-table-column :label="$t('业务状态')" width="115"><template #default="{ row }"><el-tag :type="stateTone(row.status)">{{ $t(statusLabel(row.status, active)) }}</el-tag></template></el-table-column>
          <el-table-column :label="$t('支付状态')" width="115"><template #default="{ row }">{{ $t(paymentLabel(row.paymentStatus)) }}</template></el-table-column>
          <el-table-column :label="$t('创建时间')" width="160"><template #default="{ row }">{{ formatDate(row.createdAt) }}</template></el-table-column>
          <el-table-column :label="$t('查看')" width="130" fixed="right"><template #default="{ row }"><router-link :to="orderLink(row.id)" class="service-order-link">{{ $t(active === 'bookings' ? '原单与履约' : '原单详情') }}</router-link></template></el-table-column>
        </DataTable>
      </template>
    </div>

    <el-drawer v-model="detail.visible" :title="$t(detail.kind === 'bookings' ? '预约原单与履约' : '即时咨询原单')" size="min(760px, 100vw)" @close="closeDetailRoute">
      <div v-loading="detail.loading" class="service-detail">
        <div v-if="detail.error" class="ax-page-feedback is-error" role="alert"><p>{{ $t(detail.error) }}</p><el-button @click="openDetail(detail.kind, detail.id)">{{ $t('重新加载') }}</el-button></div>
        <template v-if="detail.data">
          <div class="service-detail-heading"><strong>{{ detail.data.id }}</strong><el-tag :type="stateTone(detail.data.status)">{{ $t(statusLabel(detail.data.status, detail.kind)) }}</el-tag></div>
          <p class="service-help">{{ $t('下列名称、时间和金额来自原单快照，不代表提供者当前配置。') }}</p>
          <dl class="service-facts">
            <dt>{{ $t('信众编号') }}</dt><dd>{{ detail.data.userId }}</dd>
            <dt>{{ $t('寺院') }}</dt><dd>{{ detail.data.templeName || $t('独立执业') }} <small>{{ detail.data.templeId }}</small></dd>
            <dt>{{ $t('师傅') }}</dt><dd>{{ detail.data.masterName || $t('未分配师傅') }} <small>{{ detail.data.masterId }}</small></dd>
            <dt>{{ $t('支付状态') }}</dt><dd>{{ $t(paymentLabel(detail.data.paymentStatus)) }} <el-tag v-if="isSimulated(detail.data)" type="info" size="small">{{ $t('演示支付') }}</el-tag></dd>
            <dt>{{ $t('支付单号') }}</dt><dd>{{ detail.data.paymentNo || '—' }}</dd>
            <dt>{{ $t('创建时间') }}</dt><dd>{{ formatDate(detail.data.createdAt) }}</dd>
            <template v-if="detail.kind === 'bookings'">
              <dt>{{ $t('服务') }}</dt><dd>{{ detail.data.serviceName }} <small>{{ detail.data.serviceId }}</small></dd>
              <dt>{{ $t('预约时间') }}</dt><dd>{{ detail.data.bookingDate }} {{ detail.data.timeSlot }}</dd>
              <dt>{{ $t('法师执行费') }}</dt><dd>{{ formatMoney(detail.data.serviceFee) }}</dd>
              <dt>{{ $t('寺院服务费与随喜') }}</dt><dd>{{ formatMoney(detail.data.meritMoney) }}</dd>
            </template>
            <template v-else>
              <dt>{{ $t('生效时间') }}</dt><dd>{{ detail.data.validFrom ? formatDate(detail.data.validFrom) : $t('尚未生效') }}</dd>
              <dt>{{ $t('到期时间') }}</dt><dd>{{ detail.data.expiresAt ? formatDate(detail.data.expiresAt) : '—' }}</dd>
              <dt>{{ $t('承诺首响') }}</dt><dd>{{ detail.data.responseMinutes }} {{ $t('分钟') }}</dd>
            </template>
            <dt>{{ $t('订单金额') }}</dt><dd><strong>{{ formatMoney(amount(detail.data, detail.kind)) }}</strong></dd>
          </dl>
          <section v-if="detail.kind === 'consultations' && detail.data.question" class="service-detail-section"><h3>{{ $t('下单问题') }}</h3><p class="service-preserve-text">{{ detail.data.question }}</p></section>
          <section v-if="detail.kind === 'bookings' && detail.data.note" class="service-detail-section"><h3>{{ $t('预约备注') }}</h3><p class="service-preserve-text">{{ detail.data.note }}</p></section>

          <section v-if="detail.kind === 'bookings'" v-loading="detail.fulfillmentLoading" class="service-detail-section">
            <h3>{{ $t('履约记录') }}</h3>
            <div v-if="detail.fulfillmentError" class="ax-page-feedback is-error" role="alert"><p>{{ $t('原单已加载，履约记录读取失败。') }}</p><el-button @click="loadFulfillment(detail.id, detailSequence)">{{ $t('重试履约记录') }}</el-button></div>
            <template v-else-if="detail.fulfillment">
              <h4>{{ $t('状态时间线') }}</h4>
              <ol v-if="detail.fulfillment.logs?.length" class="service-history"><li v-for="log in detail.fulfillment.logs" :key="log.id"><strong>{{ $t(statusLabel(log.fromStatus, 'bookings')) }} → {{ $t(statusLabel(log.toStatus, 'bookings')) }}</strong><small>{{ formatDate(log.createTime) }} · {{ log.operatorType }} {{ log.operatorId }}</small><p v-if="log.remark" class="service-preserve-text">{{ log.remark }}</p></li></ol>
              <p v-else class="service-help">{{ $t('暂无状态变更记录') }}</p>
              <h4>{{ $t('执行回执') }}</h4>
              <article v-for="receipt in detail.fulfillment.receipts || []" :key="receipt.id" class="service-record"><p class="service-preserve-text">{{ receipt.summary }}</p><small>{{ formatDate(receipt.createdAt) }} · {{ receipt.operatorType }} {{ receipt.operatorId }}</small><ul class="service-files"><li v-for="file in receipt.files || []" :key="file.id"><span>{{ file.name }}</span><el-button link :loading="downloading === file.id" @click="downloadFile(file)">{{ $t('下载回执') }}</el-button></li></ul></article>
              <p v-if="!detail.fulfillment.receipts?.length" class="service-help">{{ $t('暂无执行回执') }}</p>
              <h4>{{ $t('心愿与服务进展') }}</h4>
              <article v-for="record in detail.fulfillment.records || []" :key="record.id" class="service-record"><el-tag type="info" size="small">{{ $t(record.kind === 'wish' ? '心愿记录' : '服务进展') }}</el-tag><p class="service-preserve-text">{{ record.content }}</p><small>{{ formatDate(record.createdAt) }} · {{ record.operatorType }} {{ record.operatorId }}</small><ul class="service-files"><li v-for="file in record.files || []" :key="file.id"><span>{{ file.name }}</span><el-button link :loading="downloading === file.id" @click="downloadFile(file)">{{ $t('下载回执') }}</el-button></li></ul></article>
              <p v-if="!detail.fulfillment.records?.length" class="service-help">{{ $t('暂无心愿与服务进展') }}</p>
            </template>
          </section>
          <p class="service-provider-links"><router-link to="/temple/list">{{ $t('查看寺院资料与服务配置') }}</router-link><router-link to="/master/list">{{ $t('查看师傅资料与服务配置') }}</router-link></p>
        </template>
      </div>
    </el-drawer>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import { isAdminSessionExpired } from '@/api/client'
import { downloadServiceReceipt, getServiceFulfillment, getServiceOrder, getServiceOrders, type ServiceFulfillment, type ServiceOrder, type ServiceOrderKind, type ServiceOrderQuery, type ServiceReceiptFile } from '@/api/serviceOverview'
import { formatDate, formatMoney } from '@/utils/format'

interface Filters { q: string; status: string; paymentStatus: string; templeId: string; masterId: string; dates: string[] | null }
interface ListState { form: Filters; applied: Filters; page: number; size: number; total: number | null; list: ServiceOrder[]; loading: boolean; loaded: boolean; error: string }
const emptyFilters = (): Filters => ({ q: '', status: '', paymentStatus: '', templeId: '', masterId: '', dates: [] })
const emptyState = (): ListState => ({ form: emptyFilters(), applied: emptyFilters(), page: 1, size: 20, total: null, list: [], loading: false, loaded: false, error: '' })
const states = reactive<Record<ServiceOrderKind, ListState>>({ bookings: emptyState(), consultations: emptyState() })
const active = ref<ServiceOrderKind>('bookings')
const current = computed(() => states[active.value])
const route = useRoute(), router = useRouter()
const requests: Record<ServiceOrderKind, number> = { bookings: 0, consultations: 0 }
let alive = true
let detailSequence = 0
const detail = reactive({ visible: false, kind: 'bookings' as ServiceOrderKind, id: '', loading: false, error: '', data: null as ServiceOrder | null, fulfillment: null as ServiceFulfillment | null, fulfillmentLoading: false, fulfillmentError: '' })
const downloading = ref('')
const bookingStatuses = [
  { value: 'pending_payment', label: '待付款' }, { value: 'pending', label: '待确认' },
  { value: 'confirmed', label: '已确认' }, { value: 'in_progress', label: '执行中' },
  { value: 'pending_receipt', label: '待验收' }, { value: 'completed', label: '已完成' },
  { value: 'cancelled', label: '已取消' }, { value: 'reviewed', label: '已评价' }
]
const consultationStatuses = [{ value: 'pending_payment', label: '待付款' }, { value: 'active', label: '服务中' }, { value: 'expired', label: '已到期' }, { value: 'closed', label: '已关闭' }]
const statusOptions = computed(() => active.value === 'bookings' ? bookingStatuses : consultationStatuses)
const allPayments = [{ value: 'pending', label: '待付款' }, { value: 'success', label: '已付款' }, { value: 'failed', label: '支付失败' }, { value: 'legacy', label: '历史支付记录' }, { value: 'refunding', label: '退款中' }, { value: 'refunded', label: '已退款' }]
const paymentOptions = computed(() => active.value === 'bookings' ? allPayments : allPayments.slice(0, 2))
function statusLabel(status: string, kind: ServiceOrderKind) { return (kind === 'bookings' ? bookingStatuses : consultationStatuses).find(item => item.value === status)?.label || status || '—' }
function paymentLabel(status: string) { return allPayments.find(item => item.value === status)?.label || status || '—' }
function stateTone(status: string): 'success' | 'warning' | 'info' | 'danger' {
  if (['completed', 'reviewed'].includes(status)) return 'success'
  if (['cancelled', 'closed'].includes(status)) return 'danger'
  return ['pending', 'pending_payment', 'pending_receipt'].includes(status) ? 'warning' : 'info'
}
function amount(row: ServiceOrder, kind: ServiceOrderKind) { return kind === 'bookings' ? row.totalFee : row.consultFee }
function isSimulated(row: ServiceOrder) { return row.simulated || ['mock', 'demo_balance'].includes(row.paymentChannel || '') }
function orderLink(id: string) { return { path: '/services/overview', query: { kind: active.value, order: id } } }
function cloneFilters(form: Filters): Filters { return { ...form, dates: form.dates ? [...form.dates] : [] } }
async function load(kind: ServiceOrderKind) {
  const state = states[kind], sequence = ++requests[kind]
  const form = state.applied
  const params: ServiceOrderQuery = { page: state.page, size: state.size, q: form.q.trim() || undefined, status: form.status || undefined, paymentStatus: form.paymentStatus || undefined, templeId: form.templeId.trim() || undefined, masterId: form.masterId.trim() || undefined, from: form.dates?.[0] || undefined, to: form.dates?.[1] || undefined }
  state.loading = true; state.error = ''
  try {
    const result = await getServiceOrders(kind, params)
    if (!alive || sequence !== requests[kind]) return
    state.list = result.list; state.total = result.total; state.page = result.page; state.size = result.size; state.loaded = true
  } catch (error) {
    if (!alive || sequence !== requests[kind] || isAdminSessionExpired(error)) return
    state.error = kind === 'bookings' ? '预约列表加载失败，请重试。' : '即时咨询列表加载失败，请重试。'
    state.list = []; state.total = null
  } finally { if (alive && sequence === requests[kind]) state.loading = false }
}
function search() { current.value.applied = cloneFilters(current.value.form); current.value.page = 1; void load(active.value) }
function reset() { current.value.form = emptyFilters(); search() }
function onTabChange() {
  // A route deep link also updates the active tab; preserve its order query.
  if (route.query.kind !== active.value) void router.replace({ path: route.path, query: { kind: active.value } })
  if (!current.value.loaded && !current.value.loading) void load(active.value)
}
async function openDetail(kind: ServiceOrderKind, id: string) {
  const sequence = ++detailSequence
  Object.assign(detail, { visible: true, kind, id, data: null, loading: true, error: '', fulfillment: null, fulfillmentError: '', fulfillmentLoading: false })
  try {
    const result = await getServiceOrder(kind, id)
    if (!alive || sequence !== detailSequence) return
    detail.data = result
    if (kind === 'bookings') void loadFulfillment(id, sequence)
  } catch (error) {
    if (alive && sequence === detailSequence && !isAdminSessionExpired(error)) detail.error = '原单读取失败或已不存在，请重试。'
  } finally { if (alive && sequence === detailSequence) detail.loading = false }
}
async function loadFulfillment(id: string, sequence: number) {
  detail.fulfillmentLoading = true; detail.fulfillmentError = ''
  try {
    const result = await getServiceFulfillment(id)
    if (alive && sequence === detailSequence) detail.fulfillment = result
  } catch (error) {
    if (alive && sequence === detailSequence && !isAdminSessionExpired(error)) detail.fulfillmentError = '履约记录读取失败'
  } finally { if (alive && sequence === detailSequence) detail.fulfillmentLoading = false }
}
function closeDetailRoute() {
  ++detailSequence
  if (route.query.order === detail.id) void router.replace({ path: route.path, query: { kind: active.value } })
}
function syncRoute() {
  const kind: ServiceOrderKind = route.query.kind === 'consultations' ? 'consultations' : 'bookings'
  active.value = kind
  if (!states[kind].loaded && !states[kind].loading) void load(kind)
  const id = typeof route.query.order === 'string' ? route.query.order : ''
  if (id && (!detail.visible || detail.id !== id || detail.kind !== kind)) void openDetail(kind, id)
  if (!id && detail.visible) detail.visible = false
}
async function downloadFile(file: ServiceReceiptFile) {
  downloading.value = file.id
  try {
    const blob = await downloadServiceReceipt(detail.id, file.id)
    const url = URL.createObjectURL(blob), anchor = document.createElement('a')
    anchor.href = url; anchor.download = file.name.replace(/[\\/\r\n]/g, '_') || 'receipt'
    anchor.click(); window.setTimeout(() => URL.revokeObjectURL(url), 1000)
  } catch { /* The shared request client reports download failures. */ }
  finally { downloading.value = '' }
}
watch(() => route.fullPath, syncRoute)
onMounted(syncRoute)
onBeforeUnmount(() => { alive = false; requests.bookings++; requests.consultations++; detailSequence++ })
</script>

<style scoped>
.service-scope-note{display:flex;align-items:flex-start;gap:12px;color:var(--admin-text-secondary);margin-bottom:16px}.service-scope-note p{margin:0;line-height:1.6}.service-card{padding:20px}.service-filters{display:grid;grid-template-columns:minmax(220px,2fr) repeat(4,minmax(125px,1fr));gap:12px}.service-filters :deep(.el-date-editor){width:100%;grid-column:span 3}.service-filter-actions{display:flex;gap:8px;grid-column:span 2;justify-content:flex-end}.service-help,.service-results{color:var(--admin-text-secondary);font-size:13px;line-height:1.65}.service-results{margin:16px 0 8px}.service-order-link,.service-provider-links a{color:var(--admin-primary);text-decoration:underline;text-underline-offset:3px}.service-overview :deep(td small),.service-facts small{color:var(--admin-text-secondary)}.service-detail{min-height:180px}.service-detail-heading{display:flex;align-items:center;flex-wrap:wrap;gap:12px;overflow-wrap:anywhere}.service-facts{display:grid;grid-template-columns:110px minmax(0,1fr);gap:12px;margin-top:24px}.service-facts dt{color:var(--admin-text-secondary)}.service-facts dd{margin:0;overflow-wrap:anywhere}.service-detail-section{margin-top:28px;border-top:1px solid var(--admin-border);padding-top:16px}.service-detail-section h3{font-size:17px}.service-detail-section h4{font-size:14px;margin-top:22px}.service-history{padding-left:20px}.service-history li{margin-bottom:18px}.service-history small{display:block;margin-top:6px;color:var(--admin-text-secondary)}.service-record{padding:14px 0;border-bottom:1px solid var(--admin-border)}.service-record small{color:var(--admin-text-secondary)}.service-preserve-text{white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.7}.service-files{list-style:none;padding:0;margin:10px 0 0}.service-files li{display:flex;gap:12px;align-items:center;justify-content:space-between;overflow-wrap:anywhere}.service-provider-links{display:flex;flex-wrap:wrap;gap:16px;margin-top:24px;font-size:13px}
@media(max-width:1100px){.service-filters{grid-template-columns:repeat(2,minmax(0,1fr))}.service-filters :deep(.el-date-editor){grid-column:span 2}.service-filter-actions{grid-column:span 2}.service-card{padding:16px}}
@media(max-width:480px){.service-card{padding:12px}.service-filters{grid-template-columns:minmax(0,1fr)}.service-filters :deep(.el-date-editor),.service-filter-actions{grid-column:auto}.service-filter-actions{justify-content:flex-start}.service-facts{grid-template-columns:85px minmax(0,1fr)}.service-scope-note{gap:8px}.service-scope-note p{font-size:13px}}
</style>
