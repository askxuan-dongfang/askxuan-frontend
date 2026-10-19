<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Refresh, Search, View } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { listBlessingTasks } from '@/api/blessing'
import { formatDate } from '@/utils/format'
import type { BlessingTask } from '@/types'

const router = useRouter()
const route = useRoute()
const loading = ref(false)
const loadError = ref('')
const list = ref<BlessingTask[]>([])
const total = ref(0)
const initialStatus = typeof route.query.status === 'string' ? route.query.status : ''
const query = reactive({ status: ['dispatched', 'assigned', 'accepted', 'in_progress', 'completed', 'rejected'].includes(initialStatus) ? initialStatus : '', page: 1, size: 20 })
const statusOptions = [
  { value: 'dispatched', label: '待分配' },
  { value: 'assigned', label: '已分配' },
  { value: 'accepted', label: '已接单' },
  { value: 'in_progress', label: '进行中' },
  { value: 'completed', label: '已完成' },
  { value: 'rejected', label: '已拒绝' }
]

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    const response = await listBlessingTasks({
      status: query.status || undefined,
      page: query.page,
      size: query.size
    })
    list.value = response.list || []
    total.value = response.total || 0
  } catch (error) {
    loadError.value = error instanceof Error ? error.message : '加持任务加载失败'
  } finally {
    loading.value = false
  }
}

function search() {
  query.page = 1
  load()
}

function pageChange(value: { page: number; size: number }) {
  query.page = value.page
  query.size = value.size
  load()
}

onMounted(load)
</script>

<template>
  <div class="df-page">
    <PageHeader :title='$t("加持任务")' :subtitle='$t("接收商城委托并分配本寺院法师")'>
      <el-button :icon="Refresh" @click="load">{{ $t("刷新") }}</el-button>
    </PageHeader>

    <div class="df-card list-card">
      <div class="filter-bar">
        <el-select v-model="query.status" :placeholder='$t("状态筛选")' clearable style="width: 160px" @change="search">
          <el-option v-for="item in statusOptions" :key="item.value" :label="$t(item.label)" :value="item.value" />
        </el-select>
        <el-button :icon="Search" type="primary" plain @click="search">{{ $t("查询") }}</el-button>
      </div>

      <div v-if="loadError" class="ax-page-feedback is-error" role="status">
        <div class="ax-page-feedback__copy">
          <div class="ax-page-feedback__title">{{ $t("加持任务加载失败") }}</div>
          <div class="ax-page-feedback__description">{{ $t(loadError) }}</div>
        </div>
        <el-button :loading="loading" @click="load">{{ $t("重试") }}</el-button>
      </div>

      <div class="desktop-table"><DataTable
        :data="list"
        :loading="loading"
        :total="total"
        :page="query.page"
        :size="query.size"
        row-key="id"
        @change="pageChange"
      >
        <el-table-column prop="taskNo" :label='$t("任务编号")' min-width="170" />
        <el-table-column prop="diyOrderNo" :label='$t("DIY 订单")' min-width="170" />
        <el-table-column prop="masterCode" :label='$t("执行法师")' width="130">
          <template #default="{ row }">{{ $t((row.masterCode || $t('待分配'))) }}</template>
        </el-table-column>
        <el-table-column :label='$t("状态")' width="110">
          <template #default="{ row }"><StatusTag :status="row.status" kind="blessing" /></template>
        </el-table-column>
        <el-table-column :label='$t("创建时间")' width="170">
          <template #default="{ row }">{{ $t(formatDate(row.createTime)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("操作")' width="90" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" :icon="View" @click="router.push(`/blessing-tasks/${row.id}`)">{{ $t(" 详情 ") }}</el-button>
          </template>
        </el-table-column>
      </DataTable></div>

      <div class="mobile-task-list" :aria-label='$t("加持任务列表")'>
        <button v-for="item in list" :key="item.id" class="mobile-task-card" type="button" @click="router.push(`/blessing-tasks/${item.id}`)">
          <span class="mobile-task-card__head">
            <strong>{{ $t(item.taskNo) }}</strong>
            <StatusTag :status="item.status" kind="blessing" />
          </span>
          <span class="mobile-task-card__meta">{{ $t("DIY 订单：") }}{{ $t(item.diyOrderNo) }}</span>
          <span class="mobile-task-card__foot"><span>{{ $t((item.masterCode || $t('待分配法师'))) }}</span><b>{{ $t(formatDate(item.createTime)) }}</b></span>
        </button>
        <div v-if="!loading && !list.length && !loadError" class="mobile-task-empty">{{ $t("当前筛选下暂无加持任务") }}</div>
        <div v-if="total > query.size" class="mobile-task-pager">
          <el-button :disabled="query.page <= 1" @click="pageChange({ page: query.page - 1, size: query.size })">{{ $t("上一页") }}</el-button>
          <span>{{ $t("第 ") }}{{ $t(query.page) }}{{ $t(" 页") }}</span>
          <el-button :disabled="query.page * query.size >= total" @click="pageChange({ page: query.page + 1, size: query.size })">{{ $t("下一页") }}</el-button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.list-card { padding: 18px 20px; }
.filter-bar { display: flex; gap: 10px; margin-bottom: 16px; }
@media (max-width: 767px) {
  .list-card { padding: 12px; }
  .filter-bar { align-items: stretch; flex-direction: column; }
  .filter-bar :deep(.el-select), .filter-bar :deep(.el-button) { width: 100% !important; }
}
</style>
