<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
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
    await ElMessageBox.confirm(`确定将该服务设为「${status === 'on_shelf' ? '上架' : '下架'}」？`, '提示', {
      type: 'warning'
    })
    await updateServiceStatus(row.id, status)
    ElMessage.success('状态已更新')
    load()
  } catch {
    /* 取消 */
  }
}

onMounted(load)
</script>

<template>
  <div class="df-page">
    <PageHeader title="服务管理" subtitle="管理本寺法事服务项目与上下架">
      <el-button :icon="Refresh" @click="load">刷新</el-button>
      <el-button type="primary" :icon="Plus" @click="goEdit()">新增服务</el-button>
    </PageHeader>

    <div class="df-card list-card">
      <div class="filter-bar">
        <el-select v-model="statusFilter" placeholder="状态筛选" clearable style="width: 160px">
          <el-option label="上架" value="on_shelf" />
          <el-option label="下架" value="off_shelf" />
        </el-select>
      </div>

      <DataTable :data="filteredList" :loading="loading" :total="0" row-key="id">
        <el-table-column prop="serviceCode" label="服务编码" width="120" />
        <el-table-column prop="serviceName" label="服务名称" min-width="150" />
        <el-table-column label="价格" width="120">
          <template #default="{ row }">
            <span class="price">{{ formatMoney(row.price) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="开放时段" min-width="200">
          <template #default="{ row }">
            <el-tag
              v-for="t in row.timeSlots || []"
              :key="t"
              size="small"
              effect="plain"
              class="slot-tag"
              >{{ t }}</el-tag
            >
            <span v-if="!row.timeSlots?.length" class="muted">-</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="90">
          <template #default="{ row }"><StatusTag :status="row.status" kind="service" /></template>
        </el-table-column>
        <el-table-column label="创建时间" width="160">
          <template #default="{ row }">{{ formatDate(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" :icon="Edit" @click="goEdit(row.id)">编辑</el-button>
            <el-dropdown trigger="click" @command="(cmd: string) => toggleStatus(row as TempleService, cmd)">
              <el-button link type="primary" size="small">
                上下架<el-icon class="el-icon--right"><ArrowDown /></el-icon>
              </el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="on_shelf">上架</el-dropdown-item>
                  <el-dropdown-item command="off_shelf">下架</el-dropdown-item>
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
  color: #c45a3c;
  font-weight: 600;
}
.slot-tag {
  margin: 2px 4px 2px 0;
}
.muted {
  color: #b0a090;
}
</style>
