<script setup lang="ts">
// 商城订单列表
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import { orderApi, type OrderListParams } from '@/api/order'
import { formatMoney, orderStatusLabel, orderStatusType } from '@/utils/format'
import type { ShopOrder } from '@/types'

const router = useRouter()
const loading = ref(false)
const loadError = ref('')
const list = ref<ShopOrder[]>([])
const total = ref(0)

const query = reactive<OrderListParams>({
  status: '',
  page: 1,
  size: 20
})

const statusOptions = [
  { value: 'pending_payment', label: '待付款' },
  { value: 'paid', label: '已付款' },
  { value: 'shipped', label: '已发货' },
  { value: 'completed', label: '已完成' },
  { value: 'cancelled', label: '已取消' },
  { value: 'in_return', label: '退货中' }
]

async function loadList() {
  loading.value = true
  loadError.value = ''
  try {
    const res = await orderApi.list(query)
    list.value = res.list || []
    total.value = res.total || 0
  } catch (error) {
    loadError.value = error instanceof Error ? error.message : '商城订单加载失败'
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
    <PageHeader title="商城订单" subtitle="管理商城商品订单，支持发货操作" />

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

    <div v-if="loadError" class="ax-page-feedback is-error" role="status">
      <div class="ax-page-feedback__copy">
        <div class="ax-page-feedback__title">商城订单加载失败</div>
        <div class="ax-page-feedback__description">{{ loadError }}</div>
      </div>
      <el-button :loading="loading" @click="loadList">重试</el-button>
    </div>

    <div class="df-card">
      <div class="desktop-table"><el-table v-loading="loading" :data="list" style="width: 100%" empty-text="暂无订单">
        <el-table-column label="订单号" prop="orderNo" width="200" />
        <el-table-column label="用户 ID" prop="userId" width="160" />
        <el-table-column label="订单金额" width="130">
          <template #default="{ row }">
            <span class="price">{{ formatMoney(row.payAmount) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <el-tag :type="orderStatusType(row.status)" effect="light" round size="small">
              {{ orderStatusLabel(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="备注" prop="note" min-width="180" show-overflow-tooltip />
        <el-table-column label="下单时间" prop="createTime" width="180" />
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="router.push(`/orders/${row.id}`)">详情</el-button>
          </template>
        </el-table-column>
      </el-table></div>

      <div class="mobile-task-list" aria-label="商城订单列表">
        <button v-for="item in list" :key="item.id" class="mobile-task-card" type="button" @click="router.push(`/orders/${item.id}`)">
          <span class="mobile-task-card__head">
            <strong>{{ item.orderNo }}</strong>
            <el-tag :type="orderStatusType(item.status)" effect="light" round size="small">{{ orderStatusLabel(item.status) }}</el-tag>
          </span>
          <span class="mobile-task-card__meta">用户 {{ item.userId }} · {{ item.createTime }}</span>
          <span class="mobile-task-card__foot"><span>{{ item.note || '无备注' }}</span><b>{{ formatMoney(item.payAmount) }}</b></span>
        </button>
        <div v-if="!loading && !list.length && !loadError" class="mobile-task-empty">当前筛选下暂无商城订单</div>
        <div v-if="total > (query.size || 20)" class="mobile-task-pager">
          <el-button :disabled="(query.page || 1) <= 1" @click="handlePageChange((query.page || 1) - 1)">上一页</el-button>
          <span>第 {{ query.page || 1 }} 页</span>
          <el-button :disabled="(query.page || 1) * (query.size || 20) >= total" @click="handlePageChange((query.page || 1) + 1)">下一页</el-button>
        </div>
      </div>

      <div class="pager desktop-table">
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
@media (max-width: 767px) {
  .filter-bar { padding: 12px; }
}
</style>
