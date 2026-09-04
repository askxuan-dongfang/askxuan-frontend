<template>
  <div class="dfx-page">
    <PageHeader title="财务概览" subtitle="全平台收入总览与抽成配置">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div v-if="loadIssueCount" class="ax-page-feedback" :class="{ 'is-error': loadIssueCount === 2 }" role="status">
      <div class="ax-page-feedback__copy">
        <div class="ax-page-feedback__title">{{ loadIssueCount === 2 ? '财务概览暂时无法加载' : '部分财务数据加载失败' }}</div>
        <div class="ax-page-feedback__description">未加载的指标显示为“—”，不会用 0 掩盖接口失败。</div>
      </div>
      <el-button :loading="loading" @click="loadData">重新加载</el-button>
    </div>

    <div class="stat-row">
      <StatCard label="平台总收入" :value="overview?.totalIncome ?? '—'" icon="Money" icon-color="#C8A96E" :prefix="overview ? '¥' : ''" />
      <StatCard label="寺院结算" :value="overview?.templeIncome ?? '—'" icon="OfficeBuilding" icon-color="#C45A3C" :prefix="overview ? '¥' : ''" />
      <StatCard label="法师结算" :value="overview?.masterIncome ?? '—'" icon="Avatar" icon-color="#B5453A" :prefix="overview ? '¥' : ''" />
      <StatCard label="商城结算" :value="overview?.shopIncome ?? '—'" icon="ShoppingCart" icon-color="#5B8C5A" :prefix="overview ? '¥' : ''" />
      <StatCard label="平台抽成" :value="overview?.commissionIncome ?? '—'" icon="Coin" icon-color="#D4A843" :prefix="overview ? '¥' : ''" />
      <StatCard label="待审提现" :value="overview?.pendingWithdraw ?? '—'" icon="Wallet" icon-color="#D4735A" :suffix="overview ? ' 笔' : ''" />
    </div>

    <div class="charts-row desktop-finance-chart">
      <div class="dfx-card chart-card">
        <div class="section-title">收入构成</div>
        <div v-if="overview" ref="pieRef" class="chart-body" aria-label="收入构成图表"></div>
        <div v-else class="chart-unavailable">财务汇总加载成功后显示收入构成</div>
      </div>
    </div>

    <div class="dfx-card mobile-finance-summary">
      <div class="section-title">收入构成摘要</div>
      <div v-if="overview" class="summary-grid">
        <div><span>寺院结算</span><b>¥{{ overview.templeIncome }}</b></div>
        <div><span>法师结算</span><b>¥{{ overview.masterIncome }}</b></div>
        <div><span>商城结算</span><b>¥{{ overview.shopIncome }}</b></div>
        <div><span>平台抽成</span><b>¥{{ overview.commissionIncome }}</b></div>
      </div>
      <div v-else class="chart-unavailable">暂无法生成收入构成摘要</div>
    </div>

    <!-- 抽成配置 -->
    <div class="dfx-card config-card">
      <div class="section-title">抽成配置</div>
      <el-table class="desktop-table" :data="configs" v-loading="configLoading" style="width: 100%">
        <el-table-column label="业务类型" width="160">
          <template #default="{ row }">{{ bizTypeText(row.bizType) }}</template>
        </el-table-column>
        <el-table-column label="抽成比例" width="160">
          <template #default="{ row }">
            <el-input-number v-model="row.rate" :min="0" :max="1" :step="0.01" :precision="2" size="small" controls-position="right" style="width: 120px" />
          </template>
        </el-table-column>
        <el-table-column label="说明" min-width="200">
          <template #default="{ row }">
            <el-input v-model="row.description" size="small" />
          </template>
        </el-table-column>
        <el-table-column label="更新时间" width="170">
          <template #default="{ row }">{{ formatDate(row.updateTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" :loading="row._saving" @click="saveConfig(row)">保存</el-button>
          </template>
        </el-table-column>
      </el-table>
      <MobileTaskList :items="configs" :loading="configLoading" :total="configs.length" :size="Math.max(1, configs.length)">
        <template #item="{ item: row }">
          <article class="mobile-task-card config-task-card">
            <div class="mobile-task-card__head"><strong>{{ bizTypeText(row.bizType) }}</strong><span class="muted">{{ formatDate(row.updateTime) }}</span></div>
            <label class="config-field"><span>抽成比例</span><el-input-number v-model="row.rate" :min="0" :max="1" :step="0.01" :precision="2" controls-position="right" /></label>
            <label class="config-field"><span>说明</span><el-input v-model="row.description" /></label>
            <el-button type="primary" :loading="row._saving" @click="saveConfig(row)">保存配置</el-button>
          </article>
        </template>
      </MobileTaskList>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts'
