<script setup lang="ts">
// DIY 订单详情（含审核 / 制作完成 / 发货操作）
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import { diyOrderApi } from '@/api/diyOrder'
import { formatMoney, formatDateTime } from '@/utils/format'
import type { DiyOrder } from '@/types'

const route = useRoute()
const router = useRouter()

const orderId = computed(() => Number(route.params.id) || 0)
const loading = ref(false)
const detail = ref<DiyOrder | null>(null)

// 发货弹窗
const shipDialogVisible = ref(false)
const shipFormRef = ref<FormInstance>()
const shipSaving = ref(false)
const shipForm = reactive({
  expressCompany: '',
  trackingNo: ''
})
const shipRules: FormRules = {
  expressCompany: [{ required: true, message: '请选择快递公司', trigger: 'change' }],
  trackingNo: [{ required: true, message: '请输入运单号', trigger: 'blur' }]
}
const expressOptions = ['顺丰速运', '中通快递', '圆通速递', '韵达快递', '申通快递', '京东物流', 'EMS']

async function loadDetail() {
  loading.value = true
  try {
    detail.value = await diyOrderApi.detail(orderId.value)
  } finally {
    loading.value = false
  }
}

async function handleReview(action: 'approve' | 'reject') {
  const tip = action === 'approve' ? '通过' : '拒绝'
  try {
    let reason = ''
    if (action === 'reject') {
      const res = await ElMessageBox.prompt('请输入拒绝原因', '拒绝审核', {
        confirmButtonText: '确认',
        cancelButtonText: '取消',
        inputType: 'textarea'
      })
      reason = res.value || ''
    } else {
      await ElMessageBox.confirm(`确认${tip}该 DIY 订单审核？`, '提示', {
        confirmButtonText: '确认',
        cancelButtonText: '取消',
        type: 'warning'
      })
    }
    await diyOrderApi.review(orderId.value, action, reason)
    ElMessage.success(`审核已${tip}`)
    loadDetail()
  } catch {
    // 取消
  }
}

async function handleMakeComplete() {
  try {
    await ElMessageBox.confirm('确认该 DIY 订单制作完成？', '提示', {
      confirmButtonText: '确认',
      cancelButtonText: '取消',
      type: 'warning'
    })
    await diyOrderApi.makeComplete(orderId.value)
    ElMessage.success('已标记制作完成')
    loadDetail()
  } catch {
    // 取消
  }
}

function openShipDialog() {
  shipForm.expressCompany = ''
  shipForm.trackingNo = ''
  shipDialogVisible.value = true
}

async function handleShip() {
  if (!shipFormRef.value) return
  await shipFormRef.value.validate(async (valid) => {
    if (!valid) return
    shipSaving.value = true
    try {
      await diyOrderApi.ship(orderId.value, { ...shipForm })
      ElMessage.success('发货成功')
      shipDialogVisible.value = false
      loadDetail()
    } finally {
      shipSaving.value = false
    }
  })
}

onMounted(() => {
  loadDetail()
})
</script>

