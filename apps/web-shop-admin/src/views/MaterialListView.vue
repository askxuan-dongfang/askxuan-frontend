<script setup lang="ts">
// DIY 材料列表
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { materialApi, type MaterialListParams } from '@/api/material'
import { formatMoney, materialCategoryLabel } from '@/utils/format'
import type { Material } from '@/types'

const router = useRouter()
const loading = ref(false)
const list = ref<Material[]>([])
const total = ref(0)

const query = reactive<MaterialListParams>({
  category: '',
  keyword: '',
  page: 1,
  size: 20
})

const categoryOptions = [
  { value: 'main_bead', label: '主珠' },
  { value: 'spacer', label: '隔珠' },
  { value: 'buddha_head', label: '佛头' },
  { value: 'pendant', label: '吊坠' },
  { value: 'tassel', label: '流苏' },
  { value: 'three_way', label: '三通' },
  { value: 'cord', label: '线绳' }
]

async function loadList() {
  loading.value = true
  try {
    const res = await materialApi.list(query)
    list.value = res.list || []
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}

function handleSearch() {
  query.page = 1
  loadList()
}

function handleReset() {
  query.category = ''
  query.keyword = ''
  query.page = 1
  loadList()
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

async function handleStatusChange(row: any, status: string) {
  try {
    await materialApi.updateStatus(row.id, status as 'on_shelf' | 'off_shelf')
    ElMessage.success('状态已更新')
    loadList()
  } catch {
    // 忽略
  }
}

async function handleDelete(row: any) {
  try {
    await ElMessageBox.confirm(`确认删除材料「${row.name}」吗？`, '提示', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning'
    })
    // DIY 材料无独立删除接口，使用下架替代提示
    ElMessage.info('材料暂不支持物理删除，请使用下架')
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
    <PageHeader title="DIY 材料列表" subtitle="管理手串 DIY 材料库、价格与库存">
      <template #extra>
        <el-button type="primary" @click="router.push('/materials/edit')">
          <el-icon><Plus /></el-icon>
          新建材料
        </el-button>
      </template>
    </PageHeader>

    <div class="df-card filter-bar">
      <el-form inline @submit.prevent="handleSearch">
        <el-form-item label="关键词">
          <el-input
            v-model="query.keyword"
            placeholder="材料名称"
            clearable
            style="width: 200px"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="分类">
          <el-select v-model="query.category" placeholder="全部分类" clearable style="width: 160px">
            <el-option
              v-for="c in categoryOptions"
              :key="c.value"
              :label="c.label"
              :value="c.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">查询</el-button>
          <el-button @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>
    </div>

    <div class="df-card">
      <el-table v-loading="loading" :data="list" style="width: 100%" empty-text="暂无材料">
        <el-table-column label="材料" min-width="220">
          <template #default="{ row }">
            <div class="material-cell">
              <el-image :src="row.image" fit="cover" class="material-thumb">
                <template #error>
                  <div class="material-thumb-placeholder">无图</div>
                </template>
              </el-image>
              <div>
                <div class="material-name">{{ row.name }}</div>
                <div class="material-spec">{{ row.spec }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="分类" width="100">
          <template #default="{ row }">{{ materialCategoryLabel(row.category) }}</template>
        </el-table-column>
        <el-table-column label="五行" prop="fiveElements" width="80" />
        <el-table-column label="单价" width="120">
          <template #default="{ row }">
            <span class="price">{{ formatMoney(row.unitPrice) }} / {{ row.unit }}</span>
          </template>
        </el-table-column>
        <el-table-column label="库存" prop="stock" width="100" />
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <StatusTag :status="row.status" domain="enabled" />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="220" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="router.push(`/materials/edit/${row.id}`)">编辑</el-button>
            <el-button
              v-if="row.status !== 'on_shelf'"
              text
              type="success"
              size="small"
              @click="handleStatusChange(row, 'on_shelf')"
            >上架</el-button>
            <el-button
              v-else
              text
              type="warning"
              size="small"
              @click="handleStatusChange(row, 'off_shelf')"
            >下架</el-button>
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
.filter-bar {
  padding: 16px 24px;
  margin-bottom: 16px;
}
.filter-bar :deep(.el-form-item) {
  margin-bottom: 0;
}
.pager {
  padding: 16px 24px;
  display: flex;
  justify-content: flex-end;
}
.material-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}
.material-thumb {
  width: 48px;
  height: 48px;
  border-radius: 6px;
  flex-shrink: 0;
  border: 1px solid var(--border);
}
.material-thumb-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f5f0eb;
  color: var(--text-light);
  font-size: 12px;
}
.material-name {
  font-weight: 500;
  color: var(--text-dark);
}
.material-spec {
  font-size: 12px;
  color: var(--text-light);
  margin-top: 2px;
}
.price {
  color: var(--primary);
  font-weight: 600;
}
</style>
