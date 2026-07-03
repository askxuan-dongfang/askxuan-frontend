<template>
  <div class="dfx-page">
    <PageHeader title="对账中心" subtitle="提现审核 / 打款处理 / 对账报表">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card table-wrap">
      <el-tabs v-model="activeTab" @tab-change="loadData">
        <el-tab-pane label="提现审核" name="withdrawal">
          <div class="filter-bar">
            <el-select v-model="wQuery.applicantType" placeholder="申请方" clearable style="width: 140px" @change="onWSearch">
              <el-option label="寺院" value="temple" />
              <el-option label="法师" value="master" />
              <el-option label="商城" value="shop" />
            </el-select>
            <el-select v-model="wQuery.status" placeholder="状态" clearable style="width: 150px" @change="onWSearch">
              <el-option label="待审核" value="pending" />
              <el-option label="已通过" value="approved" />
              <el-option label="处理中" value="processing" />
              <el-option label="成功" value="success" />
              <el-option label="失败" value="failed" />
              <el-option label="已驳回" value="rejected" />
            </el-select>
          </div>
          <DataTable :data="wList" :loading="loading" :total="wTotal" v-model:page="wQuery.page" v-model:size="wQuery.size" @change="loadWithdrawals">
            <el-table-column label="提现单号" prop="withdrawalNo" width="180" />
            <el-table-column label="申请方" width="120">
              <template #default="{ row }">{{ applicantText(row.applicantType) }} · {{ row.applicantId }}</template>
            </el-table-column>
            <el-table-column label="金额" width="130" align="right">
              <template #default="{ row }"><span class="amount">{{ formatMoney(row.amount) }}</span></template>
            </el-table-column>
            <el-table-column label="收款账户" width="180">
              <template #default="{ row }">{{ maskBankCard(row.bankCard) }}</template>
            </el-table-column>
            <el-table-column label="状态" width="110">
              <template #default="{ row }"><StatusTag :status="row.status" /></template>
            </el-table-column>
            <el-table-column label="申请时间" width="170">
              <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
            </el-table-column>
            <el-table-column label="操作" width="180" fixed="right">
              <template #default="{ row }">
                <template v-if="row.status === 'pending'">
                  <el-button link type="success" @click="auditW(row, 'approve')">通过</el-button>
                  <el-button link type="danger" @click="auditW(row, 'reject')">驳回</el-button>
                </template>
                <el-button v-else-if="row.status === 'approved'" link type="primary" @click="processW(row)">打款</el-button>
                <span v-else class="muted">-</span>
              </template>
            </el-table-column>
          </DataTable>
        </el-tab-pane>

        <el-tab-pane label="对账报表" name="report">
          <div class="filter-bar">
            <el-date-picker v-model="dateRange" type="daterange" range-separator="至" start-placeholder="开始日期" end-placeholder="结束日期" value-format="YYYY-MM-DD" style="width: 320px" />
            <el-button type="primary" :icon="Search" @click="loadReport">生成报表</el-button>
          </div>
          <div v-if="report" class="report-cards">
            <StatCard label="总收入" :value="report.totalIncome" icon="Money" icon-color="#C8A96E" prefix="¥" />
            <StatCard label="总结算" :value="report.totalSettlement" icon="Wallet" icon-color="#C45A3C" prefix="¥" />
            <StatCard label="总提现" :value="report.totalWithdrawal" icon="CreditCard" icon-color="#B5453A" prefix="¥" />
            <StatCard label="订单数" :value="report.orderCount" icon="List" icon-color="#5B8C5A" suffix=" 单" />
          </div>
          <el-empty v-else description="请选择日期范围生成对账报表" />
        </el-tab-pane>
      </el-tabs>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Refresh, Search } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import StatCard from '@/components/StatCard.vue'
import { getWithdrawals, auditWithdrawal, processWithdrawal, getFinanceReports } from '@/api/finance'
import { formatDate, formatMoney, maskBankCard } from '@/utils/format'
import type { Withdrawal, FinanceReport } from '@/types'

const activeTab = ref('withdrawal')
const loading = ref(false)

const wQuery = reactive({ applicantType: '', status: '', page: 1, size: 20 })
const wList = ref<Withdrawal[]>([])
const wTotal = ref(0)

const dateRange = ref<[string, string] | null>(null)
const report = ref<FinanceReport | null>(null)

function applicantText(t: string) {
  return { temple: '寺院', master: '法师', shop: '商城' }[t] || t
}

async function loadWithdrawals() {
  loading.value = true
  try {
    const res = await getWithdrawals(wQuery)
    wList.value = res.list || []
    wTotal.value = res.total || 0
  } finally {
    loading.value = false
  }
}

function onWSearch() {
  wQuery.page = 1
  loadWithdrawals()
}

async function auditW(row: Withdrawal, action: 'approve' | 'reject') {
  const remark = action === 'reject' ? await ElMessageBox.prompt('请输入驳回原因', '驳回提现', { type: 'warning' }).then((r) => r.value).catch(() => null) : ''
  if (action === 'reject' && remark === null) return
  await auditWithdrawal(row.id, { action, remark: remark || undefined })
  ElMessage.success('操作成功')
  loadWithdrawals()
}

async function processW(row: Withdrawal) {
  await ElMessageBox.confirm(`确认对提现单「${row.withdrawalNo}」执行打款？金额 ${formatMoney(row.amount)}`, '打款确认', { type: 'warning' })
  await processWithdrawal(row.id)
  ElMessage.success('打款处理已提交')
  loadWithdrawals()
}

async function loadReport() {
  if (!dateRange.value) {
    ElMessage.warning('请选择日期范围')
    return
  }
  loading.value = true
  try {
    report.value = await getFinanceReports({ startTime: dateRange.value[0], endTime: dateRange.value[1] })
  } finally {
    loading.value = false
  }
}

async function loadData() {
  if (activeTab.value === 'withdrawal') loadWithdrawals()
  else if (report.value) loadReport()
}

onMounted(loadWithdrawals)
</script>

<style scoped>
.table-wrap {
  padding: 16px;
}
.filter-bar {
  display: flex;
  gap: 12px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}
.amount {
  color: var(--color-accent);
  font-weight: 700;
}
.muted {
  color: var(--color-text-tertiary);
  font-size: 12px;
}
.report-cards {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  margin-top: 8px;
}
</style>
