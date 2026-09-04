<template>
  <div class="dfx-page">
    <PageHeader title="账号管理" subtitle="统一管理平台、寺院、法师与商城运营账号">
      <template #actions>
        <el-button type="primary" :icon="Plus" @click="openCreate">新建账号</el-button>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-input v-model="query.keyword" placeholder="账号或姓名" clearable style="width: 220px" @keyup.enter="onSearch" />
      <el-select v-model="query.status" placeholder="账号状态" clearable style="width: 140px">
        <el-option label="已启用" value="enabled" />
        <el-option label="已停用" value="disabled" />
      </el-select>
      <el-button type="primary" :icon="Search" @click="onSearch">查询</el-button>
      <el-button :icon="RefreshLeft" @click="onReset">重置</el-button>
    </div>

    <div v-if="loadError || dependencyError" class="ax-page-feedback" :class="{ 'is-error': loadError }" role="alert">
      <div class="ax-page-feedback__copy">
        <div class="ax-page-feedback__title">{{ loadError ? '账号列表加载失败' : '部分账号关联信息加载失败' }}</div>
        <div class="ax-page-feedback__description">{{ loadError ? '当前结果不可视为无账号，请重新加载。' : '角色、寺院或法师名称可能不完整，账号状态操作仍以列表数据为准。' }}</div>
      </div>
      <el-button :loading="loading" @click="loadPage">重新加载</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable class="desktop-table" :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="登录账号" prop="account" min-width="150" />
        <el-table-column label="名称" prop="name" min-width="150" />
        <el-table-column label="角色" min-width="130">
          <template #default="{ row }">{{ row.roleName || roleName(row.roleId) }}</template>
        </el-table-column>
        <el-table-column label="所属主体" min-width="180">
          <template #default="{ row }">{{ bindingText(row) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <el-tag :type="row.status === 'enabled' ? 'success' : 'info'">
              {{ row.status === 'enabled' ? '已启用' : '已停用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="最近登录" width="180">
          <template #default="{ row }">{{ row.lastLoginTime ? formatDate(row.lastLoginTime) : '尚未登录' }}</template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button link :type="row.status === 'enabled' ? 'warning' : 'success'" @click="toggleStatus(row)">
              {{ row.status === 'enabled' ? '停用' : '启用' }}
            </el-button>
          </template>
        </el-table-column>
      </DataTable>
      <MobileTaskList v-model:page="query.page" :items="list" :loading="loading" :total="total" :size="query.size" @change="loadData">
        <template #item="{ item: row }">
          <article class="mobile-task-card">
            <div class="mobile-task-card__head"><strong>{{ row.name || row.account }}</strong><StatusTag :status="row.status" /></div>
            <div class="mobile-task-card__meta">{{ row.account }} · {{ row.roleName || roleName(row.roleId) }}</div>
            <div class="mobile-task-card__meta">{{ bindingText(row) }} · {{ row.lastLoginTime ? `最近登录 ${formatDate(row.lastLoginTime)}` : '尚未登录' }}</div>
            <div class="mobile-task-card__foot">
              <span>账号 #{{ row.id }}</span>
              <span class="mobile-actions">
                <el-button type="primary" @click="openEdit(row)">编辑</el-button>
                <el-button :type="row.status === 'enabled' ? 'warning' : 'success'" plain @click="toggleStatus(row)">{{ row.status === 'enabled' ? '停用' : '启用' }}</el-button>
              </span>
            </div>
          </article>
        </template>
      </MobileTaskList>
    </div>

    <el-dialog v-model="dialog.visible" :title="dialog.isEdit ? '编辑账号' : '新建账号'" width="520px">
      <el-form label-width="90px">
        <el-form-item label="登录账号">
          <el-input v-model="dialog.form.account" :disabled="dialog.isEdit" placeholder="请输入唯一登录账号" />
        </el-form-item>
        <el-form-item v-if="!dialog.isEdit" label="初始密码">
          <el-input v-model="dialog.form.password" type="password" show-password placeholder="请输入初始密码" />
        </el-form-item>
        <el-form-item label="显示名称">
          <el-input v-model="dialog.form.name" placeholder="请输入管理员姓名或岗位名称" />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="dialog.form.roleId" style="width: 100%" @change="clearBindings">
            <el-option v-for="role in roles" :key="role.id" :label="role.name" :value="role.id" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="selectedRoleCode === 'temple_admin'" label="所属寺院">
          <el-select v-model="dialog.form.templeId" filterable style="width: 100%" placeholder="请选择寺院">
            <el-option v-for="temple in temples" :key="temple.id" :label="`${temple.name}（${temple.id}）`" :value="temple.id" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="selectedRoleCode === 'master'" label="所属法师">
		  <el-select v-model="dialog.form.masterId" filterable style="width: 100%" placeholder="请选择已认证法师">
			<el-option
			  v-for="master in masters"
			  :key="master.id"
			  :label="`${master.dharmaName}（${master.id} · ${master.templeName}）`"
			  :value="master.id"
			  :disabled="master.authStatus !== '已认证' || master.platformStatus !== 'normal'"
			/>
		  </el-select>
        </el-form-item>
        <el-form-item v-if="selectedRoleCode === 'shop_admin'" label="所属商铺">
          <el-input-number v-model="dialog.form.shopId" :min="1" style="width: 100%" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialog.visible = false">取消</el-button>
        <el-button type="primary" :loading="dialog.loading" @click="submit">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Refresh, RefreshLeft, Search } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import MobileTaskList from '@/components/MobileTaskList.vue'
import StatusTag from '@/components/StatusTag.vue'
import { createAdminAccount, getAdminAccounts, getRoles, updateAdminAccount, updateAdminAccountStatus } from '@/api/auth'
import { getTempleList } from '@/api/temple'
import { getMasterList } from '@/api/master'
import { formatDate } from '@/utils/format'
import type { AdminAccount, Master, Role, Temple } from '@/types'

const loading = ref(false)
const loadError = ref(false)
const dependencyError = ref(false)
const list = ref<AdminAccount[]>([])
const total = ref(0)
const roles = ref<Role[]>([])
const temples = ref<Temple[]>([])
const masters = ref<Master[]>([])
const query = reactive({ keyword: '', status: '', page: 1, size: 20 })
const emptyForm = () => ({ account: '', password: '', name: '', roleId: 2, templeId: '', masterId: '', shopId: 0 })
const dialog = reactive({ visible: false, loading: false, isEdit: false, editId: 0, form: emptyForm() })
const selectedRoleCode = computed(() => roles.value.find((role) => role.id === dialog.form.roleId)?.code || '')

async function loadData() {
  loading.value = true
  loadError.value = false
  try {
    const response = await getAdminAccounts(query)
    list.value = response.list || []
    total.value = response.total || 0
  } catch {
    loadError.value = true
  } finally {
    loading.value = false
  }
}

function onSearch() { query.page = 1; loadData() }
function onReset() { query.keyword = ''; query.status = ''; onSearch() }
function roleName(id: number) { return roles.value.find((role) => role.id === id)?.name || `角色 ${id}` }
function templeName(id?: string) { return temples.value.find((temple) => temple.id === id)?.name || id || '' }
function masterName(id?: string) { return masters.value.find((master) => master.id === id)?.dharmaName || id || '' }
function bindingText(row: AdminAccount) {
  if (row.masterId) return `${masterName(row.masterId)}（${row.masterId}）`
  if (row.templeId) return `${templeName(row.templeId)}（${row.templeId}）`
  if (row.shopId) return `商铺 ${row.shopId}`
  return '全平台'
}
function clearBindings() { dialog.form.templeId = ''; dialog.form.masterId = ''; dialog.form.shopId = 0 }
function openCreate() { dialog.isEdit = false; dialog.editId = 0; Object.assign(dialog.form, emptyForm()); dialog.visible = true }
function openEdit(row: AdminAccount) {
  dialog.isEdit = true
  dialog.editId = row.id
  Object.assign(dialog.form, { account: row.account, password: '', name: row.name, roleId: row.roleId, templeId: row.templeId || '', masterId: row.masterId || '', shopId: row.shopId || 0 })
  dialog.visible = true
}

function validForm() {
  if (!dialog.form.name || !dialog.form.roleId || (!dialog.isEdit && (!dialog.form.account || !dialog.form.password))) return false
  if (selectedRoleCode.value === 'temple_admin' && !dialog.form.templeId) return false
  if (selectedRoleCode.value === 'master' && !dialog.form.masterId) return false
  if (selectedRoleCode.value === 'shop_admin' && !dialog.form.shopId) return false
  return true
}

async function submit() {
  if (!validForm()) { ElMessage.warning('请填写当前角色所需的完整信息'); return }
  dialog.loading = true
  try {
    const payload = { name: dialog.form.name, roleId: dialog.form.roleId, templeId: dialog.form.templeId, masterId: dialog.form.masterId, shopId: dialog.form.shopId }
    if (dialog.isEdit) await updateAdminAccount(dialog.editId, payload)
    else await createAdminAccount({ account: dialog.form.account, password: dialog.form.password, ...payload })
    ElMessage.success(dialog.isEdit ? '账号已更新' : '账号已创建')
    dialog.visible = false
    loadData()
  } finally { dialog.loading = false }
}

async function toggleStatus(row: AdminAccount) {
  const status = row.status === 'enabled' ? 'disabled' : 'enabled'
  await ElMessageBox.confirm(`确认${status === 'enabled' ? '启用' : '停用'}账号「${row.account}」？`, '账号状态', { type: 'warning' })
  await updateAdminAccountStatus(row.id, status)
  ElMessage.success('账号状态已更新')
  loadData()
}

async function loadDependencies() {
  dependencyError.value = false
  const [roleResult, templeResult, masterResult] = await Promise.allSettled([
    getRoles(),
    getTempleList({ page: 1, size: 100 }),
    getMasterList({ page: 1, size: 100 })
  ])
  if (roleResult.status === 'fulfilled') roles.value = roleResult.value
  if (templeResult.status === 'fulfilled') temples.value = templeResult.value.list || []
  if (masterResult.status === 'fulfilled') masters.value = masterResult.value.list || []
  dependencyError.value = [roleResult, templeResult, masterResult].some((result) => result.status === 'rejected')
}

async function loadPage() {
  await Promise.all([loadDependencies(), loadData()])
}

onMounted(async () => {
  await loadDependencies()
  await loadData()
})
</script>

<style scoped>
.filter-bar { display: flex; gap: 12px; align-items: center; padding: 16px; margin-bottom: 16px; flex-wrap: wrap; }
.table-wrap { padding: 16px; }
.mobile-actions { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px; }
.mobile-actions :deep(.el-button + .el-button) { margin-left: 0; }
</style>
