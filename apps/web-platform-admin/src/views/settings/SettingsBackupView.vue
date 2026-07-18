<template>
  <div class="dfx-page">
    <PageHeader title="数据备份" subtitle="数据库快照、下载与受控恢复">
      <template #actions>
        <el-button type="primary" :icon="Plus" :loading="backing" @click="createBackup">立即备份</el-button>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="stat-row">
      <StatCard label="备份总数" :value="backups.length" icon="Files" icon-color="#C8A96E" suffix=" 份" />
      <StatCard label="最近备份" :value="lastBackupTime" icon="Clock" icon-color="#5B8C5A" />
      <StatCard label="占用空间" :value="totalSize" icon="Coin" icon-color="#C45A3C" suffix=" MB" />
      <StatCard label="存储位置" value="私有对象存储" icon="Calendar" icon-color="#D4A843" />
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="backups" :loading="loading" :show-pagination="false">
        <el-table-column label="备份编号" prop="id" width="120" />
        <el-table-column label="文件名" prop="filename" min-width="220" />
        <el-table-column label="大小（MB）" prop="size" width="120" align="right" />
        <el-table-column label="类型" width="120">
          <template #default="{ row }">
            <el-tag size="small" type="warning" effect="dark">手动全量</el-tag>
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
import { getBackups, createBackup as requestBackup, getBackupDownload, restoreBackup, type BackupItem } from '@/api/system'

const loading = ref(false)
const backing = ref(false)
const backups = ref<BackupItem[]>([])

const lastBackupTime = computed(() => (backups.value.length ? formatDate(backups.value[0].time) : '-'))
const totalSize = computed(() => backups.value.reduce((sum, b) => sum + b.size, 0).toFixed(1))

async function loadData() {
  loading.value = true
  try {
    const response = await getBackups()
    backups.value = response.list || []
  } finally {
    loading.value = false
  }
}

async function createBackup() {
  backing.value = true
  try {
    await requestBackup()
    ElMessage.success('备份完成')
    await loadData()
  } finally {
    backing.value = false
  }
}

async function onDownload(row: BackupItem) {
  const response = await getBackupDownload(row.filename)
  window.open(response.url, '_blank', 'noopener,noreferrer')
}

async function onRestore(row: BackupItem) {
  const result = await ElMessageBox.prompt(
    `恢复会覆盖当前数据库。请输入完整文件名 ${row.filename} 继续。`,
    '恢复确认',
    { type: 'warning', confirmButtonText: '恢复', inputPattern: new RegExp(`^${row.filename.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`), inputErrorMessage: '文件名不匹配' }
  )
  const response = await restoreBackup(row.filename, result.value)
  ElMessage.success(response.message || '恢复完成')
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
