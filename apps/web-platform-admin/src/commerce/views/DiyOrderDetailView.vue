<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

// DIY 订单详情（含审核 / 制作完成 / 发货操作）
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { type FormInstance, type FormRules } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import { diyOrderApi } from '@/commerce/api/diyOrder'
import { getStatusMeta } from '@askxuan/domain-status'
import { formatMoney, formatDateTime } from '@/commerce/utils/format'
import type { DiyOrder } from '@/commerce/types'

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
      const res = await ElMessageBox.prompt(uiText('拒绝后停止制作并恢复材料库存，已付款订单将提交原路退款。请输入拒绝原因。'), uiText('拒绝审核'), {
        confirmButtonText: uiText('确认'),
        cancelButtonText: uiText('取消'),
        inputType: 'textarea'
      })
      reason = res.value || ''
    } else {
      await ElMessageBox.confirm(uiText('确认通过该 DIY 订单审核？通过后将锁定当前设计快照并进入制作流程。'), uiText('DIY 审核确认'), {
        confirmButtonText: uiText('确认通过'),
        cancelButtonText: uiText('返回核对'),
        type: 'warning'
      })
    }
    await diyOrderApi.review(orderId.value, action, reason)
    ElMessage.success((uiText("审核已") + String(tip) + uiText("")))
    loadDetail()
  } catch {
    // 取消
  }
}

