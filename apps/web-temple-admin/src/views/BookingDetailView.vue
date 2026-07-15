<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { ArrowLeft, Check, Close, ChatLineSquare } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getBooking, getBookingStatusLog, getBookingReview, confirmBooking, cancelBooking, replyBookingReview } from '@/api/booking'
import { formatMoney, formatDate, bookingStatusText, parseImages, isBookingTerminal } from '@/utils/format'
import type { Booking, BookingStatusLog, BookingReview } from '@/types'

const route = useRoute()
const router = useRouter()
const bookingId = computed(() => (route.params.id as string) || '')

const loading = ref(false)
const acting = ref(false)
const booking = ref<Booking | null>(null)
const logs = ref<BookingStatusLog[]>([])
const review = ref<BookingReview | null>(null)
const replyText = ref('')
const replying = ref(false)

const canConfirm = computed(() => booking.value?.status === 'pending')
const canCancel = computed(() => !!booking.value && !isBookingTerminal(booking.value.status))

async function load() {
  loading.value = true
  try {
    const b = await getBooking(bookingId.value)
    booking.value = b
    // 并行加载状态日志与评价（评价仅在已评价时加载）
    const tasks: Promise<unknown>[] = [getBookingStatusLog(bookingId.value).then((r) => (logs.value = r.list || []))]
    if (b.status === 'reviewed') {
      tasks.push(
        getBookingReview(bookingId.value)
          .then((r) => (review.value = r))
          .catch(() => (review.value = null))
      )
    } else {
      review.value = null
    }
    await Promise.allSettled(tasks)
  } finally {
    loading.value = false
  }
}

function doConfirm() {
  ElMessageBox.prompt('请输入确认备注（可选）', '确认预约', {
    confirmButtonText: '确认',
    cancelButtonText: '取消',
    inputPlaceholder: '备注'
  })
    .then(async ({ value }) => {
      acting.value = true
      try {
        await confirmBooking(bookingId.value, value)
        ElMessage.success('预约已确认')
        load()
      } finally {
        acting.value = false
      }
    })
    .catch(() => {})
}

function doCancel() {
  ElMessageBox.prompt('请输入取消原因', '取消预约', {
    confirmButtonText: '确认取消',
    cancelButtonText: '返回',
    inputPlaceholder: '取消原因',
    inputType: 'textarea'
  })
    .then(async ({ value }) => {
      acting.value = true
      try {
        await cancelBooking(bookingId.value, value)
        ElMessage.success('预约已取消')
        load()
      } finally {
        acting.value = false
      }
    })
    .catch(() => {})
}

