<template>
  <div class="dfx-page">
    <PageHeader title="法师审核" subtitle="法师资质认证审核">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.status" placeholder="审核状态" clearable style="width: 160px" @change="onSearch">
        <el-option label="待审核" value="pending" />
        <el-option label="已通过" value="pass" />
        <el-option label="已驳回" value="rejected" />
      </el-select>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="申请编号" prop="id" width="90" />
        <el-table-column label="法师编码" prop="masterCode" width="120" />
        <el-table-column label="所属寺院" prop="templeCode" width="120" />
        <el-table-column label="资质材料" min-width="180">
          <template #default="{ row }">
            <el-image
              v-for="(url, i) in row.credentialUrls"
              :key="i"
              :src="url"
              fit="cover"
              class="cert-img"
              :preview-src-list="row.credentialUrls"
              :initial-index="i"
              preview-teleported
            >
              <template #error><div class="cert-img cert-img--fallback">证</div></template>
            </el-image>
            <span v-if="!row.credentialUrls?.length">-</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="申请时间" width="170">
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
import { getMasterAudits, masterAuditPass, masterAuditReject } from '@/api/master'
import { formatDate } from '@/utils/format'
import type { MasterAudit } from '@/types'

const loading = ref(false)
const list = ref<MasterAudit[]>([])
const total = ref(0)
const query = reactive({ status: '', page: 1, size: 20 })

async function loadData() {
  loading.value = true
  try {
    const res = await getMasterAudits(query)
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

async function doAudit(row: MasterAudit, action: 'approve' | 'reject', remark: string) {
  if (action === 'approve') await masterAuditPass(row.id, remark)
  else await masterAuditReject(row.id, remark)
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
.cert-img {
  width: 40px;
  height: 40px;
  border-radius: var(--radius-sm);
  margin-right: 6px;
}
.cert-img--fallback {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg-tertiary);
  color: var(--color-text-tertiary);
  font-size: 12px;
}
.muted {
  color: var(--color-text-tertiary);
  font-size: 12px;
}
</style>
