<template>
  <div class="dfx-page">
    <PageHeader title="操作日志" subtitle="平台审核与操作记录追踪">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.bizType" placeholder="业务类型" clearable style="width: 150px" @change="onSearch">
        <el-option label="设计素材" value="design" />
        <el-option label="寺院" value="temple" />
        <el-option label="法师" value="master" />
        <el-option label="评价" value="comment" />
      </el-select>
      <el-select v-model="query.status" placeholder="处理结果" clearable style="width: 150px" @change="onSearch">
        <el-option label="待处理" value="pending" />
        <el-option label="已通过" value="approved" />
        <el-option label="已驳回" value="rejected" />
      </el-select>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="编号" prop="id" width="80" />
        <el-table-column label="业务类型" width="120">
          <template #default="{ row }">{{ bizTypeText(row.bizType) }}</template>
        </el-table-column>
        <el-table-column label="业务ID" prop="bizId" width="120" />
        <el-table-column label="提交人" prop="submitterId" width="120" />
        <el-table-column label="审核人" prop="auditorId" width="120" />
        <el-table-column label="处理结果" width="110">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="审核备注" prop="auditRemark" min-width="160" show-overflow-tooltip />
        <el-table-column label="审核时间" width="170">
          <template #default="{ row }">{{ formatDate(row.auditTime) }}</template>
        </el-table-column>
        <el-table-column label="提交时间" width="170">
          <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
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
import { getOperationLogs } from '@/api/system'
import { formatDate } from '@/utils/format'
import type { AuditQueue } from '@/types'

const loading = ref(false)
const list = ref<AuditQueue[]>([])
const total = ref(0)
const query = reactive({ bizType: '', status: '', page: 1, size: 20 })

function bizTypeText(t: string) {
  return { design: '设计素材', temple: '寺院', master: '法师', comment: '评价' }[t] || t || '-'
}

async function loadData() {
  loading.value = true
  try {
    const res = await getOperationLogs(query)
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
</style>
