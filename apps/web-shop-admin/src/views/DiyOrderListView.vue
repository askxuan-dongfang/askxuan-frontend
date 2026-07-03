<script setup lang="ts">
// DIY 订单列表
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import { diyOrderApi, type DiyOrderListParams } from '@/api/diyOrder'
import { formatMoney } from '@/utils/format'
import type { DiyOrder } from '@/types'

const router = useRouter()
const loading = ref(false)
const list = ref<DiyOrder[]>([])
const total = ref(0)

const query = reactive<DiyOrderListParams>({
  status: '',
  page: 1,
  size: 20
})

const statusOptions = [
  { value: 'pending_payment', label: '待付款' },
  { value: 'paid', label: '已付款' },
  { value: 'in_review', label: '待审核' },
  { value: 'making', label: '制作中' },
  { value: 'shipped', label: '已发货' },
  { value: 'completed', label: '已完成' },
  { value: 'cancelled', label: '已取消' }
]

async function loadList() {
  loading.value = true
  try {
    const res = await diyOrderApi.list(query)
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
    <PageHeader title="DIY 订单" subtitle="管理手串 DIY 订单、审核与发货" />

    <div class="df-card filter-bar">
      <el-form inline @submit.prevent="handleSearch">
        <el-form-item label="订单状态">
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
      <el-table v-loading="loading" :data="list" style="width: 100%" empty-text="暂无 DIY 订单">
        <el-table-column label="订单号" prop="orderNo" width="200" />
        <el-table-column label="用户 ID" prop="userId" width="160" />
        <el-table-column label="设计 ID" prop="designId" width="100" />
        <el-table-column label="材料费" width="120">
          <template #default="{ row }">{{ formatMoney(row.materialFee) }}</template>
        </el-table-column>
        <el-table-column label="加持费" width="120">
          <template #default="{ row }">{{ formatMoney(row.blessFee) }}</template>
        </el-table-column>
        <el-table-column label="合计" width="130">
          <template #default="{ row }">
            <span class="price">{{ formatMoney(row.totalFee) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" prop="status" width="120" />
        <el-table-column label="下单时间" prop="createTime" width="180" />
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="router.push(`/diy-orders/${row.id}`)">详情</el-button>
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
