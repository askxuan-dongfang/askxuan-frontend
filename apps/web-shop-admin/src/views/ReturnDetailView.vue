<script setup lang="ts">
// 退货详情（含审核 / 退款操作）
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import { orderApi } from '@/api/order'
import { formatMoney, formatDateTime, returnStatusLabel, returnStatusType } from '@/utils/format'
import type { ReturnOrder } from '@/types'

const route = useRoute()
const router = useRouter()

const returnId = computed(() => Number(route.params.id) || 0)
const loading = ref(false)
const detail = ref<ReturnOrder | null>(null)

// 退款弹窗
const refundDialogVisible = ref(false)
const refundSaving = ref(false)
const refundAmount = ref(0)

async function loadDetail() {
  loading.value = true
  try {
    // 后端未提供单独的退货详情接口，从列表中查找
    const res = await orderApi.returnList({ page: 1, size: 200 })
    detail.value = (res.list || []).find((r) => r.id === returnId.value) || null
    if (detail.value) {
      refundAmount.value = detail.value.refundAmount
    }
  } finally {
    loading.value = false
  }
}

async function handleReview(action: 'approve' | 'reject') {
  const tip = action === 'approve' ? '通过' : '拒绝'
  try {
    let reason = ''
    if (action === 'reject') {
      const res = await ElMessageBox.prompt('请输入拒绝原因', '拒绝退货', {
        confirmButtonText: '确认',
        cancelButtonText: '取消',
        inputType: 'textarea'
      })
      reason = res.value || ''
    } else {
      await ElMessageBox.confirm(`确认${tip}该退货申请？`, '提示', {
        confirmButtonText: '确认',
        cancelButtonText: '取消',
        type: 'warning'
      })
    }
    await orderApi.returnReview(returnId.value, action, reason)
    ElMessage.success(`审核已${tip}`)
    loadDetail()
  } catch {
    // 取消
  }
}

function openRefundDialog() {
  refundAmount.value = detail.value?.refundAmount || 0
  refundDialogVisible.value = true
}

async function handleRefund() {
  if (refundAmount.value <= 0) {
    ElMessage.warning('退款金额需大于 0')
    return
  }
  refundSaving.value = true
  try {
    await orderApi.returnRefund(returnId.value, refundAmount.value)
    ElMessage.success('退款成功')
    refundDialogVisible.value = false
    loadDetail()
  } finally {
    refundSaving.value = false
  }
}

onMounted(() => {
  loadDetail()
})
</script>

<template>
  <div class="page-wrap" v-loading="loading">
    <PageHeader title="退货详情" subtitle="查看退货申请、执行审核与退款">
      <template #extra>
        <el-button @click="router.push('/returns')">返回列表</el-button>
        <template v-if="detail">
          <el-button
            v-if="detail.status === 'pending_review'"
            type="success"
            @click="handleReview('approve')"
          >通过审核</el-button>
          <el-button
            v-if="detail.status === 'pending_review'"
            type="danger"
            @click="handleReview('reject')"
          >拒绝</el-button>
          <el-button
            v-if="detail.status === 'approved' || detail.status === 'return_received' || detail.status === 'refunding'"
            type="primary"
            @click="openRefundDialog"
          >退款</el-button>
        </template>
      </template>
    </PageHeader>

    <template v-if="detail">
      <div class="df-card section-card">
        <div class="section-title">退货信息</div>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="退货单号">{{ detail.returnNo }}</el-descriptions-item>
          <el-descriptions-item label="退货 ID">{{ detail.id }}</el-descriptions-item>
          <el-descriptions-item label="原订单 ID">{{ detail.orderId }}</el-descriptions-item>
          <el-descriptions-item label="类型">
            <el-tag size="small" :type="detail.type === 'exchange' ? 'warning' : 'info'">
              {{ detail.type === 'exchange' ? '换货' : '退货' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="returnStatusType(detail.status)" effect="light" round size="small">
              {{ returnStatusLabel(detail.status) }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="退款金额">
            <span class="price">{{ formatMoney(detail.refundAmount) }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="申请时间">{{ formatDateTime(detail.createTime) }}</el-descriptions-item>
        </el-descriptions>
      </div>

      <div class="df-card section-card">
        <div class="section-title">退货原因</div>
        <div class="reason-box">{{ detail.reason || '未填写' }}</div>
      </div>
    </template>
    <el-empty v-else description="未找到退货单" />

    <!-- 退款弹窗 -->
    <el-dialog v-model="refundDialogVisible" title="退款处理" width="420px">
      <el-form label-width="100px">
        <el-form-item label="退款金额">
          <el-input-number v-model="refundAmount" :min="0" :precision="2" :step="1" controls-position="right" />
          <span class="form-tip">元</span>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="refundDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="refundSaving" @click="handleRefund">确认退款</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.section-card {
  padding: 0 24px 24px;
  margin-bottom: 16px;
}
.section-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-dark);
  padding: 16px 0;
  border-bottom: 1px solid var(--border);
  margin-bottom: 16px;
}
.price {
  color: var(--primary);
  font-weight: 600;
}
.reason-box {
  padding: 12px 16px;
  background: var(--el-fill-color-light);
  border-radius: 8px;
  color: var(--text-medium);
  line-height: 1.8;
  min-height: 60px;
}
.form-tip {
  margin-left: 8px;
  font-size: 12px;
  color: var(--text-light);
}
</style>
