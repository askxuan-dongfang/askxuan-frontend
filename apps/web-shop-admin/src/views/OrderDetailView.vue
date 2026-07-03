<script setup lang="ts">
// 订单详情（含发货操作）
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import { orderApi } from '@/api/order'
import { formatMoney, formatDateTime, orderStatusLabel, orderStatusType } from '@/utils/format'
import type { ShopOrder } from '@/types'

const route = useRoute()
const router = useRouter()

const orderId = computed(() => Number(route.params.id) || 0)
const loading = ref(false)
const detail = ref<ShopOrder | null>(null)

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
    detail.value = await orderApi.detail(orderId.value)
  } finally {
    loading.value = false
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
      await orderApi.ship(orderId.value, { ...shipForm })
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
    <PageHeader title="订单详情" subtitle="查看订单明细、物流信息，并执行发货">
      <template #extra>
        <el-button @click="router.push('/orders')">返回列表</el-button>
        <el-button
          v-if="detail && detail.status === 'paid'"
          type="primary"
          @click="openShipDialog"
        >
          <el-icon><Promotion /></el-icon>
          发货
        </el-button>
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
          <el-descriptions-item label="订单状态">
            <el-tag :type="orderStatusType(detail.status)" effect="light" round size="small">
              {{ orderStatusLabel(detail.status) }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="下单时间">{{ formatDateTime(detail.createTime) }}</el-descriptions-item>
          <el-descriptions-item label="收货地址 ID">{{ detail.addressId }}</el-descriptions-item>
          <el-descriptions-item label="订单总额">{{ formatMoney(detail.totalAmount) }}</el-descriptions-item>
          <el-descriptions-item label="实付金额">
            <span class="price">{{ formatMoney(detail.payAmount) }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="备注">{{ detail.note || '-' }}</el-descriptions-item>
        </el-descriptions>
      </div>

      <!-- 商品明细 -->
      <div class="df-card section-card">
        <div class="section-title">商品明细</div>
        <el-table :data="detail.items || []" style="width: 100%" empty-text="无商品">
          <el-table-column label="商品" prop="productName" min-width="200" />
          <el-table-column label="规格" prop="skuSpec" width="160" />
          <el-table-column label="单价" width="120">
            <template #default="{ row }">{{ formatMoney(row.price) }}</template>
          </el-table-column>
          <el-table-column label="数量" prop="quantity" width="100" />
          <el-table-column label="小计" width="120">
            <template #default="{ row }">{{ formatMoney(row.price * row.quantity) }}</template>
          </el-table-column>
        </el-table>
      </div>

      <!-- 物流信息 -->
      <div class="df-card section-card">
        <div class="section-title">物流信息</div>
        <template v-if="detail.logistics && detail.logistics.trackingNo">
          <el-descriptions :column="2" border>
            <el-descriptions-item label="快递公司">{{ detail.logistics.expressCompany }}</el-descriptions-item>
            <el-descriptions-item label="运单号">{{ detail.logistics.trackingNo }}</el-descriptions-item>
            <el-descriptions-item label="发货时间">{{ formatDateTime(detail.logistics.shipTime) }}</el-descriptions-item>
          </el-descriptions>
        </template>
        <el-empty v-else description="暂无物流信息" :image-size="80" />
      </div>
    </template>

    <!-- 发货弹窗 -->
    <el-dialog v-model="shipDialogVisible" title="订单发货" width="480px">
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
</style>
