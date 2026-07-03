<script setup lang="ts">
// 物流管理 - 快递公司 / 运费模板 / 物流追踪（Tab 切换）
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { logisticsApi } from '@/api/logistics'
import { formatDateTime } from '@/utils/format'
import type { ExpressCompany, FreightTemplate, TrackQueryResp } from '@/types'

const activeTab = ref('express')

/* ===== 快递公司 ===== */
const expressLoading = ref(false)
const expressList = ref<ExpressCompany[]>([])
const expressTotal = ref(0)
const expressQuery = reactive({ name: '', code: '', status: '', page: 1, size: 20 })

const expressDialogVisible = ref(false)
const expressDialogTitle = ref('')
const expressFormRef = ref<FormInstance>()
const expressSaving = ref(false)
const expressForm = reactive({
  id: undefined as number | undefined,
  code: '',
  name: '',
  logoUrl: '',
  customerService: '',
  sort: 0,
  status: 'enabled' as 'enabled' | 'disabled'
})
const expressRules: FormRules = {
  code: [{ required: true, message: '请输入快递编码', trigger: 'blur' }],
  name: [{ required: true, message: '请输入快递公司名称', trigger: 'blur' }]
}

async function loadExpress() {
  expressLoading.value = true
  try {
    const res = await logisticsApi.expressList(expressQuery)
    expressList.value = res.list || []
    expressTotal.value = res.total || 0
  } finally {
    expressLoading.value = false
  }
}

function openExpressCreate() {
  expressDialogTitle.value = '新建快递公司'
  Object.assign(expressForm, {
    id: undefined,
    code: '',
    name: '',
    logoUrl: '',
    customerService: '',
    sort: 0,
    status: 'enabled'
  })
  expressDialogVisible.value = true
}

function openExpressEdit(row: any) {
  expressDialogTitle.value = '编辑快递公司'
  Object.assign(expressForm, {
    id: row.id,
    code: row.code,
    name: row.name,
    logoUrl: row.logoUrl,
    customerService: row.customerService,
    sort: row.sort,
    status: row.status as 'enabled' | 'disabled'
  })
  expressDialogVisible.value = true
}

async function handleExpressSubmit() {
  if (!expressFormRef.value) return
  await expressFormRef.value.validate(async (valid) => {
    if (!valid) return
    expressSaving.value = true
    try {
      const { id, ...payload } = expressForm
      if (id) {
        await logisticsApi.expressUpdate(id, payload)
        ElMessage.success('更新成功')
      } else {
        await logisticsApi.expressCreate({
          code: payload.code,
          name: payload.name,
          logoUrl: payload.logoUrl,
          customerService: payload.customerService,
          sort: payload.sort
        })
        ElMessage.success('创建成功')
      }
      expressDialogVisible.value = false
      loadExpress()
    } finally {
      expressSaving.value = false
    }
  })
}

async function handleExpressStatusToggle(row: any) {
  const next = row.status === 'enabled' ? 'disabled' : 'enabled'
  try {
    await logisticsApi.expressUpdate(row.id, { status: next })
    ElMessage.success('状态已更新')
    loadExpress()
  } catch {
    // 忽略
  }
}

/* ===== 运费模板 ===== */
const freightLoading = ref(false)
const freightList = ref<FreightTemplate[]>([])
const freightTotal = ref(0)
const freightQuery = reactive({ name: '', type: '', status: '', page: 1, size: 20 })

const freightDialogVisible = ref(false)
const freightDialogTitle = ref('')
const freightFormRef = ref<FormInstance>()
const freightSaving = ref(false)
const freightForm = reactive({
  id: undefined as number | undefined,
  name: '',
  type: 'by_piece' as 'by_weight' | 'by_piece',
  freeShipping: 0,
  config: '',
  status: 'enabled' as 'enabled' | 'disabled'
})
const freightRules: FormRules = {
  name: [{ required: true, message: '请输入模板名称', trigger: 'blur' }],
  type: [{ required: true, message: '请选择计费方式', trigger: 'change' }],
  config: [{ required: true, message: '请输入计费规则（JSON）', trigger: 'blur' }]
}