<template>
  <div class="page-wrap" v-loading="loading">
    <PageHeader title="DIY 订单详情" subtitle="查看 DIY 订单、审核 / 制作完成 / 发货">
      <template #extra>
        <el-button @click="router.push('/diy-orders')">返回列表</el-button>
        <template v-if="detail">
          <el-button
            v-if="detail.status === 'in_review'"
            type="success"
            @click="handleReview('approve')"
          >通过审核</el-button>
          <el-button
            v-if="detail.status === 'in_review'"
            type="danger"
            @click="handleReview('reject')"
          >拒绝</el-button>
          <el-button
            v-if="detail.status === 'making'"
            type="warning"
            @click="handleMakeComplete"
          >制作完成</el-button>
          <el-button
            v-if="detail.status === 'paid' || detail.status === 'approved'"
            type="primary"
            @click="openShipDialog"
          >
            <el-icon><Promotion /></el-icon>
            发货
          </el-button>
        </template>
      </template>
    </PageHeader>

    <template v-if="detail">
      <!-- 基本信息 -->
      <div class="df-card section-card">
        <div class="section-title">基本信息</div>
        <el-descriptions :column="3" border>
          <el-descriptions-item label="订单号">{{ detail.orderNo }}</el-descriptions-item>
          <el-descriptions-item label="订单 ID">{{ detail.id }}</el-descriptions-item>
          <el-descriptions-item label="用户 ID">{{ detail.userId }}</el-descriptions-item>
          <el-descriptions-item label="设计 ID">{{ detail.designId }}</el-descriptions-item>
          <el-descriptions-item label="订单状态">{{ detail.status }}</el-descriptions-item>
          <el-descriptions-item label="下单时间">{{ formatDateTime(detail.createTime) }}</el-descriptions-item>
          <el-descriptions-item label="材料费">{{ formatMoney(detail.materialFee) }}</el-descriptions-item>
          <el-descriptions-item label="加持费">{{ formatMoney(detail.blessFee) }}</el-descriptions-item>
          <el-descriptions-item label="合计">
            <span class="price">{{ formatMoney(detail.totalFee) }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="收货地址 ID">{{ detail.addressId }}</el-descriptions-item>
        </el-descriptions>
      </div>

      <!-- 材料明细 -->
      <div class="df-card section-card">
        <div class="section-title">材料明细</div>
        <el-table :data="detail.items || []" style="width: 100%" empty-text="无材料">
          <el-table-column label="材料" prop="materialName" min-width="200" />
          <el-table-column label="规格" prop="spec" width="160" />
          <el-table-column label="单价" width="120">
            <template #default="{ row }">{{ formatMoney(row.unitPrice) }}</template>
          </el-table-column>
          <el-table-column label="数量" prop="quantity" width="100" />
          <el-table-column label="子类型" prop="subtype" width="120" />
          <el-table-column label="小计" width="120">
            <template #default="{ row }">{{ formatMoney(row.unitPrice * row.quantity) }}</template>
          </el-table-column>
        </el-table>
      </div>

      <!-- 加持任务 -->
      <div class="df-card section-card">
        <div class="section-title">加持任务</div>
        <template v-if="detail.blessingTask && detail.blessingTask.taskNo">
          <el-descriptions :column="2" border>
            <el-descriptions-item label="任务编号">{{ detail.blessingTask.taskNo }}</el-descriptions-item>
            <el-descriptions-item label="DIY 订单号">{{ detail.blessingTask.diyOrderNo }}</el-descriptions-item>
            <el-descriptions-item label="寺院编码">{{ detail.blessingTask.templeCode }}</el-descriptions-item>
            <el-descriptions-item label="法师编码">{{ detail.blessingTask.masterCode }}</el-descriptions-item>
            <el-descriptions-item label="任务状态">{{ detail.blessingTask.status }}</el-descriptions-item>
            <el-descriptions-item label="分派时间">{{ formatDateTime(detail.blessingTask.assignTime) }}</el-descriptions-item>
            <el-descriptions-item label="完成时间">{{ formatDateTime(detail.blessingTask.completeTime) }}</el-descriptions-item>
          </el-descriptions>
          <div v-if="detail.blessingTask.certificateUrls?.length" class="cert-list">
            <div class="cert-title">证书图片：</div>
            <div class="cert-imgs">
              <el-image
                v-for="(url, idx) in detail.blessingTask.certificateUrls"
                :key="idx"
                :src="url"
                :preview-src-list="detail.blessingTask.certificateUrls"
                :initial-index="idx"
                fit="cover"
                class="cert-img"
              />
            </div>
          </div>
        </template>
        <el-empty v-else description="暂无加持任务" :image-size="80" />
      </div>
    </template>

    <!-- 发货弹窗 -->
    <el-dialog v-model="shipDialogVisible" title="DIY 订单发货" width="480px">
      <el-form
        ref="shipFormRef"
        :model="shipForm"
        :rules="shipRules"
        label-width="100px"
      >
        <el-form-item label="快递公司" prop="expressCompany">
          <el-select v-model="shipForm.expressCompany" placeholder="请选择快递公司" style="width: 100%">
            <el-option
              v-for="e in expressOptions"
              :key="e"
              :label="e"
              :value="e"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="运单号" prop="trackingNo">
          <el-input v-model="shipForm.trackingNo" placeholder="请输入运单号" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="shipDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="shipSaving" @click="handleShip">确认发货</el-button>
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
.cert-list {
  margin-top: 16px;
}
.cert-title {
  font-size: 13px;
  color: var(--text-medium);
  margin-bottom: 8px;
}
.cert-imgs {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.cert-img {
  width: 96px;
  height: 96px;
  border-radius: 8px;
  border: 1px solid var(--border);
}
</style>
