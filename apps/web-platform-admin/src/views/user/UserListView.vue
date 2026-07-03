<template>
  <div class="dfx-page">
    <PageHeader title="用户列表" subtitle="全平台注册用户管理">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-input v-model="query.keyword" placeholder="手机号 / 昵称" clearable style="width: 220px" @keyup.enter="onSearch" />
      <el-select v-model="query.status" placeholder="状态" clearable style="width: 140px" @change="onSearch">
        <el-option label="正常" value="normal" />
        <el-option label="封禁" value="banned" />
      </el-select>
      <el-button type="primary" :icon="Search" @click="onSearch">查询</el-button>
      <el-button :icon="RefreshLeft" @click="onReset">重置</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData" show-index>
        <el-table-column label="用户" min-width="200">
          <template #default="{ row }">
            <div class="user-cell">
              <el-avatar :size="38" :src="row.avatar">{{ row.nickname?.slice(0, 1) }}</el-avatar>
              <div>
                <div class="user-cell__name">{{ row.nickname }}</div>
                <div class="user-cell__id">ID: {{ row.userId }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="手机号" width="140">
          <template #default="{ row }">{{ maskMobile(row.mobile) }}</template>
        </el-table-column>
        <el-table-column label="地区" prop="region" width="120" />
        <el-table-column label="订单数" prop="totalOrders" width="100" align="center" />
        <el-table-column label="消费总额" width="140" align="right">
          <template #default="{ row }">{{ formatMoney(row.totalSpent) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="注册时间" width="170">
          <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="170" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="$router.push(`/user/detail/${row.userId}`)">详情</el-button>
            <el-button v-if="row.status === 'normal'" link type="danger" @click="onStatus(row, 'banned')">封禁</el-button>
            <el-button v-else link type="success" @click="onStatus(row, 'normal')">解封</el-button>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Search, Refresh, RefreshLeft } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getUserList, updateUserStatus } from '@/api/user'
import { formatDate, formatMoney, maskMobile } from '@/utils/format'
import type { AdminUserItem } from '@/types'

const loading = ref(false)
const list = ref<AdminUserItem[]>([])
const total = ref(0)
const query = reactive({ keyword: '', status: '', page: 1, size: 20 })

async function loadData() {
  loading.value = true
  try {
    const res = await getUserList(query)
    list.value = res.list || []
    total.value = res.total || 0
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
  await ElMessageBox.confirm(`确认${status === 'banned' ? '封禁' : '解封'}用户「${row.nickname}」？`, '提示', {
    type: status === 'banned' ? 'warning' : 'info'
  })
  await updateUserStatus(row.userId, status)
  ElMessage.success('操作成功')
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
.user-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}
.user-cell__name {
  font-weight: 600;
  color: var(--color-text-primary);
}
.user-cell__id {
  font-size: 12px;
  color: var(--color-text-tertiary);
}
</style>
