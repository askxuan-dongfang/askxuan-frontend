<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts'
import { Refresh, Calendar, Wallet, DataAnalysis, CircleCheck } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import StatCard from '@/components/StatCard.vue'
import { getTempleReport } from '@/api/report'
import { formatMoney } from '@/utils/format'
import type { TempleReportResp } from '@/types'
import { useAuthStore } from '@/stores/auth'

const loading = ref(false)
const report = ref<TempleReportResp | null>(null)
const loadError = ref('')
const dateRange = ref<[string, string] | []>([])
const auth = useAuthStore()

const trendRef = ref<HTMLElement>()
const pieRef = ref<HTMLElement>()
const barRef = ref<HTMLElement>()
let trendChart: echarts.ECharts | null = null
let pieChart: echarts.ECharts | null = null
let barChart: echarts.ECharts | null = null

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    const params: { templeId: string; startTime?: string; endTime?: string } = { templeId: auth.templeId }
    if (dateRange.value && dateRange.value.length === 2) {
      params.startTime = dateRange.value[0]
      params.endTime = dateRange.value[1]
    }
    const nextReport = await getTempleReport(params)
    if (!nextReport?.revenueStats || !Array.isArray(nextReport.bookingTrend) || !Array.isArray(nextReport.serviceDistribution) || !Array.isArray(nextReport.masterRanking)) {
      throw new Error('报表服务返回的数据结构不完整')
    }
    report.value = nextReport
    await nextTick()
    renderCharts()
  } catch (error) {
    report.value = null
    loadError.value = error instanceof Error ? error.message : '报表加载失败'
    disposeCharts()
  } finally {
    loading.value = false
  }
}

function renderCharts() {
  if (!report.value) return
  // 趋势图
  if (trendRef.value) {
    trendChart ??= echarts.init(trendRef.value)
    const trend = report.value.bookingTrend || []
    trendChart.setOption({
      tooltip: { trigger: 'axis' },
      legend: { data: ['预约数', '功德金'], right: 0, top: 0 },
      grid: { left: 48, right: 56, top: 36, bottom: 32 },
      xAxis: { type: 'category', data: trend.map((t) => t.date), axisLine: { lineStyle: { color: '#E8E0D8' } } },
      yAxis: [
        { type: 'value', name: '预约数', splitLine: { lineStyle: { color: '#F0E9E1' } } },
        { type: 'value', name: '功德金', position: 'right', splitLine: { show: false } }
      ],
      series: [
        { name: '预约数', type: 'bar', data: trend.map((t) => t.bookings), itemStyle: { color: '#C45A3C', borderRadius: [4, 4, 0, 0] } },
        { name: '功德金', type: 'line', yAxisIndex: 1, smooth: true, data: trend.map((t) => t.revenue), itemStyle: { color: '#C8A96E' }, lineStyle: { width: 2 } }
      ]
    })
  }
  // 服务分布
  if (pieRef.value) {
    pieChart ??= echarts.init(pieRef.value)
    const dist = report.value.serviceDistribution || []
    pieChart.setOption({
      tooltip: { trigger: 'item', formatter: '{b}: {c} ({d}%)' },
      legend: { bottom: 0, type: 'scroll' },
      series: [
        {
          type: 'pie',
          radius: ['42%', '68%'],
          center: ['50%', '44%'],
          avoidLabelOverlap: true,
          itemStyle: { borderColor: '#fff', borderWidth: 2 },
          label: { show: false },
          data: dist.map((d) => ({ name: d.serviceName, value: d.count })),
          color: ['#C45A3C', '#C8A96E', '#D4A843', '#5B8C5A', '#B5453A', '#8A7A6A']
        }
      ]
    })
  }
  // 法师排行
  if (barRef.value) {
    barChart ??= echarts.init(barRef.value)
    const rank = (report.value.masterRanking || []).slice().reverse()
    barChart.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: 80, right: 24, top: 16, bottom: 24 },
      xAxis: { type: 'value', splitLine: { lineStyle: { color: '#F0E9E1' } } },
      yAxis: { type: 'category', data: rank.map((m) => m.masterName), axisLine: { lineStyle: { color: '#E8E0D8' } } },
      series: [
        {
          name: '功德金',
          type: 'bar',
          data: rank.map((m) => m.revenue),
          itemStyle: { color: '#C8A96E', borderRadius: [0, 4, 4, 0] },
          label: { show: true, position: 'right', formatter: (p: any) => formatMoney(p.value), color: '#6A5A4A', fontSize: 11 }
        }
      ]
    })
  }
}

