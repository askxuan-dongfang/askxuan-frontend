<template>
  <div class="dfx-page">
    <PageHeader title="寺院结算" subtitle="寺院结算单查询与确认">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.status" placeholder="结算状态" clearable style="width: 150px" @change="onSearch">
        <el-option label="待确认" value="pending" />
        <el-option label="已确认" value="confirmed" />
        <el-option label="已付款" value="paid" />
      </el-select>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="结算单号" prop="settlementNo" width="180" />
        <el-table-column label="寺院" min-width="160">
          <template #default="{ row }">
            <div>{{ row.targetName }}</div>
            <div class="muted">{{ row.targetId }}</div>
          </template>
        </el-table-column>
        <el-table-column label="结算周期" width="200">
          <template #default="{ row }">{{ row.periodStart }} ~ {{ row.periodEnd }}</template>
        </el-table-column>
        <el-table-column label="订单数" prop="orderCount" width="90" align="center" />
        <el-table-column label="总金额" width="130" align="right">
          <template #default="{ row }">{{ formatMoney(row.totalAmount) }}</template>
        </el-table-column>
        <el-table-column label="抽成比例" width="100" align="center">
          <template #default="{ row }">{{ formatPercent(row.commissionRate) }}</template>
        </el-table-column>
        <el-table-column label="抽成金额" width="130" align="right">
          <template #default="{ row }">{{ formatMoney(row.commissionAmount) }}</template>
        </el-table-column>
        <el-table-column label="应结金额" width="140" align="right">
          <template #default="{ row }"><span class="amount">{{ formatMoney(row.settleAmount) }}</span></template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button v-if="row.status === 'pending'" link type="success" :loading="row._saving" @click="confirm(row)">确认结算</el-button>
            <span v-else class="muted">-</span>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getSettlements, confirmSettlement } from '@/api/finance'
import { formatMoney, formatPercent } from '@/utils/format'
import type { Settlement } from '@/types'

interface Row extends Settlement {
  _saving?: boolean
}

const loading = ref(false)
const list = ref<Row[]>([])
const total = ref(0)
const query = reactive({ status: '', settleType: 'temple', page: 1, size: 20 })

async function loadData() {
  loading.value = true
  try {
    const res = await getSettlements(query)
    list.value = (res.list || []).map((s) => ({ ...s }))
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}

function onSearch() {
  query.page = 1
  loadData()
}

async function confirm(row: Row) {
  await ElMessageBox.confirm(`确认结算单「${row.settlementNo}」，应结金额 ${formatMoney(row.settleAmount)}？`, '确认结算', { type: 'warning' })
  row._saving = true
  try {
    await confirmSettlement(row.id)
    ElMessage.success('结算单已确认')
    loadData()
  } finally {
    row._saving = false
  }
}

onMounted(loadData)
</script>

<style scoped>
.filter-bar {
  display: flex;
  gap: 12px;
  padding: 16px;
  margin-bottom: 16px;
}
.table-wrap {
  padding: 16px;
}
.amount {
  color: var(--color-accent);
  font-weight: 700;
}
.muted {
  color: var(--color-text-tertiary);
  font-size: 12px;
}
</style>
