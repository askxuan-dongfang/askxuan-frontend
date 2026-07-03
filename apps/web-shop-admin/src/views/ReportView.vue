<script setup lang="ts">
// 商城报表 - ECharts 渲染销售趋势 + Top 商品
import { ref, reactive, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts'
import PageHeader from '@/components/PageHeader.vue'
import StatCard from '@/components/StatCard.vue'
import { reportApi } from '@/api/report'
import { formatMoney } from '@/utils/format'
import type { ShopReport } from '@/types'

const loading = ref(false)
const dateRange = ref<[string, string] | null>(null)
const report = ref<ShopReport | null>(null)

const trendChartRef = ref<HTMLElement>()
const topChartRef = ref<HTMLElement>()
let trendChart: echarts.ECharts | null = null
let topChart: echarts.ECharts | null = null

function defaultRange(): [string, string] {
  const end = new Date()
  const start = new Date()
  start.setDate(start.getDate() - 29)
  return [start.toISOString().slice(0, 10), end.toISOString().slice(0, 10)]
}

async function loadReport() {
  loading.value = true
  try {
    const [startTime, endTime] = dateRange.value || defaultRange()
    report.value = await reportApi.shopReports({ startTime, endTime })
    await nextTick()
    renderCharts()
  } catch {
    // 失败时使用空数据渲染
    report.value = {
      totalSales: 0,
      totalOrders: 0,
      avgOrderValue: 0,
      refundRate: 0,
      salesTrend: [],
      topProducts: []
    }
    await nextTick()
    renderCharts()
  } finally {
    loading.value = false
  }
}

function renderCharts() {
  renderTrend()
  renderTop()
}

function renderTrend() {
  if (!trendChartRef.value) return
  if (!trendChart) {
    trendChart = echarts.init(trendChartRef.value)
  }
  const trend = report.value?.salesTrend || []
  trendChart.setOption({
    tooltip: { trigger: 'axis' },
    legend: { data: ['销售额', '订单数'], textStyle: { color: '#6A5A4A' } },
    grid: { left: 60, right: 50, top: 40, bottom: 40 },
    xAxis: {
      type: 'category',
      data: trend.map((p) => p.date),
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
        axisLabel: { color: '#9A8A7A', formatter: '{value}' }
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
        type: 'line',
        smooth: true,
        data: trend.map((p) => p.sales),
        itemStyle: { color: '#C45A3C' },
        lineStyle: { width: 3, color: '#C45A3C' },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(196, 90, 60, 0.25)' },
            { offset: 1, color: 'rgba(196, 90, 60, 0)' }
          ])
        },
        symbol: 'circle',
        symbolSize: 6
      },
      {
        name: '订单数',
        type: 'bar',
        yAxisIndex: 1,
        data: trend.map((p) => p.orders),
        itemStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(200, 169, 110, 0.8)' },
            { offset: 1, color: 'rgba(200, 169, 110, 0.2)' }
          ]),
          borderRadius: [4, 4, 0, 0]
        },
        barWidth: '40%'
      }
    ]
  })
}

function renderTop() {
  if (!topChartRef.value) return
  if (!topChart) {
    topChart = echarts.init(topChartRef.value)
  }
  const top = (report.value?.topProducts || []).slice(0, 10).reverse()
  topChart.setOption({
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: 160, right: 40, top: 20, bottom: 30 },
    xAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { lineStyle: { color: '#F0EBE5' } },
      axisLabel: { color: '#9A8A7A' }
    },
    yAxis: {
      type: 'category',
      data: top.map((p) => p.productName),
      axisLine: { lineStyle: { color: '#E8E0D8' } },
      axisLabel: { color: '#6A5A4A' }
    },
    series: [
      {
        name: '销售额',
        type: 'bar',
        data: top.map((p) => p.sales),
        itemStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 1, 0, [
            { offset: 0, color: '#C45A3C' },
            { offset: 1, color: '#D4735A' }
          ]),
          borderRadius: [0, 4, 4, 0]
        },
        label: {
          show: true,
          position: 'right',
          color: '#6A5A4A',
          formatter: (params: any) => formatMoney(params.value)
        }
      }
    ]
  })
}

function handleResize() {
  trendChart?.resize()
  topChart?.resize()
}

function handleSearch() {
  loadReport()
}

onMounted(async () => {
  dateRange.value = defaultRange()
  await loadReport()
  window.addEventListener('resize', handleResize)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
  trendChart?.dispose()
  topChart?.dispose()
})
</script>

<template>
  <div class="page-wrap" v-loading="loading">
    <PageHeader title="数据报表" subtitle="商城销售趋势、Top 商品销售排行" />

    <!-- 筛选 -->
    <div class="df-card filter-bar">
      <el-form inline @submit.prevent="handleSearch">
        <el-form-item label="时间范围">
          <el-date-picker
            v-model="dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            value-format="YYYY-MM-DD"
            style="width: 280px"
          />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">查询</el-button>
        </el-form-item>
      </el-form>
    </div>

    <!-- 指标卡片 -->
    <div class="stat-grid" v-if="report">
      <StatCard label="总销售额" :value="formatMoney(report.totalSales)" change="统计区间内" color="primary" icon="Money" />
      <StatCard label="总订单数" :value="report.totalOrders" change="统计区间内" color="success" icon="List" />
      <StatCard label="客单价" :value="formatMoney(report.avgOrderValue)" change="平均" color="accent" icon="Coin" />
      <StatCard label="退货率" :value="`${(report.refundRate * 100).toFixed(2)}%`" :up="false" change="越低越好" color="warning" icon="RefreshLeft" />
    </div>

    <!-- 销售趋势 -->
    <div class="df-card chart-card">
      <div class="chart-header">
        <h3>销售趋势</h3>
        <el-tag size="small" type="info" effect="plain">销售额 + 订单数</el-tag>
      </div>
      <div ref="trendChartRef" class="chart-box"></div>
    </div>

    <!-- Top 商品 -->
    <div class="df-card chart-card">
      <div class="chart-header">
        <h3>Top 商品销售排行</h3>
        <el-tag size="small" type="info" effect="plain">Top 10</el-tag>
      </div>
      <div ref="topChartRef" class="chart-box"></div>
    </div>

    <!-- Top 商品列表 -->
    <div class="df-card" v-if="report && report.topProducts.length">
      <div class="chart-header">
        <h3>Top 商品明细</h3>
      </div>
      <el-table :data="report.topProducts" style="width: 100%">
        <el-table-column label="排名" width="80" type="index" :index="1" />
        <el-table-column label="商品 ID" prop="productId" width="120" />
        <el-table-column label="商品名称" prop="productName" min-width="240" />
        <el-table-column label="销售额" width="140">
          <template #default="{ row }">
            <span class="price">{{ formatMoney(row.sales) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="订单数" prop="orderCount" width="120" />
      </el-table>
    </div>
  </div>
</template>

<style scoped>
.filter-bar {
  padding: 16px 24px;
  margin-bottom: 16px;
}
.filter-bar :deep(.el-form-item) {
  margin-bottom: 0;
}
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
  height: 360px;
  padding: 12px;
}
.price {
  color: var(--primary);
  font-weight: 600;
}

@media (max-width: 1200px) {
  .stat-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
