<template>
  <div class="dfx-page">
    <PageHeader title="寺院列表" subtitle="全平台寺院信息与状态管理">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-input v-model="query.region" placeholder="地区" clearable style="width: 140px" />
      <el-select v-model="query.sect" placeholder="宗派" clearable style="width: 140px">
        <el-option v-for="s in sects" :key="s" :label="s" :value="s" />
      </el-select>
      <el-select v-model="query.type" placeholder="类型" clearable style="width: 140px">
        <el-option v-for="t in types" :key="t" :label="t" :value="t" />
      </el-select>
      <el-button type="primary" :icon="Search" @click="onSearch">查询</el-button>
      <el-button :icon="RefreshLeft" @click="onReset">重置</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="寺院" min-width="220">
          <template #default="{ row }">
            <div class="temple-cell">
              <el-image :src="row.coverImage" class="temple-cell__img" fit="cover">
                <template #error><div class="temple-cell__img-fallback">寺</div></template>
              </el-image>
              <div>
                <div class="temple-cell__name">{{ row.name }}</div>
                <div class="temple-cell__id">{{ row.id }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="地区" prop="region" width="110" />
        <el-table-column label="类型" prop="type" width="100" />
        <el-table-column label="宗派" prop="sect" width="100" />
        <el-table-column label="评分" width="90">
          <template #default="{ row }">
            <span class="star">★ {{ row.rating?.toFixed(1) || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <StatusTag :status="row.status" />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="240" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="$router.push(`/temple/detail/${row.id}`)">详情</el-button>
            <el-dropdown @command="(cmd: string) => onStatus(row, cmd)">
              <el-button link type="warning">状态<el-icon><ArrowDown /></el-icon></el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="normal">设为正常</el-dropdown-item>
                  <el-dropdown-item command="recommended">设为推荐</el-dropdown-item>
                  <el-dropdown-item command="banned">封禁寺院</el-dropdown-item>
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
import { getTempleList, updateTempleStatus } from '@/api/temple'
import type { Temple } from '@/types'

const sects = ['禅宗', '净土宗', '天台宗', '律宗', '全真派', '正一道']
const types = ['佛教', '道教']

const loading = ref(false)
const list = ref<Temple[]>([])
const total = ref(0)
const query = reactive({ region: '', sect: '', type: '', page: 1, size: 20 })

async function loadData() {
  loading.value = true
  try {
    const res = await getTempleList(query)
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
  query.region = ''
  query.sect = ''
  query.type = ''
  onSearch()
}

async function onStatus(row: Temple, status: string) {
  const actionText = { normal: '设为正常', recommended: '设为推荐', banned: '封禁' }[status] || status
  await ElMessageBox.confirm(`确认将「${row.name}」${actionText}？`, '提示', { type: status === 'banned' ? 'warning' : 'info' })
  await updateTempleStatus(row.id, status)
  ElMessage.success('状态已更新')
  loadData()
}

onMounted(loadData)
</script>

<style scoped>
.filter-bar {
  display: flex;
  gap: 12px;
  align-items: center;
  padding: 16px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}
.table-wrap {
  padding: 16px;
}
.temple-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}
.temple-cell__img,
.temple-cell__img-fallback {
  width: 44px;
  height: 44px;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
}
.temple-cell__img-fallback {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg-tertiary);
  color: var(--color-accent);
  font-family: var(--font-serif);
  font-weight: 700;
}
.temple-cell__name {
  font-weight: 600;
  color: var(--color-text-primary);
}
.temple-cell__id {
  font-size: 12px;
  color: var(--color-text-tertiary);
}
.star {
  color: var(--color-accent);
  font-weight: 600;
}
</style>