async function submitReply() {
  if (!replyText.value.trim()) {
    ElMessage.warning('请输入回复内容')
    return
  }
  replying.value = true
  try {
    const r = await replyBookingReview(bookingId.value, replyText.value.trim())
    review.value = r
    replyText.value = ''
    ElMessage.success('回复已发送')
  } finally {
    replying.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="df-page" v-loading="loading">
    <PageHeader title="预约详情" :subtitle="booking?.id">
      <el-button :icon="ArrowLeft" @click="router.back()">返回</el-button>
      <el-button v-if="canConfirm" type="primary" :icon="Check" :loading="acting" @click="doConfirm">确认预约</el-button>
      <el-button v-if="canCancel" type="danger" plain :icon="Close" :loading="acting" @click="doCancel">取消预约</el-button>
    </PageHeader>

    <div class="detail-grid" v-if="booking">
      <div class="detail-left">
        <div class="df-card section">
          <div class="section-title">预约信息</div>
          <el-descriptions :column="2" border>
            <el-descriptions-item label="预约号">{{ booking.id }}</el-descriptions-item>
            <el-descriptions-item label="状态">
              <StatusTag :status="booking.status" kind="booking" />
            </el-descriptions-item>
            <el-descriptions-item label="服务项目">{{ booking.serviceName }}</el-descriptions-item>
            <el-descriptions-item label="法师">{{ booking.masterName || '-' }}</el-descriptions-item>
            <el-descriptions-item label="预约日期">{{ booking.bookingDate }}</el-descriptions-item>
            <el-descriptions-item label="时段">{{ booking.timeSlot }}</el-descriptions-item>
            <el-descriptions-item label="功德金">
              <span class="price">{{ formatMoney(booking.meritMoney) }}</span>
              <el-tag v-if="booking.meritMoneyTier" size="small" effect="plain" class="ml-2">{{ booking.meritMoneyTier }}</el-tag>
            </el-descriptions-item>
			<el-descriptions-item label="服务费"><span class="price">{{ formatMoney(booking.serviceFee) }}</span></el-descriptions-item>
			<el-descriptions-item label="合计"><span class="price">{{ formatMoney(booking.totalFee) }}</span></el-descriptions-item>
			<el-descriptions-item label="支付状态">
			  <el-tag :type="booking.paymentStatus === 'success' ? 'success' : 'warning'">{{ booking.paymentStatus }}</el-tag>
			</el-descriptions-item>
			<el-descriptions-item label="支付单号">{{ booking.paymentNo || '-' }}</el-descriptions-item>
            <el-descriptions-item label="提交时间">{{ formatDate(booking.createdAt) }}</el-descriptions-item>
            <el-descriptions-item label="用户ID" :span="2">{{ booking.userId }}</el-descriptions-item>
            <el-descriptions-item label="备注" :span="2">{{ booking.note || '-' }}</el-descriptions-item>
          </el-descriptions>
        </div>

        <!-- 评价 -->
        <div class="df-card section" v-if="booking.status === 'reviewed'">
          <div class="section-title">信众评价</div>
          <div v-if="!review" class="muted">暂无评价数据</div>
          <div v-else>
            <div class="review-head">
              <el-rate :model-value="review.rating" disabled />
              <span class="muted">{{ formatDate(review.createTime) }}</span>
            </div>
            <div class="review-content">{{ review.content }}</div>
            <div class="review-images" v-if="parseImages(review.images).length">
              <el-image
                v-for="(img, i) in parseImages(review.images)"
                :key="i"
                :src="img"
                :preview-src-list="parseImages(review.images)"
                fit="cover"
                class="review-img"
                :preview-teleported="true"
              />
            </div>

            <div class="reply-block" v-if="review.masterReply">
              <div class="reply-label">法师回复：</div>
              <div class="reply-text">{{ review.masterReply }}</div>
            </div>
            <div class="reply-block" v-else>
              <div class="reply-label">回复评价：</div>
              <el-input v-model="replyText" type="textarea" :rows="3" placeholder="请输入回复内容" />
              <div class="reply-action">
                <el-button type="primary" :icon="ChatLineSquare" :loading="replying" @click="submitReply">发送回复</el-button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 状态流转 -->
      <div class="detail-right">
        <div class="df-card section">
          <div class="section-title">状态流转</div>
          <el-timeline v-if="logs.length">
            <el-timeline-item
              v-for="log in logs"
              :key="log.id"
              :timestamp="formatDate(log.createTime)"
              placement="top"
              :type="log.toStatus === 'cancelled' ? 'danger' : 'primary'"
            >
              <div class="log-line">
                <span class="log-from">{{ bookingStatusText(log.fromStatus) }}</span>
                <span class="log-arrow">→</span>
                <span class="log-to">{{ bookingStatusText(log.toStatus) }}</span>
              </div>
              <div class="log-meta">
                <el-tag size="small" effect="plain">{{ log.operatorType }}</el-tag>
                <span v-if="log.remark" class="log-remark">{{ log.remark }}</span>
              </div>
            </el-timeline-item>
          </el-timeline>
          <el-empty v-else description="暂无流转记录" :image-size="60" />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.detail-grid {
  display: grid;
  grid-template-columns: 1.6fr 1fr;
  gap: 16px;
  align-items: start;
}
.section {
  padding: 18px 20px;
  margin-bottom: 16px;
}
.section-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 15px;
  font-weight: 600;
  color: #2a1e1a;
  margin-bottom: 14px;
}
.price {
  color: #c45a3c;
  font-weight: 600;
}
.ml-2 {
  margin-left: 8px;
}
.muted {
  color: #8a7a6a;
  font-size: 13px;
}
.review-head {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 8px;
}
.review-content {
  color: #2a1e1a;
  line-height: 1.6;
  margin-bottom: 10px;
}
.review-images {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.review-img {
  width: 80px;
  height: 80px;
  border-radius: 8px;
  border: 1px solid #e8e0d8;
}
.reply-block {
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px dashed #e8e0d8;
}
.reply-label {
  font-size: 13px;
  color: #6a5a4a;
  margin-bottom: 8px;
}
.reply-text {
  color: #2a1e1a;
  background: #faf6f0;
  padding: 10px 12px;
  border-radius: 8px;
}
.reply-action {
  margin-top: 10px;
  text-align: right;
}
.log-line {
  font-size: 14px;
}
.log-from {
  color: #8a7a6a;
}
.log-arrow {
  margin: 0 6px;
  color: #c8a96e;
}
.log-to {
  color: #c45a3c;
  font-weight: 600;
}
.log-meta {
  margin-top: 4px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.log-remark {
  font-size: 12px;
  color: #8a7a6a;
}
</style>
