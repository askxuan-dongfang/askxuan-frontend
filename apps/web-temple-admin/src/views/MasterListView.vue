<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'

import { Plus, Refresh, Search, Edit, ArrowDown } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { listMasters, updateMasterStatus } from '@/api/master'
import { useAuthStore } from '@/stores/auth'
import type { Master } from '@/types'

const router = useRouter()
const auth = useAuthStore()

const loading = ref(false)
const list = ref<Master[]>([])
const total = ref(0)
const query = reactive({ status: '', page: 1, size: 20 })

async function load() {
  loading.value = true
  try {
    const r = await listMasters({
      templeId: auth.templeId,
      status: query.status || undefined,
      page: query.page,
      size: query.size
    })
    list.value = r.list || []
    total.value = r.total || 0
  } finally {
    loading.value = false
  }
}

function onSearch() {
  query.page = 1
  load()
}
function onPageChange(p: { page: number; size: number }) {
  query.page = p.page
  query.size = p.size
  load()
}
function goEdit(id?: string) {
  router.push(id ? `/masters/edit/${id}` : '/masters/edit')
}

async function toggleStatus(id: string, status: string) {
  try {
    await ElMessageBox.confirm((uiText("确定将该法师设为「") + String((status === 'on_shelf' ? uiText('上架') : uiText('下架'))) + uiText("」？")), uiText('提示'), {
      type: 'warning'
    })
    await updateMasterStatus(id, status)
    ElMessage.success(uiText('状态已更新'))
    load()
  } catch {
    /* 取消 */
  }
}

onMounted(load)
</script>

<template>
  <div class="df-page">
    <PageHeader :title='$t("法师管理")' :subtitle='$t("维护本寺法师信息与上下架状态")'>
      <el-button @click="router.push('/masters/accounts')">{{ $t("账号分配") }}</el-button>
      <el-button :icon="Refresh" @click="load">{{ $t("刷新") }}</el-button>
      <el-button type="primary" :icon="Plus" @click="goEdit()">{{ $t("新增法师") }}</el-button>
    </PageHeader>

    <div class="df-card list-card">
      <div class="filter-bar">
        <el-select v-model="query.status" :placeholder='$t("状态筛选")' clearable style="width: 160px" @change="onSearch">
          <el-option :label='$t("上架")' value="on_shelf" />
          <el-option :label='$t("下架")' value="off_shelf" />
        </el-select>
        <el-button :icon="Search" type="primary" plain @click="onSearch">{{ $t("查询") }}</el-button>
      </div>

      <DataTable
        :data="list"
        :loading="loading"
        :total="total"
        :page="query.page"
        :size="query.size"
        row-key="id"
        @change="onPageChange"
      >
        <el-table-column :label='$t("法师")' min-width="180">
          <template #default="{ row }">
            <div class="master-cell">
              <el-avatar :size="36" :src="row.avatar">{{ $t(row.dharmaName?.charAt(0)) }}</el-avatar>
              <div>
                <div class="master-name">{{ $t(row.dharmaName) }}</div>
                <div class="master-lay">{{ $t("俗名：") }}{{ $t((row.layName || '-')) }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="position" :label='$t("职位")' width="100" />
        <el-table-column prop="sect" :label='$t("宗派")' width="100" />
        <el-table-column prop="type" :label='$t("类型")' width="90" />
        <el-table-column :label='$t("专长")' min-width="160">
          <template #default="{ row }">
            <el-tag
              v-for="s in row.specialties || []"
              :key="s"
              size="small"
              effect="plain"
              class="spec-tag"
              >{{ $t(s) }}</el-tag
            >
            <span v-if="!row.specialties?.length" class="muted">-</span>
          </template>
        </el-table-column>
        <el-table-column :label='$t("认证")' width="90">
          <template #default="{ row }"><StatusTag :status="row.authStatus" kind="master" /></template>
        </el-table-column>
        <el-table-column :label='$t("评分")' width="80">
          <template #default="{ row }">
            <span class="rate-text">{{ $t((row.rating?.toFixed(1) ?? '-')) }}</span>
          </template>
        </el-table-column>
        <el-table-column :label='$t("操作")' width="150" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" :icon="Edit" @click="goEdit(row.id)">{{ $t("编辑") }}</el-button>
            <el-dropdown trigger="click" @command="(cmd: string) => toggleStatus(row.id, cmd)">
              <el-button link type="primary" size="small">{{ $t(" 状态") }}<el-icon class="el-icon--right"><ArrowDown /></el-icon>
              </el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="on_shelf">{{ $t("上架") }}</el-dropdown-item>
                  <el-dropdown-item command="off_shelf">{{ $t("下架") }}</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<style scoped>
.list-card {
  padding: 18px 20px;
}
.filter-bar {
  display: flex;
  gap: 10px;
  margin-bottom: 16px;
}
.master-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}
.master-name {
  font-size: var(--type-size-body);
  font-weight: var(--type-weight-semibold);
  color: var(--admin-text);
}
.master-lay {
  font-size: var(--type-size-caption);
  color: var(--admin-text-secondary);
}
.spec-tag {
  margin: 2px 4px 2px 0;
}
.muted {
  color: var(--admin-text-secondary);
}
.rate-text {
  color: var(--admin-accent);
  font-weight: var(--type-weight-semibold);
}
</style>
