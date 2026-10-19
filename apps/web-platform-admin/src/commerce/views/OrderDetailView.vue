<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

// 订单详情（含发货操作）
import { ref, reactive, computed, onMounted } from "vue";
import { useRoute, useRouter } from "vue-router";
import { type FormInstance, type FormRules,  } from 'element-plus';
import PageHeader from "@/components/PageHeader.vue";
import { orderApi } from "@/commerce/api/order";
import {
  formatMoney,
  formatDateTime,
  orderStatusLabel,
  orderStatusType,
} from "@/commerce/utils/format";
import type { ShopOrder } from "@/commerce/types";

const route = useRoute();
const router = useRouter();

const orderId = computed(() => Number(route.params.id) || 0);
const loading = ref(false);
const detail = ref<ShopOrder | null>(null);

// 发货弹窗
const shipDialogVisible = ref(false);
const shipFormRef = ref<FormInstance>();
const shipSaving = ref(false);
const shipForm = reactive({
  expressCompany: "",
  trackingNo: "",
});
const shipRules: FormRules = {
  expressCompany: [
    { required: true, message: "请选择快递公司", trigger: "change" },
  ],
  trackingNo: [{ required: true, message: "请输入运单号", trigger: "blur" }],
};
const expressOptions = [
  "顺丰速运",
  "中通快递",
  "圆通速递",
  "韵达快递",
  "申通快递",
  "京东物流",
  "EMS",
];

async function loadDetail() {
  loading.value = true;
  try {
    detail.value = await orderApi.detail(orderId.value);
  } finally {
    loading.value = false;
  }
}

function openShipDialog() {
  shipForm.expressCompany = "";
  shipForm.trackingNo = "";
  shipDialogVisible.value = true;
}

async function handleShip() {
  if (!shipFormRef.value) return;
  await shipFormRef.value.validate(async (valid) => {
    if (!valid) return;
    try {
      await ElMessageBox.confirm(
        (uiText("确认将订单「") + String((detail.value?.orderNo || orderId.value)) + uiText("」标记为已发货？运单号 ") + String(shipForm.trackingNo) + uiText(" 将展示给用户，提交后不能在本页面撤回。")),
        uiText("确认发货"),
        {
          type: "warning",
          confirmButtonText: uiText("确认发货"),
          cancelButtonText: uiText("返回核对"),
        },
      );
    } catch {
      return;
    }
    shipSaving.value = true;
    try {
      await orderApi.ship(orderId.value, { ...shipForm });
      ElMessage.success(uiText("发货成功"));
      shipDialogVisible.value = false;
      loadDetail();
    } finally {
      shipSaving.value = false;
    }
  });
}

onMounted(() => {
  loadDetail();
});
</script>

