<script setup lang="ts">
// 退货列表
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import { orderApi, type ReturnListParams } from '@/api/order'
import { formatMoney, formatDateTime, returnStatusLabel, returnStatusType } from '@/utils/format'
import type { ReturnOrder } from '@/types'

const router = useRouter()
const loading = ref(false)
const list = ref<ReturnOrder[]>([])
const total = ref(0)

const query = reactive<ReturnListParams>({
  status: '',
  page: 1,
  size: 20
})

const statusOptions = [
  { value: 'pending_review', label: '待审核' },
  { value: 'approved', label: '已通过' },
  { value: 'return_shipping', label: '退货运输中' },
  { value: 'return_received', label: '已收货' },
  { value: 'refunding', label: '退款中' },
  { value: 'completed', label: '已完成' },
  { value: 'rejected', label: '已拒绝' }
]

async function loadList() {
  loading.value = true
  try {
    const res = await orderApi.returnList(query)
    list.value = res.list || []
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}

function handleSearch() {
  query.page = 1
  loadList()
}

function handleReset() {
  query.status = ''
  query.page = 1
  loadList()
}

function handlePageChange(p: number) {
  query.page = p
  loadList()
}

function handleSizeChange(s: number) {
  query.size = s
  query.page = 1
  loadList()
}

onMounted(() => {
  loadList()
})
</script>

<template>
  <div class="page-wrap">
    <PageHeader title="退货列表" subtitle="管理商品退货 / 换货申请" />

    <div class="df-card filter-bar">
      <el-form inline @submit.prevent="handleSearch">
        <el-form-item label="退货状态">
          <el-select v-model="query.status" placeholder="全部状态" clearable style="width: 160px">
            <el-option
              v-for="s in statusOptions"
              :key="s.value"
              :label="s.label"
              :value="s.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">查询</el-button>
          <el-button @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>
    </div>

    <div class="df-card">
      <el-table v-loading="loading" :data="list" style="width: 100%" empty-text="暂无退货单">
        <el-table-column label="退货单号" prop="returnNo" width="200" />
        <el-table-column label="原订单 ID" prop="orderId" width="120" />
        <el-table-column label="类型" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.type === 'exchange' ? 'warning' : 'info'">
              {{ row.type === 'exchange' ? '换货' : '退货' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="退款金额" width="130">
          <template #default="{ row }">
            <span class="price">{{ formatMoney(row.refundAmount) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="120">
          <template #default="{ row }">
            <el-tag :type="returnStatusType(row.status)" effect="light" round size="small">
              {{ returnStatusLabel(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="原因" prop="reason" min-width="200" show-overflow-tooltip />
        <el-table-column label="申请时间" width="180">
          <template #default="{ row }">{{ formatDateTime(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="router.push(`/returns/${row.id}`)">详情</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pager">
        <el-pagination
          v-model:current-page="query.page"
          v-model:page-size="query.size"
          :total="total"
          :page-sizes="[10, 20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          background
          @current-change="handlePageChange"
          @size-change="handleSizeChange"
        />
      </div>
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
.pager {
  padding: 16px 24px;
  display: flex;
  justify-content: flex-end;
}
.price {
  color: var(--primary);
  font-weight: 600;
}
</style>
