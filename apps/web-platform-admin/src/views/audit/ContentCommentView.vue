<template>
  <div class="dfx-page">
    <PageHeader title="评价审核" subtitle="用户评价内容审核队列">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.status" placeholder="审核状态" clearable style="width: 160px" @change="onSearch">
        <el-option label="待审核" value="pending" />
        <el-option label="已通过" value="approved" />
        <el-option label="已驳回" value="rejected" />
      </el-select>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="编号" prop="id" width="80" />
        <el-table-column label="业务ID" prop="bizId" width="120" />
        <el-table-column label="提交人" prop="submitterId" width="120" />
        <el-table-column label="内容快照" min-width="260">
          <template #default="{ row }">
            <div class="snapshot">{{ parseSnapshot(row.contentSnapshot) }}</div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="审核备注" prop="auditRemark" min-width="140" show-overflow-tooltip />
        <el-table-column label="提交时间" width="170">
          <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <AuditAction v-if="row.status === 'pending'" :on-confirm="(a, r) => doAudit(row, a, r)" @success="loadData" />
            <span v-else class="muted">已处理</span>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import AuditAction from '@/components/AuditAction.vue'
import { getAuditQueue, approveAudit, rejectAudit } from '@/api/audit'
import { useAuthStore } from '@/stores/auth'
import { formatDate, safeJsonParse } from '@/utils/format'
import type { AuditQueue } from '@/types'

const auth = useAuthStore()
const BIZ_TYPE = 'comment'

const loading = ref(false)
const list = ref<AuditQueue[]>([])
const total = ref(0)
const query = reactive({ status: '', page: 1, size: 20 })

function parseSnapshot(snapshot: string): string {
  const obj = safeJsonParse<any>(snapshot, null)
  if (!obj) return snapshot || '-'
  return obj.content || obj.text || JSON.stringify(obj)
}

async function loadData() {
  loading.value = true
  try {
    const res = await getAuditQueue({ ...query, bizType: BIZ_TYPE })
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

async function doAudit(row: AuditQueue, action: 'approve' | 'reject', remark: string) {
  const auditorId = String(auth.userInfo?.userId || '0')
  if (action === 'approve') await approveAudit(row.id, { auditorId, remark })
  else await rejectAudit(row.id, { auditorId, remark })
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
.snapshot {
  color: var(--color-text-secondary);
  font-size: 13px;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.muted {
  color: var(--color-text-tertiary);
  font-size: 12px;
}
</style>
