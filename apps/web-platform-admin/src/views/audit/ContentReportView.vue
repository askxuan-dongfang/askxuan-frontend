<template>
  <div class="dfx-page">
    <PageHeader title="举报处理" subtitle="全平台内容举报工单处理">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.targetType" placeholder="举报对象" clearable style="width: 150px" @change="onSearch">
        <el-option label="设计素材" value="design" />
        <el-option label="评价" value="comment" />
        <el-option label="法师" value="master" />
        <el-option label="寺院" value="temple" />
      </el-select>
      <el-select v-model="query.status" placeholder="处理状态" clearable style="width: 150px" @change="onSearch">
        <el-option label="待处理" value="pending" />
        <el-option label="已处理" value="handled" />
        <el-option label="已驳回" value="rejected" />
      </el-select>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="编号" prop="id" width="80" />
        <el-table-column label="举报人" prop="reporterId" width="110" />
        <el-table-column label="对象类型" width="100">
          <template #default="{ row }">{{ targetText(row.targetType) }}</template>
        </el-table-column>
        <el-table-column label="对象ID" prop="targetId" width="120" />
        <el-table-column label="举报原因" prop="reason" min-width="180" show-overflow-tooltip />
        <el-table-column label="证据" width="120">
          <template #default="{ row }">
            <el-image
              v-for="(url, i) in evidenceUrls(row.evidenceUrls)"
              :key="i"
              :src="url"
              fit="cover"
              class="evidence-img"
              :preview-src-list="evidenceUrls(row.evidenceUrls)"
              :initial-index="i"
              preview-teleported
            >
              <template #error><div class="evidence-img evidence-img--fallback">证</div></template>
            </el-image>
            <span v-if="!evidenceUrls(row.evidenceUrls).length">-</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="举报时间" width="170">
          <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <el-button v-if="row.status === 'pending'" link type="primary" @click="open(row)">处理</el-button>
            <span v-else class="muted">已处理</span>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <el-dialog v-model="dialog.visible" title="处理举报" width="460px">
      <div class="dialog-info">
        <p><span>对象类型：</span>{{ targetText(dialog.row?.targetType) }}</p>
        <p><span>举报原因：</span>{{ dialog.row?.reason }}</p>
      </div>
      <el-form label-position="top">
        <el-form-item label="处理结果">
          <el-radio-group v-model="dialog.handleResult">
            <el-radio value="handled">已处理（下架/封禁）</el-radio>
            <el-radio value="rejected">驳回举报</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="处理备注">
          <el-input v-model="dialog.remark" type="textarea" :rows="3" placeholder="请输入处理备注" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialog.visible = false">取消</el-button>
        <el-button type="primary" :loading="dialog.loading" @click="confirm">确认处理</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getAuditReports, handleAuditReport } from '@/api/audit'
import { useAuthStore } from '@/stores/auth'
import { formatDate, safeJsonParse } from '@/utils/format'
import type { Report } from '@/types'

const auth = useAuthStore()
const loading = ref(false)
const list = ref<Report[]>([])
const total = ref(0)
const query = reactive({ targetType: '', status: '', page: 1, size: 20 })

const dialog = reactive({
  visible: false,
  loading: false,
  row: null as Report | null,
  handleResult: 'handled' as 'handled' | 'rejected',
  remark: ''
})

function targetText(t?: string) {
  return { design: '设计素材', comment: '评价', master: '法师', temple: '寺院' }[t || ''] || t || '-'
}

function evidenceUrls(raw: string): string[] {
  return safeJsonParse<string[]>(raw, [])
}

async function loadData() {
  loading.value = true
  try {
    const res = await getAuditReports(query)
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

function open(row: Report) {
  dialog.row = row
  dialog.handleResult = 'handled'
  dialog.remark = ''
  dialog.visible = true
}

async function confirm() {
  if (!dialog.row) return
  dialog.loading = true
  try {
    await handleAuditReport(dialog.row.id, {
      handlerId: String(auth.userInfo?.userId || '0'),
      handleResult: dialog.handleResult,
      remark: dialog.remark
    })
    ElMessage.success('处理成功')
    dialog.visible = false
    loadData()
  } finally {
    dialog.loading = false
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
.evidence-img {
  width: 36px;
  height: 36px;
  border-radius: var(--radius-sm);
  margin-right: 4px;
}
.evidence-img--fallback {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg-tertiary);
  color: var(--color-text-tertiary);
  font-size: 11px;
}
.muted {
  color: var(--color-text-tertiary);
  font-size: 12px;
}
.dialog-info p {
  margin: 4px 0;
  color: var(--color-text-secondary);
  font-size: 13px;
}
.dialog-info span {
  color: var(--color-text-tertiary);
}
</style>
