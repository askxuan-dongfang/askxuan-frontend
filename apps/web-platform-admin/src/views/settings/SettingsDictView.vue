<template>
  <div class="dfx-page">
    <PageHeader :title='$t("数据字典")' :subtitle='$t("内容敏感词字典管理")'>
      <template #actions>
        <el-button type="primary" :icon="Plus" @click="openCreate">{{ $t("新增词条") }}</el-button>
        <el-button :icon="Refresh" @click="loadData">{{ $t("刷新") }}</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.category" :placeholder='$t("分类")' clearable style="width: 150px" @change="onSearch">
        <el-option v-for="o in categories" :key="o.value" :label="$t(o.label)" :value="o.value" />
      </el-select>
      <el-input v-model="query.keyword" :placeholder='$t("词条关键字")' clearable style="width: 200px" @keyup.enter="onSearch" />
      <el-button type="primary" :icon="Search" @click="onSearch">{{ $t("查询") }}</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData" show-index>
        <el-table-column :label='$t("词条")' prop="word" min-width="180" />
        <el-table-column :label='$t("分类")' width="140">
          <template #default="{ row }">
            <el-tag size="small" effect="plain" :type="categoryType(row.category)">{{ $t(categoryText(row.category)) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column :label='$t("状态")' width="100">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column :label='$t("创建时间")' width="170">
          <template #default="{ row }">{{ $t(formatDate(row.createTime)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("操作")' width="100" fixed="right">
          <template #default="{ row }">
            <el-button link type="danger" :icon="Delete" @click="onDelete(row)">{{ $t("删除") }}</el-button>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <el-dialog v-model="dialog.visible" :title='$t("新增词条")' width="420px" append-to-body>
      <el-form :model="dialog.form" label-width="80px">
        <el-form-item :label='$t("词条")'>
          <el-input v-model="dialog.form.word" :placeholder='$t("请输入敏感词")' />
        </el-form-item>
        <el-form-item :label='$t("分类")'>
          <el-select v-model="dialog.form.category" style="width: 100%">
            <el-option v-for="o in categories" :key="o.value" :label="$t(o.label)" :value="o.value" />
          </el-select>
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
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { ref, reactive, onMounted } from 'vue'
import { Plus, Refresh, Search, Delete } from '@element-plus/icons-vue'

import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getSensitiveWords, createSensitiveWord, deleteSensitiveWord } from '@/api/system'
import { formatDate } from '@/utils/format'
import type { SensitiveWord } from '@/types'

const categories = [
  { label: '政治敏感', value: 'political' },
  { label: '宗教敏感', value: 'religious' },
  { label: '低俗内容', value: 'vulgar' },
  { label: '广告推广', value: 'advertising' }
]

const loading = ref(false)
const list = ref<SensitiveWord[]>([])
const total = ref(0)
const query = reactive({ category: '', keyword: '', page: 1, size: 20 })

const dialog = reactive({
  visible: false,
  loading: false,
  form: { word: '', category: 'advertising' }
})

function categoryText(c: string) {
  return categories.find((o) => o.value === c)?.label || c
}
function categoryType(c: string): 'danger' | 'warning' | 'info' | 'primary' {
  return ({ political: 'danger', religious: 'warning', vulgar: 'info', advertising: 'primary' } as const)[c as 'political'] || 'info'
}

async function loadData() {
  loading.value = true
  try {
    const res = await getSensitiveWords(query)
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
  dialog.form = { word: '', category: 'advertising' }
  dialog.visible = true
}

async function submit() {
  if (!dialog.form.word) {
    ElMessage.warning(uiText('请输入词条'))
    return
  }
  dialog.loading = true
  try {
    await createSensitiveWord({ word: dialog.form.word, category: dialog.form.category })
    ElMessage.success(uiText('已新增'))
    dialog.visible = false
    loadData()
  } finally {
    dialog.loading = false
  }
}

async function onDelete(row: SensitiveWord) {
  await ElMessageBox.confirm((uiText("确认删除词条「") + String(row.word) + uiText("」？")), uiText('提示'), { type: 'warning' })
  await deleteSensitiveWord(row.id)
  ElMessage.success(uiText('已删除'))
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
  flex-wrap: wrap;
}
.table-wrap {
  padding: 16px;
}
</style>
