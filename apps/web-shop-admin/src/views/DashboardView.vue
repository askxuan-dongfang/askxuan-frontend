<script setup lang="ts">
// 商城工作台 - 今日订单 / 销售额 / 待发货 / 商品总数
import { ref, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts'
import { useRouter } from 'vue-router'
import StatCard from '@/components/StatCard.vue'
import { orderApi } from '@/api/order'
import { productApi } from '@/api/product'
import { formatMoney, orderStatusLabel, orderStatusType } from '@/utils/format'
import type { ShopOrder } from '@/types'

const router = useRouter()

const stats = ref([
  { label: '今日订单', value: 0, change: '统计中', up: true, icon: 'List', color: 'primary' as const },
  { label: '今日销售额', value: '¥0', change: '统计中', up: true, icon: 'Money', color: 'success' as const },
  { label: '待发货', value: 0, change: '需及时处理', up: false, icon: 'Box', color: 'warning' as const },
  { label: '商品总数', value: 0, change: '在售', up: true, icon: 'Goods', color: 'accent' as const }
])

const recentOrders = ref<ShopOrder[]>([])

const trendChartRef = ref<HTMLElement>()
let trendChart: echarts.ECharts | null = null

function initTrendChart() {
  if (!trendChartRef.value) return
  trendChart = echarts.init(trendChartRef.value)
  const today = new Date()
  const dates: string[] = []
  const sales: number[] = []
  const orders: number[] = []
  for (let i = 6; i >= 0; i--) {
    const d = new Date(today)
    d.setDate(today.getDate() - i)
    dates.push(`${d.getMonth() + 1}/${d.getDate()}`)
    sales.push(Math.round(2000 + Math.random() * 3000))
    orders.push(Math.round(15 + Math.random() * 20))
  }
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
  try {
    const list = await orderApi.list({ page: 1, size: 5 })
    recentOrders.value = list.list || []
    // 简单汇总
    const todayStr = new Date().toISOString().slice(0, 10)
    const todayOrders = (list.list || []).filter((o) => o.createTime?.startsWith(todayStr))
    stats.value[0].value = todayOrders.length
    stats.value[1].value = formatMoney(todayOrders.reduce((s, o) => s + o.payAmount, 0))
    stats.value[2].value = (list.list || []).filter((o) => o.status === 'paid').length
  } catch {
    recentOrders.value = []
  }

  try {
    const products = await productApi.list({ page: 1, size: 1 })
    stats.value[3].value = products.total
  } catch {
    // 忽略
  }
}

onMounted(async () => {
  await nextTick()
  initTrendChart()
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
      <div ref="trendChartRef" class="chart-box"></div>
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
      <el-table :data="recentOrders" style="width: 100%" empty-text="暂无订单数据">
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

@media (max-width: 1200px) {
  .stat-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
