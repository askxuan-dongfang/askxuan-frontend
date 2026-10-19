<template>
  <div class="dfx-page">
    <PageHeader :title='$t("活动管理")' :subtitle='$t("营销活动配置与上下线")'>
      <template #actions>
        <el-button type="primary" :icon="Plus" @click="openCreate">{{ $t("新建活动") }}</el-button>
        <el-button :icon="Refresh" @click="loadData">{{ $t("刷新") }}</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.type" :placeholder='$t("活动类型")' clearable style="width: 150px" @change="onSearch">
        <el-option v-for="o in activityTypes" :key="o.value" :label="$t(o.label)" :value="o.value" />
      </el-select>
      <el-select v-model="query.status" :placeholder='$t("状态")' clearable style="width: 140px" @change="onSearch">
        <el-option :label='$t("启用")' value="enabled" />
        <el-option :label='$t("禁用")' value="disabled" />
      </el-select>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column :label='$t("活动名称")' prop="name" min-width="180" />
        <el-table-column :label='$t("类型")' width="130">
          <template #default="{ row }">{{ $t(typeText(row.type)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("活动时段")' width="240">
          <template #default="{ row }">{{ $t(row.startTime) }} ~ {{ $t(row.endTime) }}</template>
        </el-table-column>
        <el-table-column :label='$t("配置")' prop="config" min-width="160" show-overflow-tooltip />
        <el-table-column :label='$t("状态")' width="100">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column :label='$t("创建时间")' width="170">
          <template #default="{ row }">{{ $t(formatDate(row.createdAt)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("操作")' width="170" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openEdit(row)">{{ $t("编辑") }}</el-button>
            <el-button link :type="row.status === 'enabled' ? 'warning' : 'success'" @click="toggle(row)">
              {{ $t((row.status === 'enabled' ? $t('禁用') : $t('启用'))) }}
            </el-button>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <el-dialog v-model="dialog.visible" :title="$t((dialog.isEdit ? $t('编辑活动') : $t('新建活动')))" width="520px" append-to-body>
      <el-form :model="dialog.form" label-width="90px">
        <el-form-item :label='$t("活动名称")'>
          <el-input v-model="dialog.form.name" :placeholder='$t("请输入活动名称")' />
        </el-form-item>
        <el-form-item :label='$t("活动类型")'>
          <el-select v-model="dialog.form.type" style="width: 100%">
            <el-option v-for="o in activityTypes" :key="o.value" :label="$t(o.label)" :value="o.value" />
          </el-select>
        </el-form-item>
        <el-form-item :label='$t("活动时段")'>
          <el-date-picker v-model="dialog.dateRange" type="datetimerange" range-separator="至" start-placeholder="开始" end-placeholder="结束" value-format="YYYY-MM-DD HH:mm:ss" style="width: 100%" />
        </el-form-item>
        <el-form-item :label='$t("活动配置")'>
          <el-input v-model="dialog.form.config" type="textarea" :rows="3" :placeholder='$t("JSON 配置，如 {\"discount\": 0.8}")' />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialog.visible = false">{{ $t("取消") }}</el-button>
        <el-button type="primary" :loading="dialog.loading" @click="submit">{{ $t("确认") }}</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { ref, reactive, onMounted } from 'vue'
import { Plus, Refresh } from '@element-plus/icons-vue'

import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getActivities, createActivity, updateActivity } from '@/api/marketing'
import { formatDate } from '@/utils/format'
import type { Activity } from '@/types'

const activityTypes = [
  { label: '限时折扣', value: 'limited_discount' },
  { label: '节日活动', value: 'festival' },
  { label: '寺院法会', value: 'temple_event' }
]

const loading = ref(false)
const list = ref<Activity[]>([])
const total = ref(0)
const query = reactive({ type: '', status: '', page: 1, size: 20 })

const dialog = reactive({
  visible: false,
  loading: false,
  isEdit: false,
  editId: 0,
  form: { name: '', type: 'limited_discount', config: '' },
  dateRange: null as [string, string] | null
})

function typeText(t: string) {
  return activityTypes.find((o) => o.value === t)?.label || t
}

async function loadData() {
  loading.value = true
  try {
    const res = await getActivities(query)
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
  dialog.form = { name: '', type: 'limited_discount', config: '' }
  dialog.dateRange = null
  dialog.visible = true
}

function openEdit(row: Activity) {
  dialog.isEdit = true
  dialog.editId = row.id
  dialog.form = { name: row.name, type: row.type, config: row.config }
  dialog.dateRange = [row.startTime, row.endTime]
  dialog.visible = true
}

async function submit() {
  if (!dialog.form.name || !dialog.dateRange) {
    ElMessage.warning(uiText('请填写完整信息'))
    return
  }
  dialog.loading = true
  try {
    const payload = { ...dialog.form, startTime: dialog.dateRange[0], endTime: dialog.dateRange[1] }
    if (dialog.isEdit) await updateActivity(dialog.editId, payload)
    else await createActivity(payload)
    ElMessage.success((dialog.isEdit ? uiText('已更新') : uiText('已创建')))
    dialog.visible = false
    loadData()
  } finally {
    dialog.loading = false
  }
}

async function toggle(row: Activity) {
  const status = row.status === 'enabled' ? 'disabled' : 'enabled'
  await updateActivity(row.id, { status })
  ElMessage.success(uiText('状态已更新'))
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
</style>
