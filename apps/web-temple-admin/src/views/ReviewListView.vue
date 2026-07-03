<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh, ChatLineSquare, Search } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { listReviews, replyReview } from '@/api/review'
import { useAuthStore } from '@/stores/auth'
import { formatDate, parseImages } from '@/utils/format'
import type { Review } from '@/types'

const auth = useAuthStore()

const loading = ref(false)
const list = ref<Review[]>([])
const total = ref(0)
const query = reactive({ status: '', rating: undefined as number | undefined, page: 1, size: 20 })

const replyVisible = ref(false)
const replyContent = ref('')
const replying = ref(false)
const currentReview = ref<Review | null>(null)

async function load() {
  loading.value = true
  try {
    const r = await listReviews({
      targetType: 'booking',
      status: query.status || undefined,
      rating: query.rating,
      page: query.page,
      size: query.size
    })
    list.value = r.list || []
    total.value = r.total || 0
  } finally {
    loading.value = false
  }
}

function onSearch() {
  query.page = 1
  load()
}
function onPageChange(p: { page: number; size: number }) {
  query.page = p.page
  query.size = p.size
  load()
}

function openReply(row: Review) {
  currentReview.value = row
  replyContent.value = ''
  replyVisible.value = true
}

async function submitReply() {
  if (!currentReview.value) return
  if (!replyContent.value.trim()) {
    ElMessage.warning('请输入回复内容')
    return
  }
  replying.value = true
  try {
    await replyReview(currentReview.value.id, String(auth.userInfo?.userId ?? '0'), replyContent.value.trim())
    ElMessage.success('回复成功')
    replyVisible.value = false
    load()
  } finally {
    replying.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="df-page">
    <PageHeader title="评价管理" subtitle="查看信众评价并回复">
      <el-button :icon="Refresh" @click="load">刷新</el-button>
    </PageHeader>

    <div class="df-card list-card">
      <div class="filter-bar">
        <el-select v-model="query.status" placeholder="状态筛选" clearable style="width: 140px" @change="onSearch">
          <el-option label="正常" value="normal" />
          <el-option label="已隐藏" value="hidden" />
        </el-select>
        <el-select v-model="query.rating" placeholder="评分筛选" clearable style="width: 140px" @change="onSearch">
          <el-option :label="'5 星'" :value="5" />
          <el-option :label="'4 星'" :value="4" />
          <el-option :label="'3 星'" :value="3" />
          <el-option :label="'2 星'" :value="2" />
          <el-option :label="'1 星'" :value="1" />
        </el-select>
        <el-button :icon="Search" type="primary" plain @click="onSearch">查询</el-button>
      </div>

      <DataTable
        :data="list"
        :loading="loading"
        :total="total"
        :page="query.page"
        :size="query.size"
        row-key="id"
        @change="onPageChange"
      >
        <el-table-column prop="reviewNo" label="评价编号" width="160" />
        <el-table-column label="评价内容" min-width="240">
          <template #default="{ row }">
            <div class="review-content-cell">{{ row.content }}</div>
            <div class="review-imgs" v-if="parseImages(row.images).length">
              <el-image
                v-for="(img, i) in parseImages(row.images).slice(0, 4)"
                :key="i"
                :src="img"
                fit="cover"
                class="mini-img"
                :preview-src-list="parseImages(row.images)"
                :preview-teleported="true"
              />
            </div>
          </template>
        </el-table-column>
        <el-table-column label="评分" width="150">
          <template #default="{ row }"><el-rate :model-value="row.rating" disabled size="small" /></template>
        </el-table-column>
        <el-table-column prop="targetId" label="关联预约" width="140" />
        <el-table-column label="状态" width="90">
          <template #default="{ row }"><StatusTag :status="row.status" kind="review" /></template>
        </el-table-column>
        <el-table-column label="时间" width="160">
          <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" :icon="ChatLineSquare" @click="openReply(row as Review)">回复</el-button>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <el-dialog v-model="replyVisible" title="回复评价" width="520px">
      <div v-if="currentReview" class="reply-dialog">
        <el-rate :model-value="currentReview.rating" disabled />
        <div class="reply-dialog-content">{{ currentReview.content }}</div>
        <el-input v-model="replyContent" type="textarea" :rows="4" placeholder="请输入回复内容" maxlength="300" show-word-limit />
      </div>
      <template #footer>
        <el-button @click="replyVisible = false">取消</el-button>
        <el-button type="primary" :loading="replying" @click="submitReply">发送回复</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.list-card {
  padding: 18px 20px;
}
.filter-bar {
  display: flex;
  gap: 10px;
  margin-bottom: 16px;
}
.review-content-cell {
  color: #2a1e1a;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.review-imgs {
  display: flex;
  gap: 6px;
  margin-top: 6px;
}
.mini-img {
  width: 44px;
  height: 44px;
  border-radius: 6px;
  border: 1px solid #e8e0d8;
}
.reply-dialog-content {
  background: #faf6f0;
  padding: 10px 12px;
  border-radius: 8px;
  color: #2a1e1a;
  margin: 10px 0;
  line-height: 1.5;
}
</style>
