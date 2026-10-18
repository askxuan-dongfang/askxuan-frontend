<script setup lang="ts">
// 祈福服务列表
import { ref, reactive, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { serviceApi, type BlessingServiceListParams } from '@/commerce/api/service'
import { formatMoney } from '@/commerce/utils/format'
import type { BlessingService } from '@/commerce/types'

const router = useRouter()
const loading = ref(false)
const list = ref<BlessingService[]>([])
const total = ref(0)
const legacy = ref(false)
watch(legacy, () => { query.page = 1; loadList() })

const query = reactive<BlessingServiceListParams>({
  page: 1,
  size: 20
})

async function loadList() {
  loading.value = true
  try {
    const res = await (legacy.value ? serviceApi.list(query) : serviceApi.consecrations(query))
    list.value = res.list || []
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}

function handlePageChange(p: number) {
  query.page = p
  loadList()
}

function handleSizeChange(s: number) {
  query.size = s
  query.page = 1
  loadList()
}

async function handleDelete(row: any) {
  try {
    await ElMessageBox.confirm(`确认删除祈福服务「${row.serviceName}」吗？`, '提示', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning'
    })
    await serviceApi.remove(row.id)
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
    <PageHeader title="DIY 开光服务" subtitle="新订单直接选用寺院或独立法师已上架的开光服务，价格与原服务一致。" />
    <el-alert type="info" :closable="false" style="margin-bottom: 16px" title="开光价格请在对应寺院或法师的服务设置中维护。寺院订单由该寺院分配法师，独立法师订单直接派给本人。" />
    <el-radio-group v-model="legacy" style="margin-bottom: 16px">
      <el-radio-button :value="false">当前开光服务</el-radio-button>
      <el-radio-button :value="true">历史附加服务</el-radio-button>
    </el-radio-group>
    <el-alert v-if="legacy" type="warning" :closable="false" style="margin-bottom: 16px" title="以下配置仅保留给历史订单，新定制不再使用独立加价项。" />

    <div class="df-card">
      <el-table v-loading="loading" :data="list" style="width: 100%" empty-text="暂无可用服务">
        <el-table-column label="服务编码" prop="serviceCode" width="180" />
        <el-table-column label="服务名称" prop="serviceName" min-width="200" />
        <el-table-column label="寺院" width="180">
          <template #default="{ row }">
            <span>{{ row.templeName || row.templeCode }}</span>
          </template>
        </el-table-column>
        <el-table-column label="法师" width="160">
          <template #default="{ row }">
            <span>{{ row.masterName || row.masterCode }}</span>
          </template>
        </el-table-column>
        <el-table-column label="价格" width="120">
          <template #default="{ row }">
            <span class="price">{{ formatMoney(row.price) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <StatusTag :status="row.status" domain="enabled" />
          </template>
        </el-table-column>
        <el-table-column v-if="legacy" label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="router.push(`/commerce/services/edit/${row.id}`)">编辑</el-button>
            <el-button text type="danger" size="small" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pager">
        <el-pagination
          v-model:current-page="query.page"
          v-model:page-size="query.size"
          :total="total"
          :page-sizes="[10, 20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          background
          @current-change="handlePageChange"
          @size-change="handleSizeChange"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.pager {
  padding: 16px 24px;
  display: flex;
  justify-content: flex-end;
}
.price {
  color: var(--primary);
  font-weight: var(--type-weight-semibold);
}
</style>
