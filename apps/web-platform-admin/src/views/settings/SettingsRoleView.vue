<template>
  <div class="dfx-page">
    <PageHeader title="角色权限" subtitle="管理台角色与权限点管理">
      <template #actions>
        <el-button type="primary" :icon="Plus" @click="openCreate">新建角色</el-button>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="grid">
      <!-- 角色列表 -->
      <div class="dfx-card section">
        <div class="section-title">角色列表</div>
        <el-table :data="roles" v-loading="roleLoading" style="width: 100%">
          <el-table-column label="角色名称" prop="name" min-width="120" />
          <el-table-column label="编码" prop="code" width="160" />
          <el-table-column label="描述" prop="description" min-width="160" show-overflow-tooltip />
          <el-table-column label="创建时间" width="170">
            <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
          </el-table-column>
          <el-table-column label="操作" width="100" fixed="right">
            <template #default="{ row }">
              <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>

      <!-- 权限点 -->
      <div class="dfx-card section">
        <div class="section-title">权限点列表</div>
        <el-table :data="permissions" v-loading="permLoading" style="width: 100%" max-height="420">
          <el-table-column label="权限名称" prop="name" min-width="140" />
          <el-table-column label="编码" prop="code" width="180" />
          <el-table-column label="资源" prop="resource" width="160" />
          <el-table-column label="操作" prop="action" width="100" />
        </el-table>
      </div>
    </div>

    <el-dialog v-model="dialog.visible" :title="dialog.isEdit ? '编辑角色' : '新建角色'" width="460px">
      <el-form :model="dialog.form" label-width="80px">
        <el-form-item label="角色名称">
          <el-input v-model="dialog.form.name" placeholder="请输入角色名称" :disabled="dialog.isEdit" />
        </el-form-item>
        <el-form-item v-if="!dialog.isEdit" label="角色编码">
          <el-input v-model="dialog.form.code" placeholder="如 platform_admin" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="dialog.form.description" type="textarea" :rows="3" placeholder="角色描述" />
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
import { getRoles, createRole, updateRole, getPermissions } from '@/api/system'
import { formatDate } from '@/utils/format'
import type { Role, Permission } from '@/types'

const roles = ref<Role[]>([])
const permissions = ref<Permission[]>([])
const roleLoading = ref(false)
const permLoading = ref(false)

const dialog = reactive({
  visible: false,
  loading: false,
  isEdit: false,
  editId: 0,
  form: { name: '', code: '', description: '' }
})

async function loadData() {
  roleLoading.value = true
  permLoading.value = true
  try {
    const [r, p] = await Promise.allSettled([getRoles(), getPermissions()])
    if (r.status === 'fulfilled') roles.value = r.value
    if (p.status === 'fulfilled') permissions.value = p.value
  } finally {
    roleLoading.value = false
    permLoading.value = false
  }
}

function openCreate() {
  dialog.isEdit = false
  dialog.editId = 0
  dialog.form = { name: '', code: '', description: '' }
  dialog.visible = true
}

function openEdit(row: Role) {
  dialog.isEdit = true
  dialog.editId = row.id
  dialog.form = { name: row.name, code: row.code, description: row.description }
  dialog.visible = true
}

async function submit() {
  if (!dialog.form.name || (!dialog.isEdit && !dialog.form.code)) {
    ElMessage.warning('请填写完整信息')
    return
  }
  dialog.loading = true
  try {
    if (dialog.isEdit) await updateRole(dialog.editId, { name: dialog.form.name, description: dialog.form.description })
    else await createRole({ name: dialog.form.name, code: dialog.form.code, description: dialog.form.description })
    ElMessage.success(dialog.isEdit ? '已更新' : '已创建')
    dialog.visible = false
    loadData()
  } finally {
    dialog.loading = false
  }
}

onMounted(loadData)
</script>

<style scoped>
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
.section {
  padding: 18px 20px;
}
.section-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 16px;
  padding-left: 10px;
  border-left: 3px solid var(--color-accent);
}
</style>