async function loadFreight() {
  freightLoading.value = true
  try {
    const res = await logisticsApi.freightTemplateList(freightQuery)
    freightList.value = res.list || []
    freightTotal.value = res.total || 0
  } finally {
    freightLoading.value = false
  }
}

function openFreightCreate() {
  freightDialogTitle.value = '新建运费模板'
  Object.assign(freightForm, {
    id: undefined,
    name: '',
    type: 'by_piece',
    freeShipping: 0,
    config: '{"first":1,"firstFee":10,"next":1,"nextFee":2}',
    status: 'enabled'
  })
  freightDialogVisible.value = true
}

function openFreightEdit(row: any) {
  freightDialogTitle.value = '编辑运费模板'
  Object.assign(freightForm, {
    id: row.id,
    name: row.name,
    type: row.type as 'by_weight' | 'by_piece',
    freeShipping: row.freeShipping,
    config: row.config,
    status: row.status as 'enabled' | 'disabled'
  })
  freightDialogVisible.value = true
}

async function handleFreightSubmit() {
  if (!freightFormRef.value) return
  await freightFormRef.value.validate(async (valid) => {
    if (!valid) return
    freightSaving.value = true
    try {
      const { id, ...payload } = freightForm
      if (id) {
        await logisticsApi.freightTemplateUpdate(id, payload)
        ElMessage.success('更新成功')
      } else {
        await logisticsApi.freightTemplateCreate({
          name: payload.name,
          type: payload.type,
          freeShipping: payload.freeShipping,
          config: payload.config
        })
        ElMessage.success('创建成功')
      }
      freightDialogVisible.value = false
      loadFreight()
    } finally {
      freightSaving.value = false
    }
  })
}

async function handleFreightStatusToggle(row: any) {
  const next = row.status === 'enabled' ? 'disabled' : 'enabled'
  try {
    await logisticsApi.freightTemplateUpdate(row.id, { status: next })
    ElMessage.success('状态已更新')
    loadFreight()
  } catch {
    // 忽略
  }
}

/* ===== 物流追踪 ===== */
const trackLoading = ref(false)
const trackingNo = ref('')
const trackResult = ref<TrackQueryResp | null>(null)

async function handleTrackQuery() {
  if (!trackingNo.value.trim()) {
    ElMessage.warning('请输入运单号')
    return
  }
  trackLoading.value = true
  try {
    trackResult.value = await logisticsApi.trackQuery(trackingNo.value.trim())
  } catch {
    trackResult.value = null
  } finally {
    trackLoading.value = false
  }
}

async function handleBatchSync() {
  try {
    await ElMessageBox.confirm('确认批量同步所有非终态物流记录？', '提示', {
      confirmButtonText: '同步',
      cancelButtonText: '取消',
      type: 'warning'
    })
    const res = await logisticsApi.tracksBatchSync()
    ElMessage.success(`同步完成：成功 ${res.success} / 失败 ${res.failed} / 共 ${res.total}`)
  } catch {
    // 取消
  }
}

onMounted(() => {
  loadExpress()
})
</script>

