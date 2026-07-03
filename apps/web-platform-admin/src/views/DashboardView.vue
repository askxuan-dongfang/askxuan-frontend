<template>
  <div class="dfx-page">
    <PageHeader title="平台总览" subtitle="全平台运营数据实时概览" />

    <!-- 统计卡片 -->
    <div class="dashboard__cards">
      <StatCard label="平台总收入（元）" :value="stats.totalIncome" icon="Money" icon-color="#C8A96E" prefix="¥" />
      <StatCard label="平台抽成（元）" :value="stats.commissionIncome" icon="Coin" icon-color="#D4A843" prefix="¥" />
      <StatCard label="入驻寺院" :value="stats.templeCount" icon="OfficeBuilding" icon-color="#C45A3C" suffix=" 家" />
      <StatCard label="认证法师" :value="stats.masterCount" icon="Avatar" icon-color="#B5453A" suffix=" 位" />
      <StatCard label="注册用户" :value="stats.userCount" icon="User" icon-color="#5B8C5A" suffix=" 人" />
      <StatCard label="待审核数" :value="stats.pendingCount" icon="Bell" icon-color="#D4735A" suffix=" 项" />
    </div>

    <!-- 图表区 -->
    <div class="dashboard__charts">
      <div class="dfx-card chart-card">
        <div class="chart-card__title">收入构成分布</div>
        <div ref="pieRef" class="chart-card__body"></div>
      </div>
      <div class="dfx-card chart-card">
        <div class="chart-card__title">审核队列状态</div>
        <div ref="barRef" class="chart-card__body"></div>
      </div>
    </div>

    <!-- 待办 -->
    <div class="dfx-card dashboard__todo">
      <div class="chart-card__title">运营待办</div>
      <div class="dashboard__todo-grid">
        <router-link v-for="todo in todos" :key="todo.path" :to="todo.path" class="todo-item">
          <el-icon :size="22" :color="todo.color"><component :is="todo.icon" /></el-icon>
          <div class="todo-item__info">
            <div class="todo-item__label">{{ todo.label }}</div>
            <div class="todo-item__count dfx-serif">{{ todo.count }}</div>
          </div>
        </router-link>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts'
import PageHeader from '@/components/PageHeader.vue'
import StatCard from '@/components/StatCard.vue'
import { getFinanceOverview } from '@/api/finance'
import { getAuditStatistics } from '@/api/audit'
import { getTempleList } from '@/api/temple'
import { getMasterList } from '@/api/master'
import { getUserList } from '@/api/user'
import type { FinanceOverview, AuditStatistics } from '@/types'

const pieRef = ref<HTMLElement>()
const barRef = ref<HTMLElement>()
let pieChart: echarts.ECharts | null = null
let barChart: echarts.ECharts | null = null

const stats = reactive({
  totalIncome: 0,
  commissionIncome: 0,
  templeCount: 0,
  masterCount: 0,
  userCount: 0,
  pendingCount: 0
})

const overview = ref<FinanceOverview | null>(null)
const audit = ref<AuditStatistics | null>(null)

const todos = ref([
  { path: '/temple/review', label: '寺院入驻审核', count: 0, icon: 'OfficeBuilding', color: '#C45A3C' },
  { path: '/master/review', label: '法师资质审核', count: 0, icon: 'Avatar', color: '#B5453A' },
  { path: '/audit/comment', label: '评价内容审核', count: 0, icon: 'ChatDotRound', color: '#D4A843' },
  { path: '/audit/report', label: '举报待处理', count: 0, icon: 'Warning', color: '#C45A3C' },
  { path: '/finance/reconcile', label: '提现待审核', count: 0, icon: 'Wallet', color: '#C8A96E' }
])

