<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'
import client from '@/api/client'
import { downloadCSV } from '@/utils/csv'
import { money, settlementStatus } from '../../../../packages/wallet/contracts'
import { t } from '../../../../packages/localization/language'
type Group = { sourceType: string; status: string; count: number; grossCents: number; commissionCents: number; netCents: number }
type Report = { groups: Group[]; recordMode: string }
const range = ref<string[]>([]), mode = ref('accounting_only'), data = ref<Report>(), error = ref(''), busy = ref(false)
const sources: Record<string, string> = { booking: '预约服务', diy: 'DIY 加持', diy_order: 'DIY 加持', consultation: '即时咨询', '': '历史汇总' }
let seq = 0
let filters = { startTime: '', endTime: '', mode: 'accounting_only' }
async function load() {
  const run = ++seq; busy.value = true; error.value = ''; data.value = undefined
  const params = { startTime: range.value?.[0] || '', endTime: range.value?.[1] || '', mode: mode.value }
  try {
    const result = await client.get<Report>('/finance/wallet/temple/report', { params })
    if (run !== seq) return
    if (!Array.isArray(result.groups)) throw new Error(t('结算报表格式不完整'))
    data.value = result; filters = params
  } catch (e) { if (run === seq) error.value = (e as Error).message }
  finally { if (run === seq) busy.value = false }
}
function exportReport() {
  if (!data.value) return
  downloadCSV('寺院结算统计.csv', [
    ['口径', '本寺院结算账本；账面已结不代表银行到账'], ['账本', filters.mode], ['开始日期', filters.startTime || '全部'], ['结束日期', filters.endTime || '全部'],
    ['来源', '状态', '笔数', '寺院分配金额（元）', '平台费用（元）', '寺院应结金额（元）'],
    ...data.value.groups.map(r => [sources[r.sourceType] || r.sourceType, settlementStatus[r.status] || r.status, r.count, (r.grossCents / 100).toFixed(2), (r.commissionCents / 100).toFixed(2), (r.netCents / 100).toFixed(2)])
  ])
}
onMounted(load); onBeforeUnmount(() => seq++)
</script>
<template>
  <el-alert :closable="false" type="info" :title="$t('按结算记录创建日期统计本寺院份额，预约在信众评价结案后入账；包含预约与 DIY 等实际入账来源，不包含法师个人份额。账面已结不代表银行到账，真实提现未开放。')"/>
  <form class="filters" @submit.prevent="load">
    <el-date-picker v-model="range" type="daterange" value-format="YYYY-MM-DD" :start-placeholder="$t('开始日期')" :end-placeholder="$t('结束日期')"/>
    <el-select v-model="mode" :aria-label="$t('结算账本')"><el-option :label="$t('原有账面记录')" value="accounting_only"/><el-option :label="$t('模拟余额结算')" value="demo"/></el-select>
    <el-button native-type="submit" :loading="busy">{{ $t('查询') }}</el-button>
    <el-button :disabled="!data || busy" @click="exportReport">{{ $t('导出当前统计') }}</el-button>
  </form>
  <el-alert v-if="error" :title="error" type="error" :closable="false"/>
  <div class="df-card report-table" v-loading="busy">
    <el-table v-if="data" :data="data.groups">
      <el-table-column :label="$t('来源')" min-width="130"><template #default="{row}">{{ $t(sources[row.sourceType] || row.sourceType) }}</template></el-table-column>
      <el-table-column :label="$t('状态')" min-width="130"><template #default="{row}">{{ $t(settlementStatus[row.status] || row.status) }}</template></el-table-column>
      <el-table-column prop="count" :label="$t('笔数')" min-width="80"/>
      <el-table-column :label="$t('寺院分配金额')" min-width="150"><template #default="{row}">{{ money(row.grossCents) }}</template></el-table-column>
      <el-table-column :label="$t('平台费用')" min-width="120"><template #default="{row}">{{ money(row.commissionCents) }}</template></el-table-column>
      <el-table-column :label="$t('寺院应结金额')" min-width="150"><template #default="{row}">{{ money(row.netCents) }}</template></el-table-column>
    </el-table>
  </div>
</template>
<style scoped>.filters{display:flex;gap:12px;flex-wrap:wrap;margin:20px 0}.filters>.el-select{width:180px}.report-table{padding:16px;min-height:100px;min-width:0}.filters :deep(.el-date-editor){max-width:100%}</style>