<template>
  <div class="page-wrap">
    <PageHeader title="物流管理" subtitle="快递公司 / 运费模板 / 物流追踪">
      <template #extra>
        <el-button type="primary" plain @click="handleBatchSync">批量同步物流</el-button>
      </template>
    </PageHeader>

    <div class="df-card">
      <el-tabs v-model="activeTab" @tab-change="(name: any) => name === 'freight' && loadFreight()">
        <!-- 快递公司 -->
        <el-tab-pane label="快递公司" name="express">
          <div class="filter-bar">
            <el-form inline @submit.prevent="loadExpress">
              <el-form-item label="名称">
                <el-input v-model="expressQuery.name" clearable style="width: 180px" @keyup.enter="loadExpress" />
              </el-form-item>
              <el-form-item label="编码">
                <el-input v-model="expressQuery.code" clearable style="width: 140px" @keyup.enter="loadExpress" />
              </el-form-item>
              <el-form-item>
                <el-button type="primary" @click="loadExpress">查询</el-button>
                <el-button type="success" @click="openExpressCreate">新建</el-button>
              </el-form-item>
            </el-form>
          </div>
          <el-table v-loading="expressLoading" :data="expressList" style="width: 100%" empty-text="暂无快递公司">
            <el-table-column label="编码" prop="code" width="120" />
            <el-table-column label="名称" prop="name" min-width="160" />
            <el-table-column label="客服电话" prop="customerService" width="160" />
            <el-table-column label="排序" prop="sort" width="80" />
            <el-table-column label="状态" width="100">
              <template #default="{ row }">
                <StatusTag :status="row.status" domain="enabled" />
              </template>
            </el-table-column>
            <el-table-column label="创建时间" prop="createTime" width="180" />
            <el-table-column label="操作" width="200" fixed="right">
              <template #default="{ row }">
                <el-button text type="primary" size="small" @click="openExpressEdit(row)">编辑</el-button>
                <el-button
                  text
                  :type="row.status === 'enabled' ? 'warning' : 'success'"
                  size="small"
                  @click="handleExpressStatusToggle(row)"
                >{{ row.status === 'enabled' ? '禁用' : '启用' }}</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <!-- 运费模板 -->
        <el-tab-pane label="运费模板" name="freight">
          <div class="filter-bar">
            <el-form inline @submit.prevent="loadFreight">
              <el-form-item label="名称">
                <el-input v-model="freightQuery.name" clearable style="width: 180px" @keyup.enter="loadFreight" />
              </el-form-item>
              <el-form-item label="计费方式">
                <el-select v-model="freightQuery.type" clearable style="width: 140px">
                  <el-option label="按件" value="by_piece" />
                  <el-option label="按重量" value="by_weight" />
                </el-select>
              </el-form-item>
              <el-form-item>
                <el-button type="primary" @click="loadFreight">查询</el-button>
                <el-button type="success" @click="openFreightCreate">新建</el-button>
              </el-form-item>
            </el-form>
          </div>
          <el-table v-loading="freightLoading" :data="freightList" style="width: 100%" empty-text="暂无运费模板">
            <el-table-column label="名称" prop="name" min-width="180" />
            <el-table-column label="计费方式" width="120">
              <template #default="{ row }">{{ row.type === 'by_weight' ? '按重量' : '按件' }}</template>
            </el-table-column>
            <el-table-column label="是否包邮" width="100">
              <template #default="{ row }">{{ row.freeShipping ? '是' : '否' }}</template>
            </el-table-column>
            <el-table-column label="计费规则" prop="config" min-width="240" show-overflow-tooltip />
            <el-table-column label="状态" width="100">
              <template #default="{ row }">
                <StatusTag :status="row.status" domain="enabled" />
              </template>
            </el-table-column>
            <el-table-column label="更新时间" prop="updateTime" width="180" />
            <el-table-column label="操作" width="200" fixed="right">
              <template #default="{ row }">
                <el-button text type="primary" size="small" @click="openFreightEdit(row)">编辑</el-button>
                <el-button
                  text
                  :type="row.status === 'enabled' ? 'warning' : 'success'"
                  size="small"
                  @click="handleFreightStatusToggle(row)"
                >{{ row.status === 'enabled' ? '禁用' : '启用' }}</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <!-- 物流追踪 -->
        <el-tab-pane label="物流追踪" name="track">
          <div class="filter-bar">
            <el-form inline @submit.prevent="handleTrackQuery">
              <el-form-item label="运单号">
                <el-input v-model="trackingNo" placeholder="请输入运单号" clearable style="width: 280px" @keyup.enter="handleTrackQuery" />
              </el-form-item>
              <el-form-item>
                <el-button type="primary" :loading="trackLoading" @click="handleTrackQuery">查询</el-button>
              </el-form-item>
            </el-form>
          </div>
          <template v-if="trackResult">
            <el-descriptions :column="2" border>
              <el-descriptions-item label="运单号">{{ trackResult.trackingNo }}</el-descriptions-item>
              <el-descriptions-item label="快递公司">{{ trackResult.expressName }} ({{ trackResult.expressCode }})</el-descriptions-item>
              <el-descriptions-item label="业务类型">{{ trackResult.bizType }}</el-descriptions-item>
              <el-descriptions-item label="业务单号">{{ trackResult.bizNo }}</el-descriptions-item>
              <el-descriptions-item label="物流状态">{{ trackResult.status }}</el-descriptions-item>
              <el-descriptions-item label="最后同步">{{ formatDateTime(trackResult.lastSyncTime) }}</el-descriptions-item>
            </el-descriptions>
            <div class="track-timeline">
              <div class="section-title">物流轨迹</div>
              <el-timeline v-if="trackResult.traces?.length">
                <el-timeline-item
                  v-for="(t, idx) in trackResult.traces"
                  :key="idx"
                  :timestamp="t.time"
                  placement="top"
                >
                  {{ t.desc }}
                </el-timeline-item>
              </el-timeline>
              <el-empty v-else description="暂无轨迹" :image-size="80" />
            </div>
          </template>
          <el-empty v-else description="请输入运单号查询物流轨迹" />
        </el-tab-pane>
      </el-tabs>
    </div>

    <!-- 快递公司弹窗 -->
    <el-dialog v-model="expressDialogVisible" :title="expressDialogTitle" width="480px">
      <el-form ref="expressFormRef" :model="expressForm" :rules="expressRules" label-width="100px">
        <el-form-item label="编码" prop="code">
          <el-input v-model="expressForm.code" placeholder="如 SF / ZTO" :disabled="!!expressForm.id" />
        </el-form-item>
        <el-form-item label="名称" prop="name">
          <el-input v-model="expressForm.name" placeholder="如 顺丰速运" />
        </el-form-item>
        <el-form-item label="Logo URL">
          <el-input v-model="expressForm.logoUrl" placeholder="可选" />
        </el-form-item>
        <el-form-item label="客服电话">
          <el-input v-model="expressForm.customerService" placeholder="可选" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="expressForm.sort" :min="0" controls-position="right" />
        </el-form-item>
        <el-form-item v-if="expressForm.id" label="状态">
          <el-radio-group v-model="expressForm.status">
            <el-radio value="enabled">启用</el-radio>
            <el-radio value="disabled">禁用</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="expressDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="expressSaving" @click="handleExpressSubmit">保存</el-button>
      </template>
    </el-dialog>

    <!-- 运费模板弹窗 -->
    <el-dialog v-model="freightDialogVisible" :title="freightDialogTitle" width="560px">
      <el-form ref="freightFormRef" :model="freightForm" :rules="freightRules" label-width="100px">
        <el-form-item label="模板名称" prop="name">
          <el-input v-model="freightForm.name" placeholder="如 默认运费模板" />
        </el-form-item>
        <el-form-item label="计费方式" prop="type">
          <el-radio-group v-model="freightForm.type">
            <el-radio value="by_piece">按件计费</el-radio>
            <el-radio value="by_weight">按重量计费</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="是否包邮">
          <el-switch v-model="freightForm.freeShipping" :active-value="1" :inactive-value="0" />
        </el-form-item>
        <el-form-item label="计费规则" prop="config">
          <el-input
            v-model="freightForm.config"
            type="textarea"
            :rows="4"
            placeholder='JSON 格式，如 {"first":1,"firstFee":10,"next":1,"nextFee":2}'
          />
        </el-form-item>
        <el-form-item v-if="freightForm.id" label="状态">
          <el-radio-group v-model="freightForm.status">
            <el-radio value="enabled">启用</el-radio>
            <el-radio value="disabled">禁用</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="freightDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="freightSaving" @click="handleFreightSubmit">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.filter-bar {
  padding: 8px 0 16px;
}
.filter-bar :deep(.el-form-item) {
  margin-bottom: 0;
}
.section-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-dark);
  padding: 16px 0;
  margin-top: 16px;
}
.track-timeline {
  margin-top: 8px;
}
:deep(.el-tabs__nav) {
  padding-left: 24px;
}
:deep(.el-tab-pane) {
  padding: 0 24px 24px;
}
</style>