<template>
  <div class="page-wrap" v-loading="loading">
    <PageHeader :title='$t("订单详情")' :subtitle='$t("查看订单明细、物流信息，并执行发货")'>
      <template #extra>
        <el-button @click="router.push('/commerce/orders')">{{ $t("返回列表") }}</el-button>
        <el-button
          v-if="detail && detail.status === 'paid'"
          type="primary"
          @click="openShipDialog"
        >
          <el-icon><Promotion /></el-icon>{{ $t(" 发货 ") }}</el-button>
      </template>
    </PageHeader>

    <template v-if="detail">
      <el-alert
        v-if="detail.isExperience"
        :title='$t("体验订单：仅模拟支付、发货和售后，不实际扣款或发货，不发放消费积分，不计入商城销售收入。")'
        type="warning"
        :closable="false"
        show-icon
      />
      <!-- 基本信息 -->
      <div class="df-card section-card">
        <div class="section-title">{{ $t("基本信息") }}</div>
        <el-descriptions :column="3" border>
          <el-descriptions-item :label='$t("订单号")'>{{
            $t(detail.orderNo)
          }}</el-descriptions-item>
          <el-descriptions-item :label='$t("订单 ID")'>{{
            $t(detail.id)
          }}</el-descriptions-item>
          <el-descriptions-item :label='$t("用户 ID")'>{{
            $t(detail.userId)
          }}</el-descriptions-item>
          <el-descriptions-item :label='$t("订单状态")'>
            <el-tag
              :type="orderStatusType(detail.status)"
              effect="light"
              round
              size="small"
            >
              {{ $t(orderStatusLabel(detail.status)) }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item :label='$t("下单时间")'>{{
            $t(formatDateTime(detail.createTime))
          }}</el-descriptions-item>
          <el-descriptions-item :label='$t("收货地址 ID")'>{{
            $t(detail.addressId)
          }}</el-descriptions-item>
          <el-descriptions-item :label='$t("订单总额")'>{{
            $t(formatMoney(detail.totalAmount))
          }}</el-descriptions-item>
          <el-descriptions-item :label='$t("实付金额")'>
            <span class="price">{{ $t(formatMoney(detail.payAmount)) }}</span>
          </el-descriptions-item>
          <el-descriptions-item :label='$t("备注")'>{{
            $t((detail.note || "-"))
          }}</el-descriptions-item>
        </el-descriptions>
      </div>

      <!-- 商品明细 -->
      <div class="df-card section-card">
        <div class="section-title">{{ $t("商品明细") }}</div>
        <el-table
          :data="detail.items || []"
          style="width: 100%"
          :empty-text='$t("无商品")'
        >
          <el-table-column :label='$t("商品")' prop="productName" min-width="200" />
          <el-table-column :label='$t("规格")' prop="skuSpec" width="160" />
          <el-table-column :label='$t("单价")' width="120">
            <template #default="{ row }">{{ $t(formatMoney(row.price)) }}</template>
          </el-table-column>
          <el-table-column :label='$t("数量")' prop="quantity" width="100" />
          <el-table-column :label='$t("小计")' width="120">
            <template #default="{ row }">{{
              $t(formatMoney(row.price * row.quantity))
            }}</template>
          </el-table-column>
        </el-table>
      </div>

      <!-- 物流信息 -->
      <div class="df-card section-card">
        <div class="section-title">{{ $t("物流信息") }}</div>
        <template v-if="detail.logistics && detail.logistics.trackingNo">
          <el-descriptions :column="2" border>
            <el-descriptions-item :label='$t("快递公司")'>{{
              $t(detail.logistics.expressCompany)
            }}</el-descriptions-item>
            <el-descriptions-item :label='$t("运单号")'>{{
              $t(detail.logistics.trackingNo)
            }}</el-descriptions-item>
            <el-descriptions-item :label='$t("发货时间")'>{{
              $t(formatDateTime(detail.logistics.shipTime))
            }}</el-descriptions-item>
          </el-descriptions>
        </template>
        <el-empty v-else :description='$t("暂无物流信息")' :image-size="80" />
      </div>
    </template>

    <!-- 发货弹窗 -->
    <el-dialog
      v-model="shipDialogVisible"
      :title="$t((detail?.isExperience ? $t('模拟订单发货') : $t('订单发货')))"
      width="480px"
     append-to-body>
      <el-alert
        :title="$t(
          (detail?.isExperience ? $t('仅记录模拟物流，请勿实际寄出商品。') : $t('发货后订单进入待收货状态，快递公司和运单号会同步给用户。'))
        )"
        type="warning"
        :closable="false"
        show-icon
      />
      <el-form
        ref="shipFormRef"
        :model="shipForm"
        :rules="shipRules"
        label-width="100px"
      >
        <el-form-item :label='$t("快递公司")' prop="expressCompany">
          <el-select
            :allow-create="detail?.isExperience"
            filterable
            v-model="shipForm.expressCompany"
            :placeholder='$t("请选择快递公司")'
            style="width: 100%"
          >
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
        <el-button @click="shipDialogVisible = false">{{ $t("取消") }}</el-button>
        <el-button type="primary" :loading="shipSaving" @click="handleShip"
          >{{ $t("确认发货") }}</el-button
        >
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
</style>
