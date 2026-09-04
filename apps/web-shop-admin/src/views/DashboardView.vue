<script setup lang="ts">
// 商城工作台 - 今日订单 / 销售额 / 待发货 / 商品总数
import { ref, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts'
import { useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import StatCard from '@/components/StatCard.vue'
import { orderApi } from '@/api/order'
import type { OrderReport } from '@/api/order'
import { productApi } from '@/api/product'
import { formatMoney, orderStatusLabel, orderStatusType } from '@/utils/format'
import type { ShopOrder } from '@/types'

const router = useRouter()
const loading = ref(false)
const loadIssueCount = ref(0)
const failedModules = ref<string[]>([])
const reportLoaded = ref(false)
const ordersLoaded = ref(false)
const pendingShip = ref<number | string>('—')

const stats = ref<Array<{
  label: string
  value: string | number
  change: string
  up: boolean
  icon: string
  color: 'primary' | 'warning' | 'success' | 'accent' | 'info'
}>>([
  { label: '今日订单', value: '—', change: '等待加载', up: true, icon: 'List', color: 'primary' as const },
  { label: '今日销售额', value: '—', change: '等待加载', up: true, icon: 'Money', color: 'success' as const },
  { label: '待发货', value: '—', change: '等待加载', up: false, icon: 'Box', color: 'warning' as const },
  { label: '商品总数', value: '—', change: '等待加载', up: true, icon: 'Goods', color: 'accent' as const }
])

const recentOrders = ref<ShopOrder[]>([])

const trendChartRef = ref<HTMLElement>()
let trendChart: echarts.ECharts | null = null

function buildTrendData(report: OrderReport | null) {
  const today = new Date()
  const map = new Map<string, { sales: number; orders: number }>()
  for (const t of report?.trend || []) {
    map.set(t.date, { sales: t.sales, orders: t.orders })
  }
  const dates: string[] = []
  const sales: number[] = []
  const orders: number[] = []
  for (let i = 6; i >= 0; i--) {
    const d = new Date(today)
    d.setDate(today.getDate() - i)
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
    dates.push(`${d.getMonth() + 1}/${d.getDate()}`)
    const point = map.get(key)
    sales.push(point?.sales || 0)
    orders.push(point?.orders || 0)
  }
  return { dates, sales, orders }
}

function initTrendChart() {
  if (!trendChartRef.value) return
  trendChart = echarts.init(trendChartRef.value)
  const { dates, sales, orders } = buildTrendData(null)
  trendChart.setOption({
    tooltip: { trigger: 'axis' },
    legend: { data: ['销售额', '订单数'], textStyle: { color: '#6A5A4A' } },
    grid: { left: 50, right: 50, top: 40, bottom: 30 },
    xAxis: {
      type: 'category',
      data: dates,
      axisLine: { lineStyle: { color: '#E8E0D8' } },
      axisLabel: { color: '#9A8A7A' }
    },
    yAxis: [
      {
        type: 'value',
        name: '销售额',
        axisLine: { show: false },
        axisTick: { show: false },
        splitLine: { lineStyle: { color: '#F0EBE5' } },
        axisLabel: { color: '#9A8A7A' }
      },
      {
        type: 'value',
        name: '订单数',
        axisLine: { show: false },
        axisTick: { show: false },
        splitLine: { show: false },
        axisLabel: { color: '#9A8A7A' }
      }
    ],
    series: [
      {
        name: '销售额',
        type: 'bar',
        data: sales,
        itemStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: '#C45A3C' },
            { offset: 1, color: 'rgba(196, 90, 60, 0.3)' }
          ]),
          borderRadius: [4, 4, 0, 0]
        },
        barWidth: '40%'
      },
      {
        name: '订单数',
        type: 'line',
        yAxisIndex: 1,
        smooth: true,
        data: orders,
        itemStyle: { color: '#C8A96E' },
        lineStyle: { width: 3, color: '#C8A96E' },
        symbol: 'circle',
        symbolSize: 8
      }
    ]
  })
}

