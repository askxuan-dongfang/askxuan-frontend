<template>
  <div class="dfx-page">
    <PageHeader title="法师列表" subtitle="全平台法师信息与状态管理">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-input v-model="query.templeId" placeholder="寺院编码" clearable style="width: 140px" />
      <el-select v-model="query.sect" placeholder="宗派" clearable style="width: 140px">
        <el-option v-for="s in sects" :key="s" :label="s" :value="s" />
      </el-select>
      <el-select v-model="query.type" placeholder="类型" clearable style="width: 120px">
        <el-option label="佛教" value="佛教" />
        <el-option label="道教" value="道教" />
      </el-select>
      <el-button type="primary" :icon="Search" @click="onSearch">查询</el-button>
      <el-button :icon="RefreshLeft" @click="onReset">重置</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="法师" min-width="200">
          <template #default="{ row }">
            <div class="master-cell">
              <el-avatar :size="40" :src="row.avatar">{{ row.dharmaName?.slice(0, 1) }}</el-avatar>
              <div>
                <div class="master-cell__name">{{ row.dharmaName }}<span class="master-cell__lay">（{{ row.layName }}）</span></div>
                <div class="master-cell__id">{{ row.id }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="所属寺院" prop="templeName" width="150" />
        <el-table-column label="职位" prop="position" width="100" />
        <el-table-column label="宗派" prop="sect" width="90" />
        <el-table-column label="类型" prop="type" width="80" />
        <el-table-column label="专长" min-width="160">
          <template #default="{ row }">
            <el-tag v-for="s in row.specialties" :key="s" size="small" effect="plain" style="margin-right: 4px">{{ s }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="评分" width="80">
          <template #default="{ row }"><span class="star">★ {{ row.rating?.toFixed(1) }}</span></template>
        </el-table-column>
        <el-table-column label="认证" width="100">
          <template #default="{ row }"><StatusTag :status="row.authStatus" /></template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-dropdown @command="(cmd: string) => onStatus(row, cmd)">
              <el-button link type="warning">状态<el-icon><ArrowDown /></el-icon></el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="normal">设为正常</el-dropdown-item>
                  <el-dropdown-item command="banned">封禁法师</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Search, Refresh, RefreshLeft, ArrowDown } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getMasterList, updateMasterStatus } from '@/api/master'
import type { Master } from '@/types'

const sects = ['禅宗', '净土宗', '天台宗', '律宗', '全真派', '正一道']
const loading = ref(false)
const list = ref<Master[]>([])
const total = ref(0)
const query = reactive({ templeId: '', sect: '', type: '', page: 1, size: 20 })

async function loadData() {
  loading.value = true
  try {
    const res = await getMasterList(query)
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
  query.templeId = ''
  query.sect = ''
  query.type = ''
  onSearch()
}

async function onStatus(row: Master, status: string) {
  await ElMessageBox.confirm(`确认将法师「${row.dharmaName}」${status === 'banned' ? '封禁' : '恢复正常'}？`, '提示', {
    type: status === 'banned' ? 'warning' : 'info'
  })
  await updateMasterStatus(row.id, status)
  ElMessage.success('状态已更新')
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
.master-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}
.master-cell__name {
  font-weight: 600;
  color: var(--color-text-primary);
}
.master-cell__lay {
  font-weight: 400;
  color: var(--color-text-tertiary);
  font-size: 12px;
}
.master-cell__id {
  font-size: 12px;
  color: var(--color-text-tertiary);
}
.star {
  color: var(--color-accent);
  font-weight: 600;
}
</style>