async function handleMakeComplete() {
  try {
    await ElMessageBox.confirm(uiText('确认该 DIY 订单制作完成？选购了开光服务的订单将交给所选寺院或法师；未选购的订单进入待发货。'), uiText('制作完成确认'), {
      confirmButtonText: uiText('确认完成'),
      cancelButtonText: uiText('返回核对'),
      type: 'warning'
    })
    await diyOrderApi.makeComplete(orderId.value)
    ElMessage.success(uiText('已标记制作完成'))
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
    try {
      await ElMessageBox.confirm(
        (uiText("确认将 DIY 订单「") + String((detail.value?.orderNo || orderId.value)) + uiText("」标记为已发货？运单号 ") + String(shipForm.trackingNo) + uiText(" 将展示给用户。")),
        uiText('确认发货'),
        { type: 'warning', confirmButtonText: uiText('确认发货'), cancelButtonText: uiText('返回核对') }
      )
    } catch {
      return
    }
    shipSaving.value = true
    try {
      await diyOrderApi.ship(orderId.value, { ...shipForm })
      ElMessage.success(uiText('发货成功'))
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
    <PageHeader :title='$t("DIY 订单详情")' :subtitle='$t("查看 DIY 订单、审核 / 制作完成 / 发货")'>
      <template #extra>
        <el-button @click="router.push('/commerce/diy-orders')">{{ $t("返回列表") }}</el-button>
        <template v-if="detail">
          <el-button
            v-if="detail.status === 'pending_review'"
            type="success"
            @click="handleReview('approve')"
          >{{ $t("通过审核") }}</el-button>
          <el-button
            v-if="detail.status === 'pending_review'"
            type="danger"
            @click="handleReview('reject')"
          >{{ $t("拒绝") }}</el-button>
          <el-button
            v-if="detail.status === 'in_making'"
            type="warning"
            @click="handleMakeComplete"
          >{{ $t("制作完成") }}</el-button>
          <el-button
            v-if="detail.status === 'awaiting_shipment' || detail.status === 'in_return'"
            type="primary"
            @click="openShipDialog"
          >
            <el-icon><Promotion /></el-icon>{{ $t(" 发货 ") }}</el-button>
        </template>
      </template>
    </PageHeader>

    <template v-if="detail">
      <el-alert v-if="detail.logistics" :title="$t(((($t('物流：') + detail.logistics.expressCompany) + ' · ') + detail.logistics.trackingNo))" type="success" :closable="false"/>
      <!-- 基本信息 -->
      <div class="df-card section-card">
        <div class="section-title">{{ $t("基本信息") }}</div>
        <el-descriptions :column="3" border>
          <el-descriptions-item :label='$t("订单号")'>{{ $t(detail.orderNo) }}</el-descriptions-item>
          <el-descriptions-item :label='$t("订单 ID")'>{{ $t(detail.id) }}</el-descriptions-item>
          <el-descriptions-item :label='$t("用户 ID")'>{{ $t(detail.userId) }}</el-descriptions-item>
          <el-descriptions-item :label='$t("设计 ID")'>{{ $t(detail.designId) }}</el-descriptions-item>
          <el-descriptions-item :label='$t("支付 / 退款")'>{{$t(getStatusMeta('payment',detail.paymentStatus||'pending').label)}}</el-descriptions-item><el-descriptions-item :label='$t("订单状态")'>{{$t(getStatusMeta('diyOrder',detail.status).label)}}</el-descriptions-item>
          <el-descriptions-item :label='$t("下单时间")'>{{ $t(formatDateTime(detail.createTime)) }}</el-descriptions-item>
          <el-descriptions-item :label='$t("材料费")'>{{ $t(formatMoney(detail.materialFee)) }}</el-descriptions-item>
          <el-descriptions-item :label='$t("加持费")'>{{ $t(formatMoney(detail.blessFee)) }}</el-descriptions-item>
          <el-descriptions-item :label='$t("合计")'>
            <span class="price">{{ $t(formatMoney(detail.totalFee)) }}</span>
          </el-descriptions-item>
          <el-descriptions-item :label='$t("收货地址 ID")'>{{ $t(detail.addressId) }}</el-descriptions-item>
        </el-descriptions>
      </div>

      <!-- 材料明细 -->
      <div class="df-card section-card">
        <div class="section-title">{{ $t("材料明细") }}</div>
        <el-table :data="detail.items || []" style="width: 100%" :empty-text='$t("无材料")'>
          <el-table-column :label='$t("材料")' prop="materialName" min-width="200" />
          <el-table-column :label='$t("规格")' prop="spec" width="160" />
          <el-table-column :label='$t("单价")' width="120">
            <template #default="{ row }">{{ $t(formatMoney(row.unitPrice)) }}</template>
          </el-table-column>
          <el-table-column :label='$t("数量")' prop="quantity" width="100" />
          <el-table-column :label='$t("子类型")' prop="subtype" width="120" />
          <el-table-column :label='$t("小计")' width="120">
            <template #default="{ row }">{{ $t(formatMoney(row.unitPrice * row.quantity)) }}</template>
          </el-table-column>
        </el-table>
      </div>

      <!-- 加持任务 -->
      <div class="df-card section-card">
        <div class="section-title">{{ $t("加持任务") }}</div>
        <template v-if="detail.blessingTask && detail.blessingTask.taskNo">
          <el-descriptions :column="2" border>
            <el-descriptions-item :label='$t("任务编号")'>{{ $t(detail.blessingTask.taskNo) }}</el-descriptions-item>
            <el-descriptions-item :label='$t("DIY 订单号")'>{{ $t(detail.blessingTask.diyOrderNo) }}</el-descriptions-item>
            <el-descriptions-item :label='$t("寺院编码")'>{{ $t(detail.blessingTask.templeCode) }}</el-descriptions-item>
            <el-descriptions-item :label='$t("法师编码")'>{{ $t(detail.blessingTask.masterCode) }}</el-descriptions-item>
            <el-descriptions-item :label='$t("任务状态")'>{{ $t(detail.blessingTask.status) }}</el-descriptions-item>
            <el-descriptions-item :label='$t("分派时间")'>{{ $t(formatDateTime(detail.blessingTask.assignTime)) }}</el-descriptions-item>
            <el-descriptions-item :label='$t("完成时间")'>{{ $t(formatDateTime(detail.blessingTask.completeTime)) }}</el-descriptions-item>
          </el-descriptions>
          <div v-if="detail.blessingTask.certificateUrls?.length" class="cert-list">
            <div class="cert-title">{{ $t("证书图片：") }}</div>
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
        <el-empty v-else :description='$t("暂无加持任务")' :image-size="80" />
      </div>
    </template>

    <!-- 发货弹窗 -->
    <el-dialog v-model="shipDialogVisible" :title='$t("DIY 订单发货")' width="480px" append-to-body>
      <el-alert :title='$t("发货后订单进入待收货状态，物流信息会同步给用户且不可在本页面撤回。")' type="warning" :closable="false" show-icon />
      <el-form
        ref="shipFormRef"
        :model="shipForm"
        :rules="shipRules"
        label-width="100px"
      >
        <el-form-item :label='$t("快递公司")' prop="expressCompany">
          <el-select v-model="shipForm.expressCompany" :placeholder='$t("请选择快递公司")' style="width: 100%">
            <el-option
              v-for="e in expressOptions"
              :key="e"
              :label="$t(e)"
              :value="e"
            />
          </el-select>
        </el-form-item>
        <el-form-item :label='$t("运单号")' prop="trackingNo">
          <el-input v-model="shipForm.trackingNo" :placeholder='$t("请输入运单号")' />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="shipDialogVisible = false" data-quiet-action="cancel">{{ $t("取消") }}</el-button>
        <el-button type="primary" :loading="shipSaving" @click="handleShip">{{ $t("确认发货") }}</el-button>
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
  font-size: var(--type-size-control);
  font-weight: var(--type-weight-semibold);
  color: var(--text-dark);
  padding: 16px 0;
  border-bottom: 1px solid var(--border);
  margin-bottom: 16px;
}
.price {
  color: var(--primary);
  font-weight: var(--type-weight-semibold);
}
.cert-list {
  margin-top: 16px;
}
.cert-title {
  font-size: var(--type-size-label);
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
