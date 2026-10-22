<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Calendar, Bell, Wallet, UserFilled, Loading, ArrowRight } from '@element-plus/icons-vue'
import JourneySummary from '@/components/JourneySummary.vue'
import PageHeader from '@/components/PageHeader.vue'
import StatCard from '@/components/StatCard.vue'
import StatusTag from '@/components/StatusTag.vue'
import { useAuthStore } from '@/stores/auth'
import { listBookings } from '@/api/booking'
import { listMasters } from '@/api/master'
import { listBlessingTasks } from '@/api/blessing'
import { getTempleReport } from '@/api/report'
import { formatMoney, formatDate, blessingStatusText } from '@/utils/format'
import type { Booking, BlessingTask, TempleReportResp } from '@/types'

const router = useRouter()
const auth = useAuthStore()

const loading = ref(false)
const loadIssueCount = ref(0)
const failedModules = ref<string[]>([])
const recentBookings = ref<Booking[]>([])
const pendingBookings = ref<Booking[]>([])
const pendingBlessings = ref<BlessingTask[]>([])
const report = ref<TempleReportResp | null>(null)
const pendingCount = ref<number | string>('—')
const pendingBlessingCount = ref<number | string>('—')
const masterCount = ref<number | string>('—')

async function loadAll() {
  loading.value = true
  loadIssueCount.value = 0
  failedModules.value = []
  recentBookings.value = []
  pendingBookings.value = []
  pendingBlessings.value = []
  report.value = null
  pendingCount.value = '—'
  pendingBlessingCount.value = '—'
  masterCount.value = '—'
  const templeId = auth.templeId
  const permitted = (permission: string, action: () => Promise<unknown>) => auth.can(permission) ? action() : Promise.resolve()
  const results = await Promise.allSettled([
    permitted('temple.bookings.read', () => listBookings({ templeId, page: 1, size: 6 }).then((r) => (recentBookings.value = r.list || []))),
    permitted('temple.bookings.read', () => listBookings({ templeId, status: 'pending', page: 1, size: 6 }).then(
      (r) => {
        pendingBookings.value = r.list || []
        pendingCount.value = r.total || 0
      }
    )),
    permitted('temple.people.read', () => listMasters({ templeId, page: 1, size: 1 }).then((r) => (masterCount.value = r.total || 0))),
    permitted('temple.blessings.read', () => listBlessingTasks({ status: 'dispatched', page: 1, size: 5 }).then(
      (r) => {
        pendingBlessings.value = r.list || []
        pendingBlessingCount.value = r.total || 0
      }
    )),
    permitted('temple.finance.read', () => getTempleReport({ templeId }).then((r) => {
      if (
        !r?.revenueStats ||
        !Number.isFinite(r.revenueStats.bookingCount) ||
        !Number.isSafeInteger(r.revenueStats.templeCents) ||
        !Array.isArray(r.bookingTrend) ||
        !Array.isArray(r.serviceDistribution) ||
        !Array.isArray(r.masterRanking)
      ) {
        throw new Error('经营报表返回的数据结构不完整')
      }
      report.value = r
    }))
  ])
  const names = ['最近预约', '待确认预约', '在册法师', '待分配加持', '经营报表']
  failedModules.value = results.flatMap((result, index) => result.status === 'rejected' ? [names[index]] : [])
  loadIssueCount.value = failedModules.value.length
  loading.value = false
}

onMounted(loadAll)

function goBooking(id: string) {
  router.push(`/bookings/${id}`)
}
</script>

