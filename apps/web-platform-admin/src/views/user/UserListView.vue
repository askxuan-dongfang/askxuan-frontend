<template>
  <div class="dfx-page">
    <PageHeader :title='$t("用户列表")' :subtitle='$t("全平台注册用户管理")'>
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">{{ $t("刷新") }}</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-input v-model="query.keyword" :placeholder='$t("手机号 / 昵称")' clearable style="width: 220px" @keyup.enter="onSearch" />
      <el-select v-model="query.status" :placeholder='$t("状态")' clearable style="width: 140px" @change="onSearch">
        <el-option :label='$t("正常")' value="normal" />
        <el-option :label='$t("封禁")' value="banned" />
      </el-select>
      <el-button type="primary" :icon="Search" @click="onSearch">{{ $t("查询") }}</el-button>
      <el-button :icon="RefreshLeft" @click="onReset">{{ $t("重置") }}</el-button>
    </div>
    <p class="stats-note">{{ $t('订单数为真实渠道已付款订单，消费为实付减成功退款；不含模拟付款、体验订单和测试余额。') }}</p>
    <div v-if="loadError" class="ax-page-feedback is-error" role="alert"><div class="ax-page-feedback__copy"><strong>{{ $t('用户与消费统计加载失败') }}</strong><p>{{ $t('统计不可用时不会显示为零，请重新加载。') }}</p></div><el-button @click="loadData">{{ $t('重新加载') }}</el-button></div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData" show-index>
        <el-table-column :label='$t("用户")' min-width="200">
          <template #default="{ row }">
            <div class="user-cell">
              <el-avatar :size="38" :src="row.avatar">{{ row.nickname?.slice(0, 1) }}</el-avatar>
              <div>
                <div class="user-cell__name">{{ row.nickname }}</div>
                <div class="user-cell__id">ID: {{ $t(row.userId) }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column :label='$t("手机号")' width="140">
          <template #default="{ row }">{{ maskMobile(row.mobile) }}</template>
        </el-table-column>
        <el-table-column :label='$t("地区")' prop="region" width="120" />
        <el-table-column :label='$t("已付订单")' prop="totalOrders" width="110" align="center" />
        <el-table-column :label='$t("净消费")' width="140" align="right">
          <template #default="{ row }">{{ $t(formatMoney(row.totalSpent)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("状态")' width="100">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column :label='$t("注册时间")' width="170">
          <template #default="{ row }">{{ $t(formatDate(row.createTime)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("操作")' width="170" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="$router.push(`/user/detail/${row.userId}`)">{{ $t("详情") }}</el-button>
            <el-button v-if="row.status === 'normal'" link type="danger" @click="onStatus(row, 'banned')">{{ $t("封禁") }}</el-button>
            <el-button v-else link type="success" @click="onStatus(row, 'normal')">{{ $t("解封") }}</el-button>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { ref, reactive, onMounted } from 'vue'
import { Search, Refresh, RefreshLeft } from '@element-plus/icons-vue'

import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getUserList, updateUserStatus } from '@/api/user'
import { formatDate, formatMoney, maskMobile } from '@/utils/format'
import type { AdminUserItem } from '@/types'

const loading = ref(false)
const loadError = ref(false)
const list = ref<AdminUserItem[]>([])
const total = ref(0)
const query = reactive({ keyword: '', status: '', page: 1, size: 20 })

async function loadData() {
  loading.value = true
  loadError.value = false
  try {
    const res = await getUserList(query)
    list.value = res.list || []
    total.value = res.total || 0
  } catch {
    list.value = []; total.value = 0; loadError.value = true
  } finally {
    loading.value = false
  }
}

function onSearch() {
  query.page = 1
  loadData()
}
function onReset() {
  query.keyword = ''
  query.status = ''
  onSearch()
}

async function onStatus(row: AdminUserItem, status: string) {
  await ElMessageBox.confirm((uiText("确认") + String((status === 'banned' ? uiText('封禁') : uiText('解封'))) + uiText("用户「") + String(row.nickname) + uiText("」？") + uiText(status === 'banned' ? '封禁后旧会话立即失效，订单和资产保留。' : '解封后需要重新登录，旧会话不会恢复。')), uiText('提示'), {
    type: status === 'banned' ? 'warning' : 'info'
  })
  await updateUserStatus(row.userId, status)
  ElMessage.success(uiText('操作成功'))
  loadData()
}

onMounted(loadData)
</script>

<style scoped>
.filter-bar {
  display: flex;
  gap: 12px;
  padding: 16px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}
.table-wrap {
  padding: 16px;
}
.stats-note{color:var(--color-text-secondary);line-height:1.8;margin:0 0 16px}
.user-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}
.user-cell__name {
  font-weight: var(--type-weight-semibold);
  color: var(--color-text-primary);
}
.user-cell__id {
  font-size: var(--type-size-caption);
  color: var(--color-text-tertiary);
}
</style>
