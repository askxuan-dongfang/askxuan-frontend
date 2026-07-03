<script setup lang="ts">
// 祈福服务列表
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { serviceApi, type BlessingServiceListParams } from '@/api/service'
import { formatMoney } from '@/utils/format'
import type { BlessingService } from '@/types'

const router = useRouter()
const loading = ref(false)
const list = ref<BlessingService[]>([])
const total = ref(0)

const query = reactive<BlessingServiceListParams>({
  page: 1,
  size: 20
})

async function loadList() {
  loading.value = true
  try {
    const res = await serviceApi.list(query)
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
    <PageHeader title="祈福服务列表" subtitle="管理 DIY 加持服务项（寺院/法师/价格）">
      <template #extra>
        <el-button type="primary" @click="router.push('/services/edit')">
          <el-icon><Plus /></el-icon>
          新建服务
        </el-button>
      </template>
    </PageHeader>

    <div class="df-card">
      <el-table v-loading="loading" :data="list" style="width: 100%" empty-text="暂无祈福服务">
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
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="router.push(`/services/edit/${row.id}`)">编辑</el-button>
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
  font-weight: 600;
}
</style>
