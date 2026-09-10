<template>
  <div class="dfx-page">
    <PageHeader title="帖子审核" subtitle="大师广场图文与视频内容">
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
        <div class="ax-page-feedback__title">帖子审核任务加载失败</div>
        <div class="ax-page-feedback__description">当前结果不可用于判断是否存在待审核内容。</div>
      </div>
      <el-button :loading="loading" @click="loadData">重新加载</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable class="desktop-table" :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="帖子ID" prop="id" width="190" show-overflow-tooltip />
        <el-table-column label="法师" prop="masterId" width="110" />
        <el-table-column label="类型" width="90">
          <template #default="{ row }">{{ row.type === 'video' ? '视频' : '图文' }}</template>
        </el-table-column>
        <el-table-column label="内容" min-width="280">
          <template #default="{ row }">
            <strong>{{ row.title }}</strong>
            <div class="content-preview">{{ row.content || '-' }}</div>
          </template>
        </el-table-column>
        <el-table-column label="互动" width="120">
          <template #default="{ row }">{{ row.likeCount }} 赞 · {{ row.commentCount }} 评</template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="审核备注" prop="auditRemark" min-width="140" show-overflow-tooltip />
        <el-table-column label="提交时间" width="170">
          <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="210" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="preview = row">查看内容</el-button>
            <AuditAction v-if="row.status === 'pending'" :on-confirm="(a, r) => doAudit(row, a, r)" @success="loadData" />
            <span v-else class="muted">已处理</span>
          </template>
        </el-table-column>
      </DataTable>
      <MobileTaskList v-model:page="query.page" :items="list" :loading="loading" :total="total" :size="query.size" @change="loadData">
        <template #item="{ item: row }">
          <article class="mobile-task-card">
            <div class="mobile-task-card__head"><strong>{{ row.title || '未命名帖子' }}</strong><StatusTag :status="row.status" /></div>
            <div class="mobile-task-card__meta">{{ row.type === 'video' ? '视频' : '图文' }} · 法师 {{ row.masterId }} · {{ row.likeCount || 0 }} 赞 / {{ row.commentCount || 0 }} 评</div>
            <div class="mobile-task-card__meta">{{ row.content || '暂无内容摘要' }}</div>
            <div class="mobile-task-card__foot">
              <span>{{ formatDate(row.createTime) }}</span>
              <el-button link type="primary" @click="preview = row">查看内容</el-button>
              <AuditAction v-if="row.status === 'pending'" :on-confirm="(a, r) => doAudit(row, a, r)" @success="loadData" />
              <b v-else>已处理</b>
            </div>
          </article>
        </template>
      </MobileTaskList>
    </div>
    <el-dialog :model-value="!!preview" title="内容审核预览" width="min(720px, 94vw)" destroy-on-close @close="preview = null">
      <article v-if="preview" class="community-review-preview">
        <h2>{{ preview.title }}</h2><p class="review-meta">{{ preview.type === 'video' ? '视频' : '图文' }} · {{ preview.assets?.length || 0 }} 份素材 · 作者 {{ preview.masterId }}</p>
        <div class="review-media"><template v-for="asset in preview.assets || []" :key="asset.id">
          <video v-if="asset.assetType === 'video' && asset.url" :src="asset.url" :poster="preview.coverUrl || asset.coverUrl" controls preload="metadata" />
          <el-image v-else-if="asset.url" :src="asset.url" :preview-src-list="(preview.assets || []).filter(a => a.assetType === 'image' && a.url).map(a => a.url!)" fit="contain" preview-teleported />
          <el-alert v-else title="素材暂不可预览，请核对后再审核" type="warning" :closable="false" />
        </template></div>
        <p class="review-body">{{ preview.content }}</p><el-alert v-if="preview.auditRemark" :title="preview.auditRemark" type="info" :closable="false" />
      </article>
      <template #footer><el-button @click="preview = null">关闭预览</el-button><AuditAction v-if="preview?.status === 'pending'" :on-confirm="(a, r) => doAudit(preview!, a, r)" @success="preview = null; loadData()" /></template>
    </el-dialog>
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
import { getCommunityPosts, reviewCommunityPost } from '@/api/community'
import { useAuthStore } from '@/stores/auth'
import { formatDate } from '@/utils/format'
import type { CommunityPost } from '@/api/community'

const preview = ref<CommunityPost | null>(null)
const auth = useAuthStore()
const loading = ref(false)
const loadError = ref(false)
const list = ref<CommunityPost[]>([])
const total = ref(0)
const query = reactive({ status: '', page: 1, size: 20 })

async function loadData() {
  loading.value = true
  loadError.value = false
  try {
    const res = await getCommunityPosts(query)
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

async function doAudit(row: CommunityPost, action: 'approve' | 'reject', remark: string) {
  const auditorId = String(auth.userInfo?.userId || '0')
  await reviewCommunityPost(row.id, action, { auditorId, remark })
}

onMounted(loadData)
</script>

<style scoped>
.community-review-preview h2 { margin-top: 0; line-height: 1.5; }
.review-meta { color: var(--el-text-color-secondary); font-size: 12px; }
.review-media { display: grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap: 10px; }
.review-media video { grid-column: 1 / -1; width: 100%; max-height: 440px; background: #111; }
.review-media .el-image { height: 240px; border-radius: 8px; background: var(--el-fill-color-light); }
.review-body { white-space: pre-wrap; overflow-wrap: anywhere; line-height: 1.85; margin-top: 20px; }
@media(max-width:500px) { .review-media { grid-template-columns: minmax(0,1fr); } }
.filter-bar {
  display: flex;
  gap: 12px;
  padding: 16px;
  margin-bottom: 16px;
}
.table-wrap {
  padding: 16px;
}
.content-preview {
  margin-top: 4px;
  color: var(--color-text-secondary);
  font-size: var(--type-size-label);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.muted {
  color: var(--color-text-tertiary);
  font-size: var(--type-size-label);
}
</style>
