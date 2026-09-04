<template>
  <div class="dfx-page">
    <PageHeader title="法师结算" subtitle="法师结算单与提现记录">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy"><div class="ax-page-feedback__title">{{ activeTab === 'settlement' ? '法师结算单加载失败' : '法师提现记录加载失败' }}</div><div class="ax-page-feedback__description">当前结果不是业务零值，请重新加载。</div></div>
      <el-button :loading="loading" @click="loadData">重新加载</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <el-tabs v-model="activeTab" @tab-change="loadData">
        <el-tab-pane label="结算单" name="settlement">
          <div class="filter-bar">
            <el-select v-model="sQuery.status" placeholder="状态" clearable style="width: 140px" @change="loadData">
              <el-option label="待确认" value="pending" />
              <el-option label="已确认" value="confirmed" />
              <el-option label="已付款" value="paid" />
            </el-select>
          </div>
          <DataTable class="desktop-table" :data="sList" :loading="loading" :total="sTotal" v-model:page="sQuery.page" v-model:size="sQuery.size" @change="loadData">
            <el-table-column label="结算单号" prop="settlementNo" width="180" />
            <el-table-column label="法师" min-width="150">
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
            <el-table-column label="抽成" width="110" align="right">
              <template #default="{ row }">{{ formatMoney(row.commissionAmount) }}</template>
            </el-table-column>
            <el-table-column label="应结" width="130" align="right">
              <template #default="{ row }"><span class="amount">{{ formatMoney(row.settleAmount) }}</span></template>
            </el-table-column>
            <el-table-column label="状态" width="110">
              <template #default="{ row }"><StatusTag :status="row.status" /></template>
            </el-table-column>
            <el-table-column label="操作" width="120" fixed="right">
              <template #default="{ row }">
                <el-button v-if="row.status === 'pending'" link type="success" @click="confirmSettle(row)">确认</el-button>
                <span v-else class="muted">-</span>
              </template>
            </el-table-column>
          </DataTable>
          <MobileTaskList v-model:page="sQuery.page" :items="sList" :loading="loading" :total="sTotal" :size="sQuery.size" @change="loadData">
            <template #item="{ item: row }">
              <article class="mobile-task-card">
                <div class="mobile-task-card__head"><strong>{{ row.targetName || row.targetId }}</strong><StatusTag :status="row.status" /></div>
                <div class="mobile-task-card__meta">{{ row.settlementNo }} · {{ row.periodStart }} 至 {{ row.periodEnd }}</div>
                <div class="mobile-task-card__meta">{{ row.orderCount }} 单 · 总额 {{ formatMoney(row.totalAmount) }} · 抽成 {{ formatMoney(row.commissionAmount) }}</div>
                <div class="mobile-task-card__foot"><span>应结 <b>{{ formatMoney(row.settleAmount) }}</b></span><el-button v-if="row.status === 'pending'" type="primary" @click="confirmSettle(row)">确认结算</el-button><b v-else>已处理</b></div>
              </article>
            </template>
          </MobileTaskList>
        </el-tab-pane>

        <el-tab-pane label="提现记录" name="withdrawal">
          <div class="filter-bar">
            <el-select v-model="wQuery.status" placeholder="状态" clearable style="width: 160px" @change="loadData">
              <el-option label="待审核" value="pending" />
              <el-option label="已通过" value="approved" />
              <el-option label="处理中" value="processing" />
              <el-option label="成功" value="success" />
              <el-option label="失败" value="failed" />
              <el-option label="已驳回" value="rejected" />
            </el-select>
          </div>
          <DataTable class="desktop-table" :data="wList" :loading="loading" :total="wTotal" v-model:page="wQuery.page" v-model:size="wQuery.size" @change="loadData">
            <el-table-column label="提现单号" prop="withdrawalNo" width="180" />
            <el-table-column label="申请人" prop="applicantId" width="120" />
            <el-table-column label="金额" width="130" align="right">
              <template #default="{ row }"><span class="amount">{{ formatMoney(row.amount) }}</span></template>
            </el-table-column>
            <el-table-column label="银行卡" width="180">
              <template #default="{ row }">{{ maskBankCard(row.bankCard) }}</template>
            </el-table-column>
            <el-table-column label="状态" width="110">
              <template #default="{ row }"><StatusTag :status="row.status" /></template>
            </el-table-column>
            <el-table-column label="申请时间" width="170">
              <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
            </el-table-column>
          </DataTable>
          <MobileTaskList v-model:page="wQuery.page" :items="wList" :loading="loading" :total="wTotal" :size="wQuery.size" @change="loadData">
            <template #item="{ item: row }">
              <article class="mobile-task-card">
                <div class="mobile-task-card__head"><strong>{{ row.withdrawalNo }}</strong><StatusTag :status="row.status" /></div>
                <div class="mobile-task-card__meta">申请人 {{ row.applicantId }} · {{ maskBankCard(row.bankCard) }}</div>
                <div class="mobile-task-card__foot"><span>{{ formatDate(row.createTime) }}</span><b>{{ formatMoney(row.amount) }}</b></div>
              </article>
            </template>
          </MobileTaskList>
        </el-tab-pane>
      </el-tabs>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import MobileTaskList from '@/components/MobileTaskList.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getSettlements, confirmSettlement, getWithdrawals } from '@/api/finance'
import { formatDate, formatMoney, maskBankCard } from '@/utils/format'
import type { Settlement, Withdrawal } from '@/types'

const activeTab = ref('settlement')
const loading = ref(false)
const loadError = ref(false)

const sQuery = reactive({ status: '', settleType: 'master', page: 1, size: 20 })
const sList = ref<Settlement[]>([])
const sTotal = ref(0)

const wQuery = reactive({ applicantType: 'master', status: '', page: 1, size: 20 })
const wList = ref<Withdrawal[]>([])
const wTotal = ref(0)

async function loadData() {
  loading.value = true
  loadError.value = false
  try {
    if (activeTab.value === 'settlement') {
      const res = await getSettlements(sQuery)
      sList.value = res.list || []
      sTotal.value = res.total || 0
    } else {
      const res = await getWithdrawals(wQuery)
      wList.value = res.list || []
      wTotal.value = res.total || 0
    }
  } catch {
    loadError.value = true
  } finally {
    loading.value = false
  }
}

async function confirmSettle(row: Settlement) {
  await ElMessageBox.confirm(`确认结算单「${row.settlementNo}」？`, '确认结算', { type: 'warning' })
  await confirmSettlement(row.id)
  ElMessage.success('结算单已确认')
  loadData()
}

onMounted(loadData)
</script>

<style scoped>
.table-wrap {
  padding: 16px;
}
.filter-bar {
  margin-bottom: 12px;
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