function renderPie() {
  if (!pieRef.value) return
  pieChart = echarts.init(pieRef.value)
  const o = overview.value
  pieChart.setOption({
    tooltip: { trigger: 'item' },
    legend: { bottom: 0, textStyle: { color: '#C5B097' } },
    series: [
      {
        type: 'pie',
        radius: ['45%', '70%'],
        center: ['50%', '45%'],
        avoidLabelOverlap: false,
        itemStyle: { borderColor: '#2A1E1A', borderWidth: 2 },
        label: { show: false },
        data: [
          { value: o?.templeIncome || 0, name: '寺院结算', itemStyle: { color: '#C45A3C' } },
          { value: o?.masterIncome || 0, name: '法师结算', itemStyle: { color: '#C8A96E' } },
          { value: o?.shopIncome || 0, name: '商城结算', itemStyle: { color: '#5B8C5A' } },
          { value: o?.commissionIncome || 0, name: '平台抽成', itemStyle: { color: '#D4A843' } }
        ]
      }
    ]
  })
}

function renderBar() {
  if (!barRef.value) return
  barChart = echarts.init(barRef.value)
  const a = audit.value
  barChart.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: 50, right: 20, top: 30, bottom: 30 },
    xAxis: { type: 'category', data: ['待审核', '已通过', '已驳回'], axisLabel: { color: '#C5B097' }, axisLine: { lineStyle: { color: 'rgba(200,169,110,0.2)' } } },
    yAxis: { type: 'value', axisLabel: { color: '#C5B097' }, splitLine: { lineStyle: { color: 'rgba(200,169,110,0.08)' } } },
    series: [
      {
        type: 'bar',
        barWidth: 36,
        data: [
          { value: a?.pendingCount || 0, itemStyle: { color: '#D4A843' } },
          { value: a?.approvedCount || 0, itemStyle: { color: '#5B8C5A' } },
          { value: a?.rejectedCount || 0, itemStyle: { color: '#C45A3C' } }
        ]
      }
    ]
  })
}

function onResize() {
  pieChart?.resize()
  barChart?.resize()
}

onMounted(async () => {
  const [finRes, auditRes, templeRes, masterRes, userRes] = await Promise.allSettled([
    getFinanceOverview(),
    getAuditStatistics({}),
    getTempleList({ page: 1, size: 1 }),
    getMasterList({ page: 1, size: 1 }),
    getUserList({ page: 1, size: 1 })
  ])

  if (finRes.status === 'fulfilled') {
    overview.value = finRes.value
    stats.totalIncome = finRes.value.totalIncome
    stats.commissionIncome = finRes.value.commissionIncome
    todos.value[4].count = finRes.value.pendingWithdraw
  }
  if (auditRes.status === 'fulfilled') {
    audit.value = auditRes.value
    stats.pendingCount = auditRes.value.pendingCount
    todos.value[2].count = auditRes.value.pendingCount
  }
  if (templeRes.status === 'fulfilled') stats.templeCount = templeRes.value.total
  if (masterRes.status === 'fulfilled') stats.masterCount = masterRes.value.total
  if (userRes.status === 'fulfilled') stats.userCount = userRes.value.total

  await nextTick()
  renderPie()
  renderBar()
  window.addEventListener('resize', onResize)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize)
  pieChart?.dispose()
  barChart?.dispose()
})
</script>

<style scoped>
.dashboard__cards {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 16px;
  margin-bottom: 20px;
}
.dashboard__charts {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-bottom: 20px;
}
.chart-card {
  padding: 18px 20px;
}
.chart-card__title {
  font-size: 15px;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 12px;
  padding-left: 10px;
  border-left: 3px solid var(--color-accent);
}
.chart-card__body {
  height: 280px;
}
.dashboard__todo-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 14px;
  margin-top: 4px;
}
.todo-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  background: var(--color-bg-tertiary);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  text-decoration: none;
  transition: all 0.2s;
}
.todo-item:hover {
  border-color: var(--color-accent);
  transform: translateY(-2px);
}
.todo-item__label {
  font-size: 12px;
  color: var(--color-text-tertiary);
}
.todo-item__count {
  font-size: 22px;
  font-weight: 700;
  color: var(--color-text-primary);
  margin-top: 4px;
}
</style>
