<script setup lang="ts">
import { withAdminChartTheme, watchAdminChartAppearance } from '../../../../packages/admin-ui/chart-theme'
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts'
import { Refresh, Calendar, Wallet, DataAnalysis, CircleCheck } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import SettlementReport from '@/components/SettlementReport.vue'
import { downloadCSV } from '@/utils/csv'
import StatCard from '@/components/StatCard.vue'
import { getTempleReport } from '@/api/report'
import { formatMoney } from '@/utils/format'
import type { TempleReportResp } from '@/types'
import { useAuthStore } from '@/stores/auth'

const tab = ref('bookings')
const loading = ref(false)
let generation = 0
const report = ref<TempleReportResp | null>(null)
const loadError = ref('')
const appliedRange = ref<string[]>([])
const dateRange = ref<[string, string] | []>([])
const auth = useAuthStore()

const trendRef = ref<HTMLElement>()
const pieRef = ref<HTMLElement>()
const barRef = ref<HTMLElement>()
let trendChart: echarts.ECharts | null = null
let pieChart: echarts.ECharts | null = null
let barChart: echarts.ECharts | null = null

async function load() {
  const run = ++generation
  loading.value = true
  loadError.value = ''
  try {
    const params: { templeId: string; startTime?: string; endTime?: string } = { templeId: auth.templeId }
    if (dateRange.value && dateRange.value.length === 2) {
      params.startTime = dateRange.value[0]
      params.endTime = dateRange.value[1]
    }
    const nextReport = await getTempleReport(params)
    if (run !== generation) return
    if (!Number.isSafeInteger(nextReport?.revenueStats?.contractCents)) throw new Error('报表口径尚未更新，请稍后重试')
    if (!nextReport?.revenueStats || !Array.isArray(nextReport.bookingTrend) || !Array.isArray(nextReport.serviceDistribution) || !Array.isArray(nextReport.masterRanking)) {
      throw new Error('报表服务返回的数据结构不完整')
    }
    appliedRange.value = [params.startTime || '', params.endTime || '']
    report.value = nextReport
    await nextTick()
    renderCharts()
  } catch (error) {
    if (run !== generation) return
    report.value = null
    loadError.value = error instanceof Error ? error.message : '报表加载失败'
    disposeCharts()
  } finally {
    if (run === generation) loading.value = false
  }
}

function renderCharts() {
  if (!report.value) return
  // 趋势图
  if (trendRef.value) {
    trendChart ??= echarts.init(trendRef.value)
    const trend = report.value.bookingTrend || []
    trendChart.setOption(withAdminChartTheme({
      tooltip: { trigger: 'axis' },
      legend: { data: ['有效预约数', '预约合同金额'], right: 0, top: 0 },
      grid: { left: 48, right: 56, top: 36, bottom: 32 },
      xAxis: { type: 'category', data: trend.map((t) => t.date), axisLine: { lineStyle: { color: '#E8E0D8' } } },
      yAxis: [
        { type: 'value', name: '有效预约数', splitLine: { lineStyle: { color: '#F0E9E1' } } },
        { type: 'value', name: '预约合同金额', position: 'right', splitLine: { show: false } }
      ],
      series: [
        { name: '有效预约数', type: 'bar', data: trend.map((t) => t.bookings), itemStyle: { color: '#C45A3C', borderRadius: [4, 4, 0, 0] } },
        { name: '预约合同金额', type: 'line', yAxisIndex: 1, smooth: true, data: trend.map((t) => t.contractCents / 100), itemStyle: { color: '#C8A96E' }, lineStyle: { width: 2 } }
      ]
    }))
  }
  // 服务分布
  if (pieRef.value) {
    pieChart ??= echarts.init(pieRef.value)
    const dist = report.value.serviceDistribution || []
    pieChart.setOption(withAdminChartTheme({
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
    }))
  }
  // 法师排行
  if (barRef.value) {
    barChart ??= echarts.init(barRef.value)
    const rank = (report.value.masterRanking || []).slice().reverse()
    barChart.setOption(withAdminChartTheme({
      tooltip: { trigger: 'axis' },
      grid: { left: 80, right: 24, top: 16, bottom: 24 },
      xAxis: { type: 'value', splitLine: { lineStyle: { color: '#F0E9E1' } } },
      yAxis: { type: 'category', data: rank.map((m) => m.masterName), axisLine: { lineStyle: { color: '#E8E0D8' } } },
      series: [
        {
          name: '法师执行费合同金额',
          type: 'bar',
          data: rank.map((m) => m.masterCents / 100),
          itemStyle: { color: '#C8A96E', borderRadius: [0, 4, 4, 0] },
          label: { show: true, position: 'right', formatter: (p: any) => formatMoney(p.value), color: '#6A5A4A', fontSize: 'var(--type-size-micro)' }
        }
      ]
    }))
  }
}

