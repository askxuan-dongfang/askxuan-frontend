<template>
  <div class="dfx-page">
    <PageHeader title="优惠券管理" subtitle="优惠券发放与状态管理">
      <template #actions>
        <el-button type="primary" :icon="Plus" @click="openCreate">新建优惠券</el-button>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.type" placeholder="券类型" clearable style="width: 150px" @change="onSearch">
        <el-option v-for="o in couponTypes" :key="o.value" :label="o.label" :value="o.value" />
      </el-select>
      <el-select v-model="query.status" placeholder="状态" clearable style="width: 140px" @change="onSearch">
        <el-option label="启用" value="enabled" />
        <el-option label="禁用" value="disabled" />
      </el-select>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="券名称" prop="name" min-width="160" />
        <el-table-column label="券号" prop="couponNo" width="160" />
        <el-table-column label="类型" width="110">
          <template #default="{ row }">{{ typeText(row.type) }}</template>
        </el-table-column>
        <el-table-column label="面值/折扣" width="120" align="right">
          <template #default="{ row }">
            <span class="amount">{{ row.type === 'discount' ? `${row.value}折` : `¥${row.value}` }}</span>
          </template>
        </el-table-column>
        <el-table-column label="门槛" width="100" align="right">
          <template #default="{ row }">{{ row.minAmount ? `满${row.minAmount}` : '无门槛' }}</template>
        </el-table-column>
        <el-table-column label="领取情况" width="130">
          <template #default="{ row }">
            <el-progress :percentage="progress(row)" :stroke-width="8" :status="progress(row) >= 100 ? 'success' : ''" />
            <div class="muted">{{ row.receivedCount }} / {{ row.totalCount }}</div>
          </template>
        </el-table-column>
        <el-table-column label="有效期" width="200">
          <template #default="{ row }">{{ row.startTime }} ~ {{ row.endTime }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="操作" width="170" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button link :type="row.status === 'enabled' ? 'warning' : 'success'" @click="toggle(row)">
              {{ row.status === 'enabled' ? '禁用' : '启用' }}
            </el-button>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <el-dialog v-model="dialog.visible" :title="dialog.isEdit ? '编辑优惠券' : '新建优惠券'" width="540px">
      <el-form :model="dialog.form" label-width="100px">
        <el-form-item label="券名称">
          <el-input v-model="dialog.form.name" placeholder="请输入券名称" />
        </el-form-item>
        <el-form-item label="券类型">
          <el-select v-model="dialog.form.type" style="width: 100%">
            <el-option v-for="o in couponTypes" :key="o.value" :label="o.label" :value="o.value" />
          </el-select>
        </el-form-item>
        <el-form-item :label="dialog.form.type === 'discount' ? '折扣（1-10）' : '面值（元）'">
          <el-input-number v-model="dialog.form.value" :min="0" :precision="2" controls-position="right" style="width: 100%" />
        </el-form-item>
        <el-form-item label="使用门槛">
          <el-input-number v-model="dialog.form.minAmount" :min="0" :precision="2" controls-position="right" style="width: 100%" placeholder="0 表示无门槛" />
        </el-form-item>
        <el-form-item label="发放总量">
          <el-input-number v-model="dialog.form.totalCount" :min="0" controls-position="right" style="width: 100%" />
        </el-form-item>
        <el-form-item label="有效期">
          <el-date-picker v-model="dialog.dateRange" type="datetimerange" range-separator="至" start-placeholder="开始" end-placeholder="结束" value-format="YYYY-MM-DD HH:mm:ss" style="width: 100%" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialog.visible = false">取消</el-button>
        <el-button type="primary" :loading="dialog.loading" @click="submit">确认</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Plus, Refresh } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getCoupons, createCoupon, updateCoupon } from '@/api/marketing'
import type { Coupon } from '@/types'

const couponTypes = [
  { label: '满减券', value: 'full_reduce' },
  { label: '折扣券', value: 'discount' },
  { label: '新人券', value: 'new_user' },
  { label: '品类券', value: 'category' }
]

const loading = ref(false)
const list = ref<Coupon[]>([])
const total = ref(0)
const query = reactive({ type: '', status: '', page: 1, size: 20 })

const dialog = reactive({
  visible: false,
  loading: false,
  isEdit: false,
  editId: 0,
  form: { name: '', type: 'full_reduce', value: 0, minAmount: 0, totalCount: 100 },
  dateRange: null as [string, string] | null
})

function typeText(t: string) {
  return couponTypes.find((o) => o.value === t)?.label || t
}

function progress(row: Coupon) {
  if (!row.totalCount) return 0
  return Math.min(100, Math.round((row.receivedCount / row.totalCount) * 100))
}

async function loadData() {
  loading.value = true
  try {
    const res = await getCoupons(query)
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

function openCreate() {
  dialog.isEdit = false
  dialog.editId = 0
  dialog.form = { name: '', type: 'full_reduce', value: 0, minAmount: 0, totalCount: 100 }
  dialog.dateRange = null
  dialog.visible = true
}

function openEdit(row: Coupon) {
  dialog.isEdit = true
  dialog.editId = row.id
  dialog.form = { name: row.name, type: row.type, value: row.value, minAmount: row.minAmount, totalCount: row.totalCount }
  dialog.dateRange = [row.startTime, row.endTime]
  dialog.visible = true
}

async function submit() {
  if (!dialog.form.name || !dialog.dateRange) {
    ElMessage.warning('请填写完整信息')
    return
  }
  dialog.loading = true
  try {
    const payload = { ...dialog.form, startTime: dialog.dateRange[0], endTime: dialog.dateRange[1] }
    if (dialog.isEdit) await updateCoupon(dialog.editId, payload)
    else await createCoupon(payload)
    ElMessage.success(dialog.isEdit ? '已更新' : '已创建')
    dialog.visible = false
    loadData()
  } finally {
    dialog.loading = false
  }
}

async function toggle(row: Coupon) {
  const status = row.status === 'enabled' ? 'disabled' : 'enabled'
  await updateCoupon(row.id, { status })
  ElMessage.success('状态已更新')
  loadData()
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
.amount {
  color: var(--color-accent);
  font-weight: 700;
}
.muted {
  color: var(--color-text-tertiary);
  font-size: 12px;
  margin-top: 4px;
}
</style>
