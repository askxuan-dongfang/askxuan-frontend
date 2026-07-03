<script setup lang="ts">
// 分类管理 - 列表 + 新建/编辑弹窗
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import { categoryApi, type CategorySaveParams } from '@/api/category'
import type { ProductCategory } from '@/types'

const loading = ref(false)
const list = ref<ProductCategory[]>([])
const total = ref(0)

const dialogVisible = ref(false)
const dialogTitle = ref('')
const formRef = ref<FormInstance>()
const saving = ref(false)

const form = reactive<CategorySaveParams & { id?: number }>({
  id: undefined,
  parentId: 0,
  name: '',
  level: 1,
  sort: 0
})

const rules: FormRules = {
  name: [{ required: true, message: '请输入分类名称', trigger: 'blur' }],
  level: [{ required: true, message: '请输入层级', trigger: 'blur' }]
}

async function loadList() {
  loading.value = true
  try {
    const res = await categoryApi.list({ page: 1, size: 100 })
    list.value = res.list || []
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}

function openCreate(parent?: any) {
  dialogTitle.value = '新建分类'
  Object.assign(form, {
    id: undefined,
    parentId: parent ? parent.id : 0,
    name: '',
    level: parent ? parent.level + 1 : 1,
    sort: 0
  })
  dialogVisible.value = true
}

function openEdit(row: any) {
  dialogTitle.value = '编辑分类'
  Object.assign(form, {
    id: row.id,
    parentId: row.parentId,
    name: row.name,
    level: row.level,
    sort: row.sort
  })
  dialogVisible.value = true
}

async function handleSubmit() {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    saving.value = true
    try {
      const { id, ...payload } = form
      if (id) {
        await categoryApi.update(id, payload)
        ElMessage.success('更新成功')
      } else {
        await categoryApi.create(payload)
        ElMessage.success('创建成功')
      }
      dialogVisible.value = false
      loadList()
    } finally {
      saving.value = false
    }
  })
}

async function handleDelete(row: any) {
  try {
    await ElMessageBox.confirm(`确认删除分类「${row.name}」吗？`, '提示', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning'
    })
    await categoryApi.remove(row.id)
    ElMessage.success('删除成功')
    loadList()
  } catch {
    // 取消
  }
}

onMounted(() => {
  loadList()
})
</script>

<template>
  <div class="page-wrap">
    <PageHeader title="分类管理" subtitle="维护商品分类树结构">
      <template #extra>
        <el-button type="primary" @click="openCreate()">
          <el-icon><Plus /></el-icon>
          新建分类
        </el-button>
      </template>
    </PageHeader>

    <div class="df-card">
      <el-table
        v-loading="loading"
        :data="list"
        row-key="id"
        :tree-props="{ children: 'children' }"
        style="width: 100%"
        empty-text="暂无分类"
      >
        <el-table-column label="分类名称" prop="name" min-width="220" />
        <el-table-column label="层级" prop="level" width="100" />
        <el-table-column label="父级 ID" prop="parentId" width="120" />
        <el-table-column label="排序" prop="sort" width="100" />
        <el-table-column label="ID" prop="id" width="100" />
        <el-table-column label="操作" width="220" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="openCreate(row)">新增子分类</el-button>
            <el-button text type="primary" size="small" @click="openEdit(row)">编辑</el-button>
            <el-button text type="danger" size="small" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div class="total-bar">共 {{ total }} 个分类</div>
    </div>

    <!-- 新建 / 编辑弹窗 -->
    <el-dialog v-model="dialogVisible" :title="dialogTitle" width="480px">
      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        label-width="80px"
      >
        <el-form-item label="名称" prop="name">
          <el-input v-model="form.name" placeholder="请输入分类名称" />
        </el-form-item>
        <el-form-item label="父级 ID">
          <el-input-number v-model="form.parentId" :min="0" controls-position="right" />
          <span class="form-tip">0 表示顶级分类</span>
        </el-form-item>
        <el-form-item label="层级" prop="level">
          <el-input-number v-model="form.level" :min="1" :max="5" controls-position="right" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort" :min="0" controls-position="right" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSubmit">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.total-bar {
  padding: 12px 24px;
  color: var(--text-light);
  font-size: 13px;
  border-top: 1px solid var(--border);
}
.form-tip {
  margin-left: 8px;
  font-size: 12px;
  color: var(--text-light);
}
</style>
