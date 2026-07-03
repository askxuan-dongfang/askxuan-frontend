<template>
  <div class="dfx-page">
    <PageHeader title="数据备份" subtitle="数据库快照与恢复（前端桩实现）">
      <template #actions>
        <el-button type="primary" :icon="Plus" :loading="backing" @click="createBackup">立即备份</el-button>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <el-alert title="本页面为前端桩实现，备份数据仅作演示，未对接后端存储。" type="warning" :closable="false" show-icon style="margin-bottom: 16px" />

    <div class="stat-row">
      <StatCard label="备份总数" :value="backups.length" icon="Files" icon-color="#C8A96E" suffix=" 份" />
      <StatCard label="最近备份" :value="lastBackupTime" icon="Clock" icon-color="#5B8C5A" />
      <StatCard label="占用空间" :value="totalSize" icon="Coin" icon-color="#C45A3C" suffix=" MB" />
      <StatCard label="自动备份" value="每日 03:00" icon="Calendar" icon-color="#D4A843" />
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="backups" :loading="loading" :show-pagination="false">
        <el-table-column label="备份编号" prop="id" width="120" />
        <el-table-column label="文件名" prop="filename" min-width="220" />
        <el-table-column label="大小（MB）" prop="size" width="120" align="right" />
        <el-table-column label="类型" width="120">
          <template #default="{ row }">
            <el-tag size="small" :type="row.type === 'auto' ? 'info' : 'warning'" effect="dark">
              {{ row.type === 'auto' ? '自动' : '手动' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="备份时间" width="180">
          <template #default="{ row }">{{ formatDate(row.time) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" :icon="Download" @click="onDownload(row)">下载</el-button>
            <el-button link type="success" :icon="RefreshRight" @click="onRestore(row)">恢复</el-button>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Plus, Refresh, Download, RefreshRight } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatCard from '@/components/StatCard.vue'
import StatusTag from '@/components/StatusTag.vue'
import { formatDate } from '@/utils/format'

interface BackupItem {
  id: string
  filename: string
  size: number
  type: 'auto' | 'manual'
  status: string
  time: string
}

const loading = ref(false)
const backing = ref(false)
const backups = ref<BackupItem[]>([])

const lastBackupTime = computed(() => (backups.value.length ? formatDate(backups.value[0].time) : '-'))
const totalSize = computed(() => backups.value.reduce((sum, b) => sum + b.size, 0).toFixed(1))

// 前端桩：生成 mock 数据
function genMock(): BackupItem[] {
  const now = Date.now()
  return [
    { id: 'BK20260702001', filename: 'df_platform_20260702_030000.sql.gz', size: 128.5, type: 'auto', status: 'success', time: new Date(now - 3600 * 1000).toISOString() },
    { id: 'BK20260701001', filename: 'df_platform_20260701_030000.sql.gz', size: 125.8, type: 'auto', status: 'success', time: new Date(now - 86400 * 1000).toISOString() },
    { id: 'BK20260630001', filename: 'df_platform_20260630_142030.sql.gz', size: 124.2, type: 'manual', status: 'success', time: new Date(now - 86400 * 2 * 1000).toISOString() },
    { id: 'BK20260629001', filename: 'df_platform_20260629_030000.sql.gz', size: 122.1, type: 'auto', status: 'success', time: new Date(now - 86400 * 3 * 1000).toISOString() }
  ]
}

function loadData() {
  loading.value = true
  // 模拟异步加载
  setTimeout(() => {
    backups.value = genMock()
    loading.value = false
  }, 300)
}

async function createBackup() {
  backing.value = true
  await new Promise((r) => setTimeout(r, 800))
  const id = `BK${Date.now()}`
  backups.value.unshift({
    id,
    filename: `df_platform_${formatDate(Date.now(), 'YYYYMMDD_HHmmss')}.sql.gz`,
    size: Number((120 + Math.random() * 10).toFixed(1)),
    type: 'manual',
    status: 'success',
    time: new Date().toISOString()
  })
  backing.value = false
  ElMessage.success('备份完成（桩）')
}

function onDownload(row: BackupItem) {
  ElMessage.info(`下载备份：${row.filename}（桩，未实际下载）`)
}

async function onRestore(row: BackupItem) {
  await ElMessageBox.confirm(`确认从备份「${row.filename}」恢复数据库？该操作不可逆。`, '恢复确认', { type: 'warning' })
  ElMessage.success('恢复指令已提交（桩）')
}

onMounted(loadData)
</script>

<style scoped>
.stat-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  margin-bottom: 20px;
}
.table-wrap {
  padding: 16px;
}
</style>
