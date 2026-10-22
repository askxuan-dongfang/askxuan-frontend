<template>
  <div class="dfx-page">
    <PageHeader :title='$t("提现审核与收支汇总")' :subtitle='$t("提现审核 / 收支汇总")'>
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">{{ $t("刷新") }}</el-button>
      </template>
    </PageHeader>

    <el-alert :title='$t("真实打款通道尚未接入")' :description='$t("当前仅支持提现审核。审核通过不会发起转账或将提现标记为成功。")' type="info" :closable="false" show-icon class="capability-note" />

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy"><div class="ax-page-feedback__title">{{ $t((activeTab === 'withdrawal' ? $t('提现审核队列加载失败') : $t('收支汇总加载失败'))) }}</div><div class="ax-page-feedback__description">{{ $t("资金数据状态未知，请重新加载后再审核。") }}</div></div>
      <el-button :loading="loading" @click="loadData">{{ $t("重新加载") }}</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <el-tabs v-model="activeTab" @tab-change="loadData">
        <el-tab-pane :label='$t("提现审核")' name="withdrawal">
          <div class="filter-bar">
            <el-select v-model="wQuery.applicantType" :placeholder='$t("申请方")' clearable style="width: 140px" @change="onWSearch">
              <el-option :label='$t("寺院")' value="temple" />
              <el-option :label='$t("法师")' value="master" />
              <el-option :label='$t("商城")' value="shop" />
            </el-select>
            <el-select v-model="wQuery.status" :placeholder='$t("状态")' clearable style="width: 150px" @change="onWSearch">
              <el-option :label='$t("待审核")' value="pending" />
              <el-option :label='$t("已通过")' value="approved" />
              <el-option :label='$t("处理中")' value="processing" />
              <el-option :label='$t("成功")' value="success" />
              <el-option :label='$t("失败")' value="failed" />
              <el-option :label='$t("已驳回")' value="rejected" />
            </el-select>
          </div>
          <DataTable class="desktop-table" :data="wList" :loading="loading" :total="wTotal" v-model:page="wQuery.page" v-model:size="wQuery.size" @change="loadWithdrawals">
            <el-table-column :label='$t("提现单号")' prop="withdrawalNo" width="180" />
            <el-table-column :label='$t("申请方")' width="120">
              <template #default="{ row }">{{ $t(applicantText(row.applicantType)) }} · {{ $t(row.applicantId) }}</template>
            </el-table-column>
            <el-table-column :label='$t("金额")' width="130" align="right">
              <template #default="{ row }"><span class="amount">{{ $t(formatMoney(row.amount)) }}</span></template>
            </el-table-column>
            <el-table-column :label='$t("收款账户")' width="180">
              <template #default="{ row }">{{ $t(maskBankCard(row.bankCard)) }}</template>
            </el-table-column>
            <el-table-column :label='$t("状态")' width="110">
              <template #default="{ row }"><StatusTag :status="row.status" /></template>
            </el-table-column>
            <el-table-column :label='$t("申请时间")' width="170">
              <template #default="{ row }">{{ $t(formatDate(row.createTime)) }}</template>
            </el-table-column>
            <el-table-column :label='$t("操作")' width="180" fixed="right">
              <template #default="{ row }">
                <template v-if="row.status === 'pending'">
                  <el-button link type="success" @click="auditW(row, 'approve')">{{ $t("通过") }}</el-button>
                  <el-button link type="danger" @click="auditW(row, 'reject')">{{ $t("驳回") }}</el-button>
                </template>
                <el-button v-else-if="row.status === 'approved'" link disabled>{{ $t("打款未接入") }}</el-button>
                <span v-else class="muted">-</span>
              </template>
            </el-table-column>
          </DataTable>
          <MobileTaskList v-model:page="wQuery.page" :items="wList" :loading="loading" :total="wTotal" :size="wQuery.size" @change="loadWithdrawals">
            <template #item="{ item: row }">
              <article class="mobile-task-card">
                <div class="mobile-task-card__head"><strong>{{ $t(row.withdrawalNo) }}</strong><StatusTag :status="row.status" /></div>
                <div class="mobile-task-card__meta">{{ $t(applicantText(row.applicantType)) }} {{ $t(row.applicantId) }} · {{ $t(maskBankCard(row.bankCard)) }}</div>
                <div class="mobile-task-card__foot">
                  <span>{{ $t(formatDate(row.createTime)) }} · <b>{{ $t(formatMoney(row.amount)) }}</b></span>
                  <span class="mobile-actions" v-if="row.status === 'pending'"><el-button type="success" @click="auditW(row, 'approve')">{{ $t("通过") }}</el-button><el-button type="danger" plain @click="auditW(row, 'reject')">{{ $t("驳回") }}</el-button></span>
                  <el-button v-else-if="row.status === 'approved'" disabled>{{ $t("打款未接入") }}</el-button>
                  <b v-else>{{ $t("已处理") }}</b>
                </div>
              </article>
            </template>
          </MobileTaskList>
        </el-tab-pane>

        <el-tab-pane :label='$t("收支汇总")' name="report">
          <div class="filter-bar">
            <el-date-picker v-model="dateRange" type="daterange" range-separator="至" start-placeholder="开始日期" end-placeholder="结束日期" value-format="YYYY-MM-DD" style="width: 320px" />
            <el-button type="primary" :icon="Search" @click="loadReport">{{ $t("生成报表") }}</el-button>
          </div>
          <div v-if="report" class="report-cards">
            <StatCard :label='$t("总收入")' :value="report.totalIncome" icon="Money" icon-color="#C8A96E" prefix="¥" />
            <StatCard :label='$t("总结算")' :value="report.totalSettlement" icon="Wallet" icon-color="#C45A3C" prefix="¥" />
            <StatCard :label='$t("总提现")' :value="report.totalWithdrawal" icon="CreditCard" icon-color="#B5453A" prefix="¥" />
            <StatCard :label='$t("订单数")' :value="report.orderCount" icon="List" icon-color="#5B8C5A" :suffix='$t(" 单")' />
          </div>
          <el-empty v-else :description='$t("请选择日期范围生成收支汇总")' />
        </el-tab-pane>
      </el-tabs>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { ref, reactive, onMounted } from 'vue'