function exportReport() {
  if (!report.value) return
  const r = report.value
  downloadCSV('寺院预约统计.csv', [
    ['寺院', auth.templeName], ['口径', '已支付且未取消预约的合同金额，非用户实付或银行到账'],
    ['开始日期', appliedRange.value[0] || '全部'], ['结束日期', appliedRange.value[1] || '全部'],
    ['预约数', r.revenueStats.bookingCount], ['预约合同总额（元）', (r.revenueStats.contractCents / 100).toFixed(2)],
    ['寺院服务费与随喜（元）', (r.revenueStats.templeCents / 100).toFixed(2)],
    ['法师执行费（元）', (r.revenueStats.masterCents / 100).toFixed(2)],
    [], ['创建日期', '有效预约数', '合同金额（元）'],
    ...r.bookingTrend.map(x => [x.date, x.bookings, (x.contractCents / 100).toFixed(2)])
  ])
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

watch(tab, async () => { disposeCharts(); await nextTick(); if(tab.value==='bookings') renderCharts() })

onMounted(() => {
  stopChartAppearance = watchAdminChartAppearance(refreshChartAppearance)
  load()
  window.addEventListener('resize', onResize)
})
onBeforeUnmount(() => {
  generation++
  stopChartAppearance?.()
  window.removeEventListener('resize', onResize)
  disposeCharts()
})

let stopChartAppearance: (() => void) | undefined

function refreshChartAppearance() {
  for (const chart of [trendChart, pieChart, barChart]) {
    if (chart && !chart.isDisposed()) chart.setOption(withAdminChartTheme(chart.getOption()))
  }
}
</script>

<template>
  <div class="df-page" v-loading="loading">
    <PageHeader :title="$t('经营统计')" :subtitle="$t('预约合同与寺院结算分别核对')">
      <el-button v-if="tab==='bookings'" :disabled="!report || loading" @click="exportReport">{{ $t('导出当前统计') }}</el-button>
    </PageHeader>
    <el-tabs v-model="tab"><el-tab-pane :label="$t('预约合同')" name="bookings"/><el-tab-pane :label="$t('寺院结算')" name="settlements"/></el-tabs>
    <SettlementReport v-if="tab==='settlements'"/>
    <template v-else>
    <el-alert :closable="false" type="info" :title="$t('按预约创建日期统计已支付且未取消的预约合同，含演示订单；寺院金额包含寺院服务费和随喜，法师执行费单列。优惠后的用户实付、平台补贴和银行到账需分别核对。')"/>
    <div class="report-filters">
      <el-date-picker
        v-model="dateRange"
        type="daterange"
        value-format="YYYY-MM-DD"
        range-separator="至"
        start-placeholder="开始日期"
        end-placeholder="结束日期"
        style="width: 280px"
      />
      <el-button :icon="Refresh" type="primary" @click="load">{{ $t("查询") }}</el-button>
    </div>

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy"><div class="ax-page-feedback__title">{{ $t("寺院报表加载失败") }}</div><div class="ax-page-feedback__description">{{ $t(loadError) }}{{ $t("。页面不会用 0 代替缺失经营数据。") }}</div></div>
      <el-button :loading="loading" @click="load">{{ $t("重新加载") }}</el-button>
    </div>

    <div class="stat-grid" v-if="report">
      <StatCard :title="$t('预约合同总额')" :value="formatMoney(report.revenueStats.contractCents / 100)" :icon="Wallet" tone="accent" />
      <StatCard :title="$t('有效预约数')" :value="report.revenueStats.bookingCount" :icon="Calendar" tone="brand" :suffix='$t("单")' />
      <StatCard :title="$t('寺院服务费与随喜')" :value="formatMoney(report.revenueStats.templeCents / 100)" :icon="DataAnalysis" tone="success" />
      <StatCard :title="$t('法师执行费')" :value="formatMoney(report.revenueStats.masterCents / 100)" :icon="Wallet" />
      <StatCard :title='$t("已完成数")'  :value="report.revenueStats.completedCount" :icon="CircleCheck" tone="warning" :suffix='$t("单")' />
    </div>

    <div v-if="report" class="desktop-report-charts">
    <div class="df-card chart-card big-chart">
      <div class="chart-title">{{ $t("预约合同趋势") }}</div>
      <div ref="trendRef" class="chart-box"></div>
    </div>

    <div class="chart-grid">
      <div class="df-card chart-card">
        <div class="chart-title">{{ $t("服务分布") }}</div>
        <div ref="pieRef" class="chart-box small"></div>
      </div>
      <div class="df-card chart-card">
        <div class="chart-title">{{ $t("法师执行费合同金额") }}</div>
        <div ref="barRef" class="chart-box small"></div>
      </div>
    </div>
    </div>

    <div v-if="report" class="df-card mobile-report-summary">
      <div class="chart-title">{{ $t("经营摘要") }}</div>
      <div class="summary-list">
        <div><span>{{ $t("趋势数据点") }}</span><b>{{ $t(report.bookingTrend.length) }}{{ $t(" 个") }}</b></div>
        <div><span>{{ $t("服务分类") }}</span><b>{{ $t(report.serviceDistribution.length) }}{{ $t(" 类") }}</b></div>
        <div><span>{{ $t("法师排行") }}</span><b>{{ $t(report.masterRanking.length) }}{{ $t(" 位") }}</b></div>
      </div>
    </div>
    <div v-else-if="!loading && !loadError" class="df-card report-empty">{{ $t("当前范围暂无可展示报表") }}</div>
    </template>
  </div>
</template>

<style scoped>
.report-filters{display:flex;gap:12px;flex-wrap:wrap;margin:20px 0}
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
  font-family: var(--font-serif);
  font-size: var(--type-size-control);
  font-weight: var(--type-weight-semibold);
  color: var(--admin-text);
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
