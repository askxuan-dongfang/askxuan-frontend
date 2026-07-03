<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Refresh, Search, View } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { listBookings } from '@/api/booking'
import { useAuthStore } from '@/stores/auth'
import { formatMoney, formatDate } from '@/utils/format'
import type { Booking } from '@/types'

const router = useRouter()
const auth = useAuthStore()

const loading = ref(false)
const list = ref<Booking[]>([])
const total = ref(0)
const query = reactive({ status: '', page: 1, size: 20 })

const statusOptions = [
  { value: 'pending', label: '待确认' },
  { value: 'confirmed', label: '已确认' },
  { value: 'in_progress', label: '进行中' },
  { value: 'reviewed', label: '已评价' },
  { value: 'cancelled', label: '已取消' }
]

async function load() {
  loading.value = true
  try {
    const r = await listBookings({
      templeId: auth.templeId,
      status: query.status || undefined,
      page: query.page,
      size: query.size
    })
    list.value = r.list || []
    total.value = r.total || 0
  } finally {
    loading.value = false
  }
}

function onSearch() {
  query.page = 1
  load()
}
function onPageChange(p: { page: number; size: number }) {
  query.page = p.page
  query.size = p.size
  load()
}
function goDetail(id: string) {
  router.push(`/bookings/${id}`)
}

onMounted(load)
</script>

<template>
  <div class="df-page">
    <PageHeader title="预约管理" subtitle="查看与处理信众预约">
      <el-button :icon="Refresh" @click="load">刷新</el-button>
    </PageHeader>

    <div class="df-card list-card">
      <div class="filter-bar">
        <el-select v-model="query.status" placeholder="状态筛选" clearable style="width: 160px" @change="onSearch">
          <el-option v-for="s in statusOptions" :key="s.value" :label="s.label" :value="s.value" />
        </el-select>
        <el-button :icon="Search" type="primary" plain @click="onSearch">查询</el-button>
      </div>

      <DataTable
        :data="list"
        :loading="loading"
        :total="total"
        :page="query.page"
        :size="query.size"
        row-key="id"
        @change="onPageChange"
      >
        <el-table-column prop="id" label="预约号" width="150" />
        <el-table-column prop="serviceName" label="服务" min-width="120" show-overflow-tooltip />
        <el-table-column prop="masterName" label="法师" width="100" />
        <el-table-column label="预约时间" width="180">
          <template #default="{ row }">
            <div>{{ row.bookingDate }}</div>
            <div class="muted">{{ row.timeSlot }}</div>
          </template>
        </el-table-column>
        <el-table-column label="功德金" width="110">
          <template #default="{ row }">
            <span class="price">{{ formatMoney(row.meritMoney) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }"><StatusTag :status="row.status" kind="booking" /></template>
        </el-table-column>
        <el-table-column label="提交时间" width="160">
          <template #default="{ row }">{{ formatDate(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="90" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" :icon="View" @click="goDetail(row.id)">详情</el-button>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<style scoped>
.list-card {
  padding: 18px 20px;
}
.filter-bar {
  display: flex;
  gap: 10px;
  margin-bottom: 16px;
}
.muted {
  font-size: 12px;
  color: #8a7a6a;
}
.price {
  color: #c45a3c;
  font-weight: 600;
}
</style>
