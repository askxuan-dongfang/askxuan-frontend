<template>
  <div class="dfx-page">
    <PageHeader title="评论审核" subtitle="大师广场评论先审后显">
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

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy">
        <div class="ax-page-feedback__title">评论审核任务加载失败</div>
        <div class="ax-page-feedback__description">当前结果不是“暂无评论”，请重试后再处理。</div>
      </div>
      <el-button :loading="loading" @click="loadData">重新加载</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable class="desktop-table" :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="评论ID" prop="id" width="190" show-overflow-tooltip />
        <el-table-column label="帖子ID" prop="postId" width="190" show-overflow-tooltip />
        <el-table-column label="用户" prop="userId" width="130" />
        <el-table-column label="评论内容" prop="content" min-width="280" show-overflow-tooltip />
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
      <MobileTaskList v-model:page="query.page" :items="list" :loading="loading" :total="total" :size="query.size" @change="loadData">
        <template #item="{ item: row }">
          <article class="mobile-task-card">
            <div class="mobile-task-card__head"><strong>{{ row.content || '无评论正文' }}</strong><StatusTag :status="row.status" /></div>
            <div class="mobile-task-card__meta">用户 {{ row.userId }} · 帖子 {{ row.postId }}</div>
            <div class="mobile-task-card__meta">提交于 {{ formatDate(row.createTime) }}</div>
            <div class="mobile-task-card__foot">
              <span>{{ row.auditRemark || (row.status === 'pending' ? '等待人工审核' : '未填写审核备注') }}</span>
              <AuditAction v-if="row.status === 'pending'" :on-confirm="(a, r) => doAudit(row, a, r)" @success="loadData" />
              <b v-else>已处理</b>
            </div>
          </article>
        </template>
      </MobileTaskList>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import MobileTaskList from '@/components/MobileTaskList.vue'
import StatusTag from '@/components/StatusTag.vue'
import AuditAction from '@/components/AuditAction.vue'
import { getCommunityComments, reviewCommunityComment } from '@/api/community'
import { useAuthStore } from '@/stores/auth'
import { formatDate } from '@/utils/format'
import type { CommunityComment } from '@/api/community'

const auth = useAuthStore()
const loading = ref(false)
const loadError = ref(false)
const list = ref<CommunityComment[]>([])
const total = ref(0)
const query = reactive({ status: '', page: 1, size: 20 })

async function loadData() {
  loading.value = true
  loadError.value = false
  try {
    const res = await getCommunityComments(query)
    list.value = res.list || []
    total.value = res.total || 0
  } catch {
    loadError.value = true
  } finally {
    loading.value = false
  }
}

function onSearch() {
  query.page = 1
  loadData()
}

async function doAudit(row: CommunityComment, action: 'approve' | 'reject', remark: string) {
  const auditorId = String(auth.userInfo?.userId || '0')
  await reviewCommunityComment(row.id, action, { auditorId, remark })
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