function handleResize() {
  trendChart?.resize()
}

async function loadDashboard() {
  loading.value = true
  loadIssueCount.value = 0
  failedModules.value = []
  reportLoaded.value = false
  ordersLoaded.value = false
  pendingShip.value = '—'
  stats.value.forEach((item) => { item.value = '—'; item.change = '等待加载' })
  recentOrders.value = []
  try {
    const report = await orderApi.report()
    if (
      !Number.isFinite(report.todayOrders) ||
      !Number.isFinite(report.todaySales) ||
      !Number.isFinite(report.pendingShip) ||
      !Array.isArray(report.trend) ||
      !Array.isArray(report.topProducts)
    ) {
      throw new Error('经营报表返回的数据结构不完整')
    }
    reportLoaded.value = true
    stats.value[0].value = report.todayOrders
    stats.value[0].change = '今日'
    stats.value[1].value = formatMoney(report.todaySales)
    stats.value[1].change = '今日'
    stats.value[2].value = report.pendingShip
    pendingShip.value = report.pendingShip
    // 趋势图按真实数据重绘
    await nextTick()
    if (!trendChart) initTrendChart()
    const { dates, sales, orders } = buildTrendData(report)
    trendChart?.setOption({
      xAxis: { data: dates },
      series: [{ data: sales }, { data: orders }]
    })
  } catch {
    failedModules.value.push('经营报表')
  }

  try {
    const list = await orderApi.list({ page: 1, size: 5 })
    recentOrders.value = list.list || []
    ordersLoaded.value = true
  } catch {
    failedModules.value.push('最新订单')
  }

  try {
    const products = await productApi.list({ page: 1, size: 1 })
    stats.value[3].value = products.total
  } catch {
    failedModules.value.push('商品总数')
  }
  loadIssueCount.value = failedModules.value.length
  loading.value = false
}

onMounted(async () => {
  window.addEventListener('resize', handleResize)
  await loadDashboard()
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
  trendChart?.dispose()
})
</script>

