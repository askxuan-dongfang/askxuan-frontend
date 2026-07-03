<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Calendar, Bell, Wallet, UserFilled, Loading, ArrowRight } from '@element-plus/icons-vue'
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
const recentBookings = ref<Booking[]>([])
const pendingBookings = ref<Booking[]>([])
const pendingBlessings = ref<BlessingTask[]>([])
const report = ref<TempleReportResp | null>(null)
const pendingCount = ref(0)
const masterCount = ref(0)

async function loadAll() {
  loading.value = true
  const templeId = auth.templeId
  await Promise.allSettled([
    listBookings({ templeId, page: 1, size: 6 }).then((r) => (recentBookings.value = r.list || [])),
    listBookings({ templeId, status: 'pending', page: 1, size: 6 }).then(
      (r) => {
        pendingBookings.value = r.list || []
        pendingCount.value = r.total || 0
      }
    ),
    listMasters({ templeId, page: 1, size: 1 }).then((r) => (masterCount.value = r.total || 0)),
    listBlessingTasks({ status: 'pending', page: 1, size: 5 }).then(
      (r) => (pendingBlessings.value = r.list || [])
    ),
    getTempleReport().then((r) => (report.value = r))
  ])
  loading.value = false
}

onMounted(loadAll)

function goBooking(id: string) {
  router.push(`/bookings/${id}`)
}
</script>

<template>
  <div class="df-page">
    <PageHeader title="工作台" subtitle="欢迎回来，愿法务兴隆、寺运昌隆">
      <el-button :icon="Loading" @click="loadAll">刷新</el-button>
    </PageHeader>

    <!-- 统计卡片 -->
    <div class="stat-grid">
      <StatCard title="待确认预约" :value="pendingCount" :icon="Bell" tone="warning" suffix="单" />
      <StatCard
        title="累计预约"
        :value="report?.revenueStats?.bookingCount ?? '-'"
        :icon="Calendar"
        tone="brand"
        suffix="单"
      />
      <StatCard
        title="累计功德金"
        :value="report ? formatMoney(report.revenueStats.totalRevenue) : '-'"
        :icon="Wallet"
        tone="accent"
      />
      <StatCard title="在册法师" :value="masterCount" :icon="UserFilled" tone="success" suffix="位" />
    </div>

    <div class="dash-grid">
      <!-- 最近预约 -->
      <div class="df-card dash-card">
        <div class="card-head">
          <span class="card-title">最近预约</span>
          <el-button link type="primary" @click="router.push('/bookings')">查看全部</el-button>
        </div>
        <el-table v-loading="loading" :data="recentBookings" size="small" :show-header="true">
          <el-table-column prop="id" label="预约号" width="150" />
          <el-table-column prop="serviceName" label="服务" min-width="110" show-overflow-tooltip />
          <el-table-column prop="masterName" label="法师" width="90" />
          <el-table-column prop="bookingDate" label="日期" width="110" />
          <el-table-column label="状态" width="90">
            <template #default="{ row }"><StatusTag :status="row.status" kind="booking" /></template>
          </el-table-column>
          <el-table-column label="操作" width="70">
            <template #default="{ row }">
              <el-button link type="primary" size="small" @click="goBooking(row.id)">详情</el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>

      <!-- 待办 -->
      <div class="df-card dash-card">
        <div class="card-head">
          <span class="card-title">待办事项</span>
          <el-tag type="warning" round>{{ pendingCount }}</el-tag>
        </div>
        <div class="todo-section">
          <div class="todo-sub">待确认预约</div>
          <div v-if="pendingBookings.length === 0" class="todo-empty">暂无待确认预约</div>
          <div v-for="b in pendingBookings" :key="b.id" class="todo-item" @click="goBooking(b.id)">
            <div class="todo-main">
              <div class="todo-no">{{ b.serviceName }}</div>
              <div class="todo-meta">{{ b.masterName }} · {{ b.bookingDate }} {{ b.timeSlot }}</div>
            </div>
            <el-icon class="todo-arrow"><ArrowRight /></el-icon>
          </div>
        </div>
        <div class="todo-section" v-if="pendingBlessings.length">
          <div class="todo-sub">待分配加持任务</div>
          <div v-for="t in pendingBlessings" :key="t.id" class="todo-item">
            <div class="todo-main">
              <div class="todo-no">{{ t.taskNo }}</div>
              <div class="todo-meta">{{ blessingStatusText(t.status) }} · {{ formatDate(t.createTime) }}</div>
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
  font-family: 'Noto Serif SC', serif;
  font-size: 16px;
  font-weight: 600;
  color: #2a1e1a;
}
.todo-section {
  margin-bottom: 16px;
}
.todo-sub {
  font-size: 12px;
  color: #8a7a6a;
  margin-bottom: 8px;
  padding-left: 2px;
}
.todo-empty {
  font-size: 13px;
  color: #b0a090;
  padding: 12px 0;
  text-align: center;
  background: #faf6f0;
  border-radius: 8px;
}
.todo-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.15s;
}
.todo-item:hover {
  background: #faf6f0;
}
.todo-no {
  font-size: 14px;
  color: #2a1e1a;
  font-weight: 500;
}
.todo-meta {
  font-size: 12px;
  color: #8a7a6a;
  margin-top: 2px;
}
.todo-arrow {
  color: #c8a96e;
}
</style>