function onResize() {
  trendChart?.resize()
  pieChart?.resize()
  barChart?.resize()
}

function disposeCharts() {
  trendChart?.dispose()
  pieChart?.dispose()
  barChart?.dispose()
  trendChart = null
  pieChart = null
  barChart = null
}

onMounted(() => {
  load()
  window.addEventListener('resize', onResize)
})
onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize)
  disposeCharts()
})
</script>

<template>
  <div class="df-page" v-loading="loading">
    <PageHeader title="数据报表" subtitle="寺院运营数据可视化">
      <el-date-picker
        v-model="dateRange"
        type="daterange"
        value-format="YYYY-MM-DD"
        range-separator="至"
        start-placeholder="开始日期"
        end-placeholder="结束日期"
        style="width: 280px"
      />
      <el-button :icon="Refresh" type="primary" @click="load">查询</el-button>
    </PageHeader>

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy"><div class="ax-page-feedback__title">寺院报表加载失败</div><div class="ax-page-feedback__description">{{ loadError }}。页面不会用 0 代替缺失经营数据。</div></div>
      <el-button :loading="loading" @click="load">重新加载</el-button>
    </div>

    <div class="stat-grid" v-if="report">
      <StatCard title="累计功德金" :value="formatMoney(report.revenueStats.totalRevenue)" :icon="Wallet" tone="accent" />
      <StatCard title="预约总数" :value="report.revenueStats.bookingCount" :icon="Calendar" tone="brand" suffix="单" />
      <StatCard title="客单功德" :value="formatMoney(report.revenueStats.avgBookingValue)" :icon="DataAnalysis" tone="success" />
      <StatCard title="已完成数" :value="report.revenueStats.completedCount" :icon="CircleCheck" tone="warning" suffix="单" />
    </div>

    <div v-if="report" class="desktop-report-charts">
    <div class="df-card chart-card big-chart">
      <div class="chart-title">预约与功德金趋势</div>
      <div ref="trendRef" class="chart-box"></div>
    </div>

    <div class="chart-grid">
      <div class="df-card chart-card">
        <div class="chart-title">服务分布</div>
        <div ref="pieRef" class="chart-box small"></div>
      </div>
      <div class="df-card chart-card">
        <div class="chart-title">法师功德金排行</div>
        <div ref="barRef" class="chart-box small"></div>
      </div>
    </div>
    </div>

    <div v-if="report" class="df-card mobile-report-summary">
      <div class="chart-title">经营摘要</div>
      <div class="summary-list">
        <div><span>趋势数据点</span><b>{{ report.bookingTrend.length }} 个</b></div>
        <div><span>服务分类</span><b>{{ report.serviceDistribution.length }} 类</b></div>
        <div><span>法师排行</span><b>{{ report.masterRanking.length }} 位</b></div>
      </div>
    </div>
    <div v-else-if="!loading && !loadError" class="df-card report-empty">当前范围暂无可展示报表</div>
  </div>
</template>

<style scoped>
.stat-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  margin-bottom: 16px;
}
.chart-card {
  padding: 18px 20px;
}
.chart-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 15px;
  font-weight: 600;
  color: #2a1e1a;
  margin-bottom: 12px;
}
.chart-box {
  width: 100%;
  height: 320px;
}
.chart-box.small {
  height: 300px;
}
.big-chart {
  margin-bottom: 16px;
}
.chart-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
.mobile-report-summary { display: none; padding: 16px; }
.summary-list { display: grid; gap: 10px; }
.summary-list div { display: flex; justify-content: space-between; gap: 16px; padding: 10px 12px; background: var(--color-bg-tertiary); border-radius: 8px; }
.summary-list span { color: var(--color-text-secondary); }
.summary-list b { font-variant-numeric: tabular-nums; }
.report-empty { padding: 36px 16px; color: var(--color-text-tertiary); text-align: center; }
@media (max-width: 767px) {
  .desktop-report-charts { display: none; }
  .mobile-report-summary { display: block; }
}
</style>