<template>
  <div class="df-page">
    <PageHeader :title='$t("工作台")' :subtitle='$t("欢迎回来，愿法务兴隆、寺运昌隆")'>
      <el-button :icon="Loading" :loading="loading" @click="loadAll">{{ $t("刷新") }}</el-button>
    </PageHeader>
    <JourneySummary v-if="auth.can('temple.bookings.read')"/>

    <div v-if="loadIssueCount" class="ax-page-feedback" :class="{ 'is-error': loadIssueCount === 5 }" role="status">
      <div class="ax-page-feedback__copy">
        <div class="ax-page-feedback__title">{{ $t((loadIssueCount === 5 ? $t('寺院工作台暂时无法加载') : $t('部分工作台数据加载失败'))) }}</div>
        <div class="ax-page-feedback__description">{{ $t("失败模块：") }}{{ $t(failedModules.join('、')) }}{{ $t("。失败模块保留为“—”，不会按真实 0 值展示。") }}</div>
      </div>
      <el-button :loading="loading" @click="loadAll">{{ $t("重新加载") }}</el-button>
    </div>

    <div class="ax-task-grid">
      <router-link class="ax-task-card" v-if="auth.can('temple.bookings.read')" to="/bookings?status=pending">
        <span class="ax-task-card__icon"><el-icon><Bell /></el-icon></span>
        <span class="ax-task-card__copy"><span class="ax-task-card__label">{{ $t("待确认预约") }}</span><span class="ax-task-card__meta">{{ $t("进入已筛选任务列表") }}</span></span>
        <strong class="ax-task-card__value">{{ $t(pendingCount) }}</strong>
      </router-link>
      <router-link class="ax-task-card" v-if="auth.can('temple.blessings.read')" to="/blessing-tasks?status=dispatched">
        <span class="ax-task-card__icon"><el-icon><Calendar /></el-icon></span>
        <span class="ax-task-card__copy"><span class="ax-task-card__label">{{ $t("待分配加持") }}</span><span class="ax-task-card__meta">{{ $t("优先分配执行法师") }}</span></span>
        <strong class="ax-task-card__value">{{ $t(pendingBlessingCount) }}</strong>
      </router-link>
      <router-link class="ax-task-card" v-if="auth.can('temple.reviews.read')" to="/reviews">
        <span class="ax-task-card__icon"><el-icon><ArrowRight /></el-icon></span>
        <span class="ax-task-card__copy"><span class="ax-task-card__label">{{ $t("评价回复") }}</span><span class="ax-task-card__meta">{{ $t("查看待回复与历史评价") }}</span></span>
        <strong class="ax-task-card__value">{{ $t("查看") }}</strong>
      </router-link>
      <router-link class="ax-task-card" v-if="auth.can('temple.finance.read')" to="/report">
        <span class="ax-task-card__icon"><el-icon><Wallet /></el-icon></span>
        <span class="ax-task-card__copy"><span class="ax-task-card__label">{{ $t("经营报表") }}</span><span class="ax-task-card__meta">{{ $t("预约合同与结算分开查看") }}</span></span>
        <strong class="ax-task-card__value">{{ $t("查看") }}</strong>
      </router-link>
    </div>

    <!-- 统计卡片 -->
    <div class="stat-grid">
      <StatCard v-if="auth.can('temple.bookings.read')" :title='$t("待确认预约")' :value="pendingCount" :icon="Bell" tone="warning" :suffix='$t("单")' />
      <StatCard v-if="auth.can('temple.finance.read')"
        :title='$t("累计预约")'
        :value="report?.revenueStats?.bookingCount ?? '—'"
        :icon="Calendar"
        tone="brand"
        :suffix="report?.revenueStats ? '单' : ''"
      />
      <StatCard v-if="auth.can('temple.finance.read')"
        :title='$t("寺院服务费与随喜")'
        :value="report?.revenueStats ? formatMoney(report.revenueStats.templeCents / 100) : '—'"
        :icon="Wallet"
        tone="accent"
      />
      <StatCard v-if="auth.can('temple.people.read')" :title='$t("在册法师")' :value="masterCount" :icon="UserFilled" tone="success" :suffix='$t("位")' />
    </div>

    <div class="dash-grid" v-if="auth.can('temple.bookings.read')">
      <!-- 最近预约 -->
      <div class="df-card dash-card">
        <div class="card-head">
          <span class="card-title">{{ $t("最近预约") }}</span>
          <el-button link type="primary" @click="router.push('/bookings')">{{ $t("查看全部") }}</el-button>
        </div>
        <el-table class="desktop-table" v-loading="loading" :data="recentBookings" size="small" :show-header="true">
          <el-table-column prop="id" :label='$t("预约号")' width="150" />
          <el-table-column prop="serviceName" :label='$t("服务")' min-width="110" show-overflow-tooltip />
          <el-table-column prop="masterName" :label='$t("法师")' width="90" />
          <el-table-column prop="bookingDate" :label='$t("日期")' width="110" />
          <el-table-column :label='$t("状态")' width="90">
            <template #default="{ row }"><StatusTag :status="row.status" kind="booking" /></template>
          </el-table-column>
          <el-table-column :label='$t("操作")' width="70">
            <template #default="{ row }">
              <el-button link type="primary" size="small" @click="goBooking(row.id)">{{ $t("详情") }}</el-button>
            </template>
          </el-table-column>
        </el-table>
        <div class="mobile-task-list" :aria-busy="loading">
          <div v-if="failedModules.includes('最近预约')" class="mobile-task-empty" role="alert">{{ $t("最近预约加载失败，请重新加载") }}</div>
          <div v-else-if="loading" class="mobile-task-empty" role="status">{{ $t("正在加载最近预约…") }}</div>
          <article v-for="booking in recentBookings" v-else-if="recentBookings.length" :key="booking.id" class="mobile-task-card" @click="goBooking(booking.id)">
            <div class="mobile-task-card__head"><strong>{{ $t((booking.serviceName || booking.id)) }}</strong><StatusTag :status="booking.status" kind="booking" /></div>
            <div class="mobile-task-card__meta">{{ booking.masterName || $t('暂未分配法师') }} · {{ $t(booking.bookingDate) }} {{ $t(booking.timeSlot) }}</div>
            <div class="mobile-task-card__foot"><span>{{ $t("预约号 ") }}{{ $t(booking.id) }}</span><b>{{ $t("查看详情") }}</b></div>
          </article>
          <div v-else class="mobile-task-empty">{{ $t("暂无最近预约") }}</div>
        </div>
      </div>

      <!-- 待办 -->
      <div class="df-card dash-card">
        <div class="card-head">
          <span class="card-title">{{ $t("待办事项") }}</span>
          <el-tag type="warning" round>{{ $t(pendingCount) }}</el-tag>
        </div>
        <div class="todo-section">
          <div class="todo-sub">{{ $t("待确认预约") }}</div>
          <div v-if="failedModules.includes('待确认预约')" class="todo-empty">{{ $t("待确认预约加载失败") }}</div>
          <div v-else-if="pendingBookings.length === 0" class="todo-empty">{{ $t("暂无待确认预约") }}</div>
          <div v-for="b in pendingBookings" :key="b.id" class="todo-item" @click="goBooking(b.id)">
            <div class="todo-main">
              <div class="todo-no">{{ $t(b.serviceName) }}</div>
              <div class="todo-meta">{{ b.masterName }} · {{ $t(b.bookingDate) }} {{ $t(b.timeSlot) }}</div>
            </div>
            <el-icon class="todo-arrow"><ArrowRight /></el-icon>
          </div>
        </div>
        <div class="todo-section" v-if="pendingBlessings.length">
          <div class="todo-sub">{{ $t("待分配加持任务") }}</div>
          <div v-for="t in pendingBlessings" :key="t.id" class="todo-item">
            <div class="todo-main">
              <div class="todo-no">{{ $t(t.taskNo) }}</div>
              <div class="todo-meta">{{ $t(blessingStatusText(t.status)) }} · {{ $t(formatDate(t.createTime)) }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.stat-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  margin-bottom: 20px;
}
.dash-grid {
  display: grid;
  grid-template-columns: 1.6fr 1fr;
  gap: 16px;
}
.dash-card {
  padding: 18px 20px;
}
.card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
}
.card-title {
  font-family: var(--font-serif);
  font-size: var(--type-size-reading);
  font-weight: var(--type-weight-semibold);
  color: var(--admin-text);
}
.todo-section {
  margin-bottom: 16px;
}
.todo-sub {
  font-size: var(--type-size-caption);
  color: var(--admin-text-secondary);
  margin-bottom: 8px;
  padding-left: 2px;
}
.todo-empty {
  font-size: var(--type-size-label);
  color: var(--admin-text-secondary);
  padding: 12px 0;
  text-align: center;
  background: var(--admin-surface-muted);
  border-radius: 8px;
}
.todo-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border-radius: 8px;
  cursor: pointer;
  transition: background-color var(--admin-transition);
}
.todo-item:hover {
  background: var(--admin-surface-muted);
}
.todo-no {
  font-size: var(--type-size-body);
  color: var(--admin-text);
  font-weight: var(--type-weight-medium);
}
.todo-meta {
  font-size: var(--type-size-caption);
  color: var(--admin-text-secondary);
  margin-top: 2px;
}
.todo-arrow {
  color: var(--admin-accent);
}

@media (max-width: 991px) {
  .dash-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 767px) {
  .dash-card {
    padding: 14px;
  }
}
</style>