import { Refresh, Search } from '@element-plus/icons-vue'

import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import MobileTaskList from '@/components/MobileTaskList.vue'
import StatusTag from '@/components/StatusTag.vue'
import StatCard from '@/components/StatCard.vue'
import { getWithdrawals, auditWithdrawal, getFinanceReports } from '@/api/finance'
import { formatDate, formatMoney, maskBankCard } from '@/utils/format'
import type { Withdrawal, FinanceReport } from '@/types'

const activeTab = ref('withdrawal')
const loading = ref(false)
const loadError = ref(false)

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
  loadError.value = false
  try {
    const res = await getWithdrawals(wQuery)
    wList.value = res.list || []
    wTotal.value = res.total || 0
  } catch {
    loadError.value = true
  } finally {
    loading.value = false
  }
}

function onWSearch() {
  wQuery.page = 1
  loadWithdrawals()
}

async function auditW(row: Withdrawal, action: 'approve' | 'reject') {
  if (action === 'approve') {
    await ElMessageBox.confirm(
      (uiText("确认通过提现单「") + String(row.withdrawalNo) + uiText("」？金额 ") + String(formatMoney(row.amount)) + uiText("。当前未接入打款通道，审核通过不会发起转账。")),
      uiText('提现审核确认'),
      { type: 'warning', confirmButtonText: uiText('确认通过'), cancelButtonText: uiText('返回核对') }
    )
  }
  const remark = action === 'reject'
    ? await ElMessageBox.prompt(
        `驳回后提现单「${row.withdrawalNo}」不会进入打款，申请方将看到处理结果。请输入驳回原因。`,
        '驳回提现',
        { type: 'warning', confirmButtonText: '确认驳回', cancelButtonText: '返回核对', inputType: 'textarea' }
      ).then((r) => r.value).catch(() => null)
    : ''
  if (action === 'reject' && remark === null) return
  await auditWithdrawal(row.id, { action, remark: remark || undefined })
  ElMessage.success(uiText('操作成功'))
  loadWithdrawals()
}

async function loadReport() {
  if (!dateRange.value) {
    ElMessage.warning(uiText('请选择日期范围'))
    return
  }
  loading.value = true
  loadError.value = false
  try {
    report.value = await getFinanceReports({ startTime: dateRange.value[0], endTime: dateRange.value[1] })
  } catch {
    loadError.value = true
  } finally {
    loading.value = false
  }
}

async function loadData() {
  if (activeTab.value === 'withdrawal') await loadWithdrawals()
  else if (report.value) await loadReport()
}

onMounted(loadWithdrawals)
</script>

<style scoped>
.table-wrap {
  padding: 16px;
}
.capability-note {
  margin-bottom: 16px;
}
.filter-bar {
  display: flex;
  gap: 12px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}
.amount {
  color: var(--color-accent);
  font-weight: var(--type-weight-semibold);
}
.muted {
  color: var(--color-text-tertiary);
  font-size: var(--type-size-caption);
}
.report-cards {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  margin-top: 8px;
}
.mobile-actions { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px; }
.mobile-actions :deep(.el-button + .el-button) { margin-left: 0; }
@media (max-width: 767px) {
  .report-cards { grid-template-columns: minmax(0, 1fr); }
}
</style>
