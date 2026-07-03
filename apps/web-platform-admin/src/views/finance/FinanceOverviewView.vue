<template>
  <div class="dfx-page">
    <PageHeader title="财务概览" subtitle="全平台收入总览与抽成配置">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="stat-row">
      <StatCard label="平台总收入" :value="overview.totalIncome" icon="Money" icon-color="#C8A96E" prefix="¥" />
      <StatCard label="寺院结算" :value="overview.templeIncome" icon="OfficeBuilding" icon-color="#C45A3C" prefix="¥" />
      <StatCard label="法师结算" :value="overview.masterIncome" icon="Avatar" icon-color="#B5453A" prefix="¥" />
      <StatCard label="商城结算" :value="overview.shopIncome" icon="ShoppingCart" icon-color="#5B8C5A" prefix="¥" />
      <StatCard label="平台抽成" :value="overview.commissionIncome" icon="Coin" icon-color="#D4A843" prefix="¥" />
      <StatCard label="待审提现" :value="overview.pendingWithdraw" icon="Wallet" icon-color="#D4735A" suffix=" 笔" />
    </div>

    <div class="charts-row">
      <div class="dfx-card chart-card">
        <div class="section-title">收入构成</div>
        <div ref="pieRef" class="chart-body"></div>
      </div>
    </div>

    <!-- 抽成配置 -->
    <div class="dfx-card config-card">
      <div class="section-title">抽成配置</div>
      <el-table :data="configs" v-loading="configLoading" style="width: 100%">
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
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts'
import { Refresh } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import StatCard from '@/components/StatCard.vue'
import { getFinanceOverview, getCommissionConfigs, updateCommissionConfig } from '@/api/finance'
import { formatDate } from '@/utils/format'
import type { FinanceOverview, CommissionConfig } from '@/types'

interface ConfigRow extends CommissionConfig {
  _saving?: boolean
}

const pieRef = ref<HTMLElement>()
let pieChart: echarts.ECharts | null = null

const overview = reactive<FinanceOverview>({
  totalIncome: 0,
  templeIncome: 0,
  masterIncome: 0,
  shopIncome: 0,
  commissionIncome: 0,
  pendingWithdraw: 0
})
const configs = ref<ConfigRow[]>([])
const configLoading = ref(false)

function bizTypeText(t: string) {
  return { booking: '预约法事', diy_blessing: 'DIY加持', diy_material: 'DIY素材', shop_order: '商城订单' }[t] || t
}

function renderPie() {
  if (!pieRef.value) return
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
          { value: overview.templeIncome, name: '寺院结算', itemStyle: { color: '#C45A3C' } },
          { value: overview.masterIncome, name: '法师结算', itemStyle: { color: '#C8A96E' } },
          { value: overview.shopIncome, name: '商城结算', itemStyle: { color: '#5B8C5A' } },
          { value: overview.commissionIncome, name: '平台抽成', itemStyle: { color: '#D4A843' } }
        ]
      }
    ]
  })
}

async function loadData() {
  const [ovRes, cfgRes] = await Promise.allSettled([getFinanceOverview(), getCommissionConfigs({})])
  if (ovRes.status === 'fulfilled') Object.assign(overview, ovRes.value)
  configLoading.value = true
  try {
    if (cfgRes.status === 'fulfilled') configs.value = cfgRes.value.map((c) => ({ ...c }))
  } finally {
    configLoading.value = false
  }
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
</style>