<template>
  <div class="dashboard">
    <PageHeader title="今日工作台" subtitle="先处理履约、DIY 与售后任务，再查看经营趋势">
      <template #extra>
        <el-button :loading="loading" @click="loadDashboard">刷新数据</el-button>
      </template>
    </PageHeader>

    <div v-if="loadIssueCount" class="ax-page-feedback" :class="{ 'is-error': loadIssueCount === 3 }" role="status">
      <div class="ax-page-feedback__copy">
        <div class="ax-page-feedback__title">{{ loadIssueCount === 3 ? '商城工作台暂时无法加载' : '部分商城数据加载失败' }}</div>
        <div class="ax-page-feedback__description">失败模块：{{ failedModules.join('、') }}。未取得的数据保持“—”，不会将接口失败显示为 0。</div>
      </div>
      <el-button :loading="loading" @click="loadDashboard">重新加载</el-button>
    </div>

    <div class="ax-task-grid">
      <router-link class="ax-task-card" to="/diy-orders">
        <span class="ax-task-card__icon"><el-icon><Brush /></el-icon></span>
        <span class="ax-task-card__copy"><span class="ax-task-card__label">DIY 审核与制作</span><span class="ax-task-card__meta">查看当前制作节点</span></span>
        <strong class="ax-task-card__value">查看</strong>
      </router-link>
      <router-link class="ax-task-card" to="/orders">
        <span class="ax-task-card__icon"><el-icon><Box /></el-icon></span>
        <span class="ax-task-card__copy"><span class="ax-task-card__label">待发货订单</span><span class="ax-task-card__meta">进入订单履约列表</span></span>
        <strong class="ax-task-card__value">{{ pendingShip }}</strong>
      </router-link>
      <router-link class="ax-task-card" to="/returns">
        <span class="ax-task-card__icon"><el-icon><RefreshLeft /></el-icon></span>
        <span class="ax-task-card__copy"><span class="ax-task-card__label">售后处理</span><span class="ax-task-card__meta">退货、退款与异常单</span></span>
        <strong class="ax-task-card__value">查看</strong>
      </router-link>
      <router-link class="ax-task-card" to="/materials">
        <span class="ax-task-card__icon"><el-icon><Warning /></el-icon></span>
        <span class="ax-task-card__copy"><span class="ax-task-card__label">材料库存</span><span class="ax-task-card__meta">检查上下架与库存状态</span></span>
        <strong class="ax-task-card__value">查看</strong>
      </router-link>
    </div>

    <!-- 指标卡片 -->
    <div class="stat-grid">
      <StatCard
        v-for="item in stats"
        :key="item.label"
        :label="item.label"
        :value="item.value"
        :change="item.change"
        :up="item.up"
        :color="item.color"
        :icon="item.icon"
      />
    </div>

    <!-- 销售趋势 -->
    <div class="df-card chart-card">
      <div class="chart-header">
        <h3>近 7 日销售趋势</h3>
        <el-tag size="small" type="info" effect="plain">本周</el-tag>
      </div>
      <div v-if="reportLoaded" ref="trendChartRef" class="chart-box desktop-chart"></div>
      <div v-else class="chart-state">趋势数据未加载</div>
      <div v-if="reportLoaded" class="chart-mobile-summary">
        <div><span>今日销售额</span><b>{{ stats[1].value }}</b></div>
        <div><span>今日订单</span><b>{{ stats[0].value }} 单</b></div>
        <el-button link type="primary" @click="router.push('/reports')">查看完整经营报表</el-button>
      </div>
    </div>

    <!-- 近期订单 -->
    <div class="df-card">
      <div class="chart-header">
        <h3>最新订单</h3>
        <el-button text type="primary" @click="router.push('/orders')">
          查看全部
          <el-icon><ArrowRight /></el-icon>
        </el-button>
      </div>
      <el-table :data="recentOrders" style="width: 100%" :empty-text="ordersLoaded ? '暂无订单数据' : '订单列表加载失败'">
        <el-table-column label="订单号" prop="orderNo" width="200" />
        <el-table-column label="用户" prop="userId" width="160" />
        <el-table-column label="支付金额" width="140">
          <template #default="{ row }">
            <span class="font-semibold">{{ formatMoney(row.payAmount) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="120">
          <template #default="{ row }">
            <el-tag :type="orderStatusType(row.status)" effect="light" round size="small">
              {{ orderStatusLabel(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="下单时间" prop="createTime" min-width="180" />
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="router.push(`/orders/${row.id}`)">详情</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>
  </div>
</template>

<style scoped>
.stat-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 20px;
  margin-bottom: 24px;
}
.chart-card {
  padding: 0;
  overflow: hidden;
  margin-bottom: 24px;
}
.chart-header {
  padding: 16px 24px;
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.chart-header h3 {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-dark);
  margin: 0;
}
.chart-box {
  height: 340px;
  padding: 12px;
}
.chart-state {
  height: 240px;
  display: grid;
  place-items: center;
  color: var(--text-light);
  background: var(--admin-surface-muted);
}
.chart-mobile-summary {
  display: none;
}

@media (max-width: 1200px) {
  .stat-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 767px) {
  .chart-header {
    padding: 14px;
  }
  .desktop-chart { display: none; }
  .chart-mobile-summary {
    display: grid;
    gap: 10px;
    padding: 14px;
    background: var(--admin-surface-muted);
  }
  .chart-mobile-summary div { display: flex; justify-content: space-between; gap: 16px; }
  .chart-mobile-summary span { color: var(--color-text-secondary); }
  .chart-mobile-summary b { font-variant-numeric: tabular-nums; }
}
</style>
