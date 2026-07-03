<template>
  <div class="dfx-page">
    <PageHeader title="寺院审核" subtitle="寺院入驻申请两阶段审核（初审 / 终审）">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.status" placeholder="审核状态" clearable style="width: 160px" @change="onSearch">
        <el-option label="待初审" value="pending" />
        <el-option label="初审通过" value="first_pass" />
        <el-option label="终审通过" value="final_pass" />
        <el-option label="已驳回" value="rejected" />
      </el-select>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="申请编号" prop="id" width="90" />
        <el-table-column label="寺院编码" prop="templeCode" width="120" />
        <el-table-column label="申请人" prop="applicantName" width="120" />
        <el-table-column label="联系电话" prop="contactPhone" width="140" />
        <el-table-column label="资质材料" min-width="160">
          <template #default="{ row }">
            <el-image
              v-for="(url, i) in row.certUrls"
              :key="i"
              :src="url"
              fit="cover"
              class="cert-img"
              :preview-src-list="row.certUrls"
              :initial-index="i"
              preview-teleported
            >
              <template #error><div class="cert-img cert-img--fallback">证</div></template>
            </el-image>
            <span v-if="!row.certUrls?.length">-</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="120">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="申请时间" width="170">
          <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="240" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 'pending'">
              <el-button link type="success" @click="open(row, 'first-pass')">初审通过</el-button>
              <el-button link type="danger" @click="open(row, 'reject')">驳回</el-button>
            </template>
            <template v-else-if="row.status === 'first_pass'">
              <el-button link type="success" @click="open(row, 'final-pass')">终审通过</el-button>
              <el-button link type="danger" @click="open(row, 'reject')">驳回</el-button>
            </template>
            <span v-else class="muted">已处理</span>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <!-- 审核弹窗 -->
    <el-dialog v-model="dialog.visible" :title="dialogTitle" width="460px">
      <div class="dialog-info">
        <p><span>寺院编码：</span>{{ dialog.row?.templeCode }}</p>
        <p><span>申请人：</span>{{ dialog.row?.applicantName }}</p>
      </div>
      <el-form label-position="top">
        <el-form-item :label="dialog.action === 'reject' ? '驳回原因（必填）' : '审核备注（选填）'">
          <el-input v-model="dialog.remark" type="textarea" :rows="4" placeholder="请输入" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialog.visible = false">取消</el-button>
        <el-button :type="dialog.action === 'reject' ? 'danger' : 'success'" :loading="dialog.loading" @click="confirm">确认</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getTempleAudits, templeAuditFirstPass, templeAuditFinalPass, templeAuditReject } from '@/api/temple'
import { formatDate } from '@/utils/format'
import type { TempleAudit } from '@/types'

const loading = ref(false)
const list = ref<TempleAudit[]>([])
const total = ref(0)
const query = reactive({ status: '', page: 1, size: 20 })

const dialog = reactive({
  visible: false,
  loading: false,
  row: null as TempleAudit | null,
  action: 'first-pass' as 'first-pass' | 'final-pass' | 'reject',
  remark: ''
})

const dialogTitle = computed(() => {
  return { 'first-pass': '初审通过', 'final-pass': '终审通过', reject: '审核驳回' }[dialog.action]
})

async function loadData() {
  loading.value = true
  try {
    const res = await getTempleAudits(query)
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

function open(row: TempleAudit, action: 'first-pass' | 'final-pass' | 'reject') {
  dialog.row = row
  dialog.action = action
  dialog.remark = ''
  dialog.visible = true
}

async function confirm() {
  if (dialog.action === 'reject' && !dialog.remark.trim()) {
    ElMessage.warning('请输入驳回原因')
    return
  }
  if (!dialog.row) return
  dialog.loading = true
  try {
    const id = dialog.row.id
    if (dialog.action === 'first-pass') await templeAuditFirstPass(id, dialog.remark)
    else if (dialog.action === 'final-pass') await templeAuditFinalPass(id, dialog.remark)
    else await templeAuditReject(id, dialog.remark)
    ElMessage.success('操作成功')
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
.dialog-info p {
  margin: 4px 0;
  color: var(--color-text-secondary);
  font-size: 13px;
}
.dialog-info span {
  color: var(--color-text-tertiary);
}
</style>
