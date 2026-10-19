<template>
  <div class="dfx-page">
    <PageHeader :title='$t("寺院结算")' :subtitle='$t("寺院结算单查询与确认")'>
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">{{ $t("刷新") }}</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.status" :placeholder='$t("结算状态")' clearable style="width: 150px" @change="onSearch">
        <el-option :label='$t("待确认")' value="pending" />
        <el-option :label='$t("已确认")' value="confirmed" />
        <el-option :label='$t("已付款")' value="paid" />
      </el-select>
    </div>

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy"><div class="ax-page-feedback__title">{{ $t("寺院结算单加载失败") }}</div><div class="ax-page-feedback__description">{{ $t("结算队列状态未知，请勿按无待结算单处理。") }}</div></div>
      <el-button :loading="loading" @click="loadData">{{ $t("重新加载") }}</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable class="desktop-table" :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column :label='$t("结算单号")' prop="settlementNo" width="180" />
        <el-table-column :label='$t("寺院")' min-width="160">
          <template #default="{ row }">
            <div>{{ $t(row.targetName) }}</div>
            <div class="muted">{{ $t(row.targetId) }}</div>
          </template>
        </el-table-column>
        <el-table-column :label='$t("结算周期")' width="200">
          <template #default="{ row }">{{ $t(row.periodStart) }} ~ {{ $t(row.periodEnd) }}</template>
        </el-table-column>
        <el-table-column :label='$t("订单数")' prop="orderCount" width="90" align="center" />
        <el-table-column :label='$t("总金额")' width="130" align="right">
          <template #default="{ row }">{{ $t(formatMoney(row.totalAmount)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("抽成比例")' width="100" align="center">
          <template #default="{ row }">{{ $t(formatPercent(row.commissionRate)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("抽成金额")' width="130" align="right">
          <template #default="{ row }">{{ $t(formatMoney(row.commissionAmount)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("应结金额")' width="140" align="right">
          <template #default="{ row }"><span class="amount">{{ $t(formatMoney(row.settleAmount)) }}</span></template>
        </el-table-column>
        <el-table-column :label='$t("状态")' width="110">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column :label='$t("操作")' width="120" fixed="right">
          <template #default="{ row }">
            <el-button v-if="row.status === 'pending'" link type="success" :loading="row._saving" @click="confirm(row)">{{ $t("确认结算") }}</el-button>
            <span v-else class="muted">-</span>
          </template>
        </el-table-column>
      </DataTable>
      <MobileTaskList v-model:page="query.page" :items="list" :loading="loading" :total="total" :size="query.size" @change="loadData">
        <template #item="{ item: row }">
          <article class="mobile-task-card">
            <div class="mobile-task-card__head"><strong>{{ $t((row.targetName || row.targetId)) }}</strong><StatusTag :status="row.status" /></div>
            <div class="mobile-task-card__meta">{{ $t(row.settlementNo) }} · {{ $t(row.periodStart) }}{{ $t(" 至 ") }}{{ $t(row.periodEnd) }}</div>
            <div class="mobile-task-card__meta">{{ $t(row.orderCount) }}{{ $t(" 单 · 总额 ") }}{{ $t(formatMoney(row.totalAmount)) }}{{ $t(" · 抽成 ") }}{{ $t(formatPercent(row.commissionRate)) }}</div>
            <div class="mobile-task-card__foot"><span>{{ $t("应结 ") }}<b>{{ $t(formatMoney(row.settleAmount)) }}</b></span><el-button v-if="row.status === 'pending'" type="primary" :loading="row._saving" @click="confirm(row)">{{ $t("确认结算") }}</el-button><b v-else>{{ $t("已处理") }}</b></div>
          </article>
        </template>
      </MobileTaskList>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { ref, reactive, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'

import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import MobileTaskList from '@/components/MobileTaskList.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getSettlements, confirmSettlement } from '@/api/finance'
import { formatMoney, formatPercent } from '@/utils/format'
import type { Settlement } from '@/types'

interface Row extends Settlement {
  _saving?: boolean
}

const loading = ref(false)
const loadError = ref(false)
const list = ref<Row[]>([])
const total = ref(0)
const query = reactive({ status: '', settleType: 'temple', page: 1, size: 20 })

async function loadData() {
  loading.value = true
  loadError.value = false
  try {
    const res = await getSettlements(query)
    list.value = (res.list || []).map((s) => ({ ...s }))
    total.value = res.total || 0
  } catch {
    loadError.value = true
  } finally {
    loading.value = false
  }
}

function onSearch() {
  query.page = 1
  loadData()
}

async function confirm(row: Row) {
  await ElMessageBox.confirm((uiText("确认结算单「") + String(row.settlementNo) + uiText("」，应结金额 ") + String(formatMoney(row.settleAmount)) + uiText("？")), uiText('确认结算'), { type: 'warning' })
  row._saving = true
  try {
    await confirmSettlement(row.id)
    ElMessage.success(uiText('结算单已确认'))
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
  font-weight: var(--type-weight-semibold);
}
.muted {
  color: var(--color-text-tertiary);
  font-size: var(--type-size-caption);
}
</style>