import { Refresh } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import StatCard from '@/components/StatCard.vue'
import MobileTaskList from '@/components/MobileTaskList.vue'
import { getFinanceOverview, getCommissionConfigs, updateCommissionConfig } from '@/api/finance'
import { formatDate } from '@/utils/format'
import type { FinanceOverview, CommissionConfig } from '@/types'

interface ConfigRow extends CommissionConfig {
  _saving?: boolean
}

const pieRef = ref<HTMLElement>()
let pieChart: echarts.ECharts | null = null

const overview = ref<FinanceOverview | null>(null)
const configs = ref<ConfigRow[]>([])
const loading = ref(false)
const configLoading = ref(false)
const loadIssueCount = ref(0)

function bizTypeText(t: string) {
  return { booking: '预约法事', diy_blessing: 'DIY加持', diy_material: 'DIY素材', shop_order: '商城订单' }[t] || t
}

function renderPie() {
  pieChart?.dispose()
  pieChart = null
  if (!pieRef.value || !overview.value) return
  pieChart = echarts.init(pieRef.value)
  pieChart.setOption({
    tooltip: { trigger: 'item' },
    legend: { bottom: 0, textStyle: { color: '#C5B097' } },
    series: [
      {
        type: 'pie',
        radius: ['40%', '70%'],
        center: ['50%', '45%'],
        itemStyle: { borderColor: '#2A1E1A', borderWidth: 2 },
        label: { color: '#C5B097' },
        data: [
          { value: overview.value.templeIncome, name: '寺院结算', itemStyle: { color: '#C45A3C' } },
          { value: overview.value.masterIncome, name: '法师结算', itemStyle: { color: '#C8A96E' } },
          { value: overview.value.shopIncome, name: '商城结算', itemStyle: { color: '#5B8C5A' } },
          { value: overview.value.commissionIncome, name: '平台抽成', itemStyle: { color: '#D4A843' } }
        ]
      }
    ]
  })
}

async function loadData() {
  loading.value = true
  configLoading.value = true
  loadIssueCount.value = 0
  const [ovRes, cfgRes] = await Promise.allSettled([getFinanceOverview(), getCommissionConfigs({})])
  overview.value = ovRes.status === 'fulfilled' ? ovRes.value : null
  if (cfgRes.status === 'fulfilled') configs.value = cfgRes.value.map((c) => ({ ...c }))
  loadIssueCount.value = [ovRes, cfgRes].filter((result) => result.status === 'rejected').length
  configLoading.value = false
  loading.value = false
  await nextTick()
  renderPie()
}

async function saveConfig(row: ConfigRow) {
  row._saving = true
  try {
    await updateCommissionConfig(row.id, { rate: row.rate, description: row.description })
    ElMessage.success('配置已保存')
  } finally {
    row._saving = false
  }
}

function onResize() {
  pieChart?.resize()
}
onMounted(() => {
  loadData()
  window.addEventListener('resize', onResize)
})
onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize)
  pieChart?.dispose()
})
</script>

<style scoped>
.stat-row {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 16px;
  margin-bottom: 20px;
}
.charts-row {
  margin-bottom: 20px;
}
.chart-card {
  padding: 18px 20px;
}
.chart-body {
  height: 260px;
}
.chart-unavailable {
  min-height: 160px;
  display: grid;
  place-items: center;
  color: var(--color-text-tertiary);
  text-align: center;
}
.mobile-finance-summary {
  display: none;
  padding: 18px 20px;
  margin-bottom: 20px;
}
.summary-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}
.summary-grid div {
  padding: 12px;
  display: grid;
  gap: 4px;
  background: var(--color-bg-tertiary);
  border-radius: 8px;
}
.summary-grid span, .muted {
  color: var(--color-text-tertiary);
  font-size: 12px;
}
.summary-grid b {
  font-size: 18px;
  font-variant-numeric: tabular-nums;
}
.config-field {
  display: grid;
  gap: 6px;
  color: var(--color-text-secondary);
  font-size: 12px;
}
.config-field :deep(.el-input-number) {
  width: 100%;
}
.config-card {
  padding: 18px 20px;
}
.section-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 16px;
  padding-left: 10px;
  border-left: 3px solid var(--color-accent);
}
@media (max-width: 767px) {
  .desktop-finance-chart { display: none; }
  .mobile-finance-summary { display: block; }
  .config-card { padding: 14px; }
  .summary-grid { grid-template-columns: 1fr; }
}
</style>
