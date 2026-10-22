<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
const auth=useAuthStore()
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'

import { Plus, Refresh, Edit, ArrowDown } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { listServices, updateServiceStatus } from '@/api/service'
import { formatMoney, formatDate } from '@/utils/format'
import type { TempleService } from '@/types'

const router = useRouter()

const loading = ref(false)
const list = ref<TempleService[]>([])
const statusFilter = ref('')

const filteredList = computed(() =>
  statusFilter.value ? list.value.filter((s) => s.status === statusFilter.value) : list.value
)

async function load() {
  loading.value = true
  try {
    const r = await listServices()
    list.value = r.list || []
  } finally {
    loading.value = false
  }
}

function goEdit(id?: number) {
  router.push(id ? `/services/edit/${id}` : '/services/edit')
}

async function toggleStatus(row: TempleService, status: string) {
  try {
    await ElMessageBox.confirm((uiText("确定将该服务设为「") + String((status === 'on_shelf' ? uiText('上架') : uiText('下架'))) + uiText("」？")), uiText('提示'), {
      type: 'warning'
    })
    await updateServiceStatus(row.id, status)
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
    <PageHeader :title='$t("服务管理")' :subtitle='$t("管理本寺法事服务项目与上下架")'>
      <el-button :icon="Refresh" @click="load">{{ $t("刷新") }}</el-button>
      <el-button v-if="auth.can('temple.services.write')" type="primary" :icon="Plus" @click="goEdit()">{{ $t("新增服务") }}</el-button>
    </PageHeader>

    <div class="df-card list-card">
      <div class="filter-bar">
        <el-select v-model="statusFilter" :placeholder='$t("状态筛选")' clearable style="width: 160px">
          <el-option :label='$t("上架")' value="on_shelf" />
          <el-option :label='$t("下架")' value="off_shelf" />
        </el-select>
      </div>

      <DataTable :data="filteredList" :loading="loading" :total="0" row-key="id">
        <el-table-column prop="serviceCode" :label='$t("服务编码")' width="120" />
        <el-table-column prop="serviceName" :label='$t("服务名称")' min-width="150" />
        <el-table-column :label='$t("价格")' width="120">
          <template #default="{ row }">
            <span class="price">{{ $t(formatMoney(row.price)) }}</span>
          </template>
        </el-table-column>
        <el-table-column :label='$t("开放时段")' min-width="200">
          <template #default="{ row }">
            <el-tag
              v-for="t in row.timeSlots || []"
              :key="t"
              size="small"
              effect="plain"
              class="slot-tag"
              >{{ $t(t) }}</el-tag
            >
            <span v-if="!row.timeSlots?.length" class="muted">-</span>
          </template>
        </el-table-column>
        <el-table-column :label='$t("状态")' width="90">
          <template #default="{ row }"><StatusTag :status="row.status" kind="service" /></template>
        </el-table-column>
        <el-table-column :label='$t("创建时间")' width="160">
          <template #default="{ row }">{{ $t(formatDate(row.createTime)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("操作")' width="150" fixed="right">
          <template #default="{ row }">
            <el-button v-if="auth.can('temple.services.write')" link type="primary" size="small" :icon="Edit" @click="goEdit(row.id)">{{ $t("编辑") }}</el-button>
            <el-dropdown v-if="auth.can('temple.services.write')" trigger="click" @command="(cmd: string) => toggleStatus(row as TempleService, cmd)">
              <el-button link type="primary" size="small">{{ $t(" 上下架") }}<el-icon class="el-icon--right"><ArrowDown /></el-icon>
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
.price {
  color: var(--admin-primary);
  font-weight: var(--type-weight-semibold);
}
.slot-tag {
  margin: 2px 4px 2px 0;
}
.muted {
  color: var(--admin-text-secondary);
}
</style>
