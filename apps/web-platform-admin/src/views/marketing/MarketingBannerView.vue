<template>
  <div class="dfx-page">
    <PageHeader title="Banner 管理" subtitle="首页 Banner 配置与上下线">
      <template #actions>
        <el-button type="primary" :icon="Plus" @click="openCreate">新增 Banner</el-button>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.status" placeholder="状态" clearable style="width: 140px" @change="onSearch">
        <el-option label="启用" value="enabled" />
        <el-option label="禁用" value="disabled" />
      </el-select>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="Banner" min-width="240">
          <template #default="{ row }">
            <div class="banner-cell">
              <el-image :src="row.imageUrl" fit="cover" class="banner-cell__img">
                <template #error><div class="banner-cell__fallback">图</div></template>
              </el-image>
              <div>
                <div class="banner-cell__title">{{ row.title }}</div>
                <div class="muted">排序：{{ row.sort }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="链接类型" width="120">
          <template #default="{ row }">{{ linkTypeText(row.linkType) }}</template>
        </el-table-column>
        <el-table-column label="链接值" prop="linkValue" min-width="140" show-overflow-tooltip />
        <el-table-column label="投放时段" width="220">
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

    <el-dialog v-model="dialog.visible" :title="dialog.isEdit ? '编辑 Banner' : '新增 Banner'" width="520px">
      <el-form :model="dialog.form" label-width="90px">
        <el-form-item label="标题">
          <el-input v-model="dialog.form.title" placeholder="请输入标题" />
        </el-form-item>
        <el-form-item label="Banner 图片">
          <ImageUploader v-model="dialog.form.imageUrl" />
        </el-form-item>
        <el-form-item label="链接类型">
          <el-select v-model="dialog.form.linkType" style="width: 100%">
            <el-option v-for="o in linkTypes" :key="o.value" :label="o.label" :value="o.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="链接值">
          <el-input v-model="dialog.form.linkValue" placeholder="跳转目标 ID" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="dialog.form.sort" :min="0" controls-position="right" />
        </el-form-item>
        <el-form-item label="投放时段">
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
import ImageUploader from '@/components/ImageUploader.vue'
import { getBanners, createBanner, updateBanner } from '@/api/marketing'
import type { Banner } from '@/types'

const linkTypes = [
  { label: '寺院', value: 'temple' },
  { label: '法师', value: 'master' },
  { label: '商品', value: 'product' },
  { label: 'DIY', value: 'diy' },
  { label: '广告落地页', value: 'ad_landing' }
]

const loading = ref(false)
const list = ref<Banner[]>([])
const total = ref(0)
const query = reactive({ status: '', page: 1, size: 20 })

const dialog = reactive({
  visible: false,
  loading: false,
  isEdit: false,
  editId: 0,
  form: { title: '', imageUrl: '', linkType: 'temple', linkValue: '', sort: 0 },
  dateRange: null as [string, string] | null
})

function linkTypeText(t: string) {
  return linkTypes.find((l) => l.value === t)?.label || t
}

async function loadData() {
  loading.value = true
  try {
    const res = await getBanners(query)
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
  dialog.form = { title: '', imageUrl: '', linkType: 'temple', linkValue: '', sort: 0 }
  dialog.dateRange = null
  dialog.visible = true
}

function openEdit(row: Banner) {
  dialog.isEdit = true
  dialog.editId = row.id
  dialog.form = { title: row.title, imageUrl: row.imageUrl, linkType: row.linkType, linkValue: row.linkValue, sort: row.sort }
  dialog.dateRange = [row.startTime, row.endTime]
  dialog.visible = true
}

async function submit() {
  if (!dialog.form.title || !dialog.form.imageUrl || !dialog.dateRange) {
    ElMessage.warning('请填写完整信息')
    return
  }
  dialog.loading = true
  try {
    const payload = {
      ...dialog.form,
      startTime: dialog.dateRange[0],
      endTime: dialog.dateRange[1]
    }
    if (dialog.isEdit) {
      await updateBanner(dialog.editId, payload)
    } else {
      await createBanner(payload)
    }
    ElMessage.success(dialog.isEdit ? '已更新' : '已创建')
    dialog.visible = false
    loadData()
  } finally {
    dialog.loading = false
  }
}

async function toggle(row: Banner) {
  const status = row.status === 'enabled' ? 'disabled' : 'enabled'
  await updateBanner(row.id, { status })
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
.banner-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}
.banner-cell__img,
.banner-cell__fallback {
  width: 80px;
  height: 45px;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
}
.banner-cell__fallback {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg-tertiary);
  color: var(--color-text-tertiary);
}
.banner-cell__title {
  font-weight: 600;
  color: var(--color-text-primary);
}
.muted {
  color: var(--color-text-tertiary);
  font-size: 12px;
}
</style>
