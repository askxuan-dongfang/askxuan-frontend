<script setup lang="ts">
// 商品列表
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { productApi, type ProductListParams } from '@/api/product'
import { categoryApi } from '@/api/category'
import { formatMoney } from '@/utils/format'
import type { Product, ProductCategory, ProductStatus } from '@/types'

const router = useRouter()
const loading = ref(false)
const list = ref<Product[]>([])
const total = ref(0)
const categories = ref<ProductCategory[]>([])

const query = reactive<ProductListParams>({
  keyword: '',
  categoryId: undefined,
  status: '',
  page: 1,
  size: 20
})

async function loadCategories() {
  try {
    const res = await categoryApi.list({ page: 1, size: 100 })
    categories.value = res.list || []
  } catch {
    categories.value = []
  }
}

async function loadList() {
  loading.value = true
  try {
    const res = await productApi.list(query)
    list.value = res.list || []
    total.value = res.total || 0
  } catch {
    list.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

function handleSearch() {
  query.page = 1
  loadList()
}

function handleReset() {
  query.keyword = ''
  query.categoryId = undefined
  query.status = ''
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

async function handleStatusChange(row: any, status: ProductStatus) {
  try {
    await productApi.updateStatus(row.id, status as 'on_shelf' | 'off_shelf')
    ElMessage.success('状态已更新')
    loadList()
  } catch {
    // 忽略
  }
}

async function handleDelete(row: any) {
  try {
    await ElMessageBox.confirm(`确认删除商品「${row.name}」吗？`, '提示', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning'
    })
    await productApi.remove(row.id)
    ElMessage.success('删除成功')
    loadList()
  } catch {
    // 取消或失败
  }
}

onMounted(() => {
  loadCategories()
  loadList()
})
</script>

<template>
  <div class="page-wrap">
    <PageHeader title="商品列表" subtitle="管理商城在售商品、上下架与库存">
      <template #extra>
        <el-button type="primary" @click="router.push('/products/edit')">
          <el-icon><Plus /></el-icon>
          新建商品
        </el-button>
      </template>
    </PageHeader>

    <div class="df-card filter-bar">
      <el-form inline @submit.prevent="handleSearch">
        <el-form-item label="关键词">
          <el-input
            v-model="query.keyword"
            placeholder="商品名称 / 编号"
            clearable
            style="width: 200px"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="分类">
          <el-select
            v-model="query.categoryId"
            placeholder="全部分类"
            clearable
            style="width: 180px"
          >
            <el-option
              v-for="c in categories"
              :key="c.id"
              :label="c.name"
              :value="c.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="query.status" placeholder="全部状态" clearable style="width: 140px">
            <el-option label="草稿" value="draft" />
            <el-option label="已上架" value="on_shelf" />
            <el-option label="已下架" value="off_shelf" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">查询</el-button>
          <el-button @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>
    </div>

    <div class="df-card">
      <el-table v-loading="loading" :data="list" style="width: 100%" empty-text="暂无商品">
        <el-table-column label="商品" min-width="280">
          <template #default="{ row }">
            <div class="product-cell">
              <el-image
                :src="row.mainImage"
                fit="cover"
                class="product-thumb"
              >
                <template #error>
                  <div class="product-thumb-placeholder">无图</div>
                </template>
              </el-image>
              <div class="product-info">
                <div class="product-name">{{ row.name }}</div>
                <div class="product-no">{{ row.productNo }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="分类" prop="categoryName" width="120" />
        <el-table-column label="售价" width="120">
          <template #default="{ row }">
            <span class="price">{{ formatMoney(row.price) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="库存" prop="stock" width="100" />
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <StatusTag :status="row.status" domain="product" />
          </template>
        </el-table-column>
        <el-table-column label="创建时间" prop="createTime" width="180" />
        <el-table-column label="操作" width="220" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="router.push(`/products/edit/${row.id}`)">编辑</el-button>
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
.product-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}
.product-thumb {
  width: 56px;
  height: 56px;
  border-radius: 8px;
  flex-shrink: 0;
  border: 1px solid var(--border);
}
.product-thumb-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f5f0eb;
  color: var(--text-light);
  font-size: 12px;
}
.product-name {
  font-weight: 500;
  color: var(--text-dark);
}
.product-no {
  font-size: 12px;
  color: var(--text-light);
  margin-top: 2px;
}
.price {
  color: var(--primary);
  font-weight: 600;
}
</style>
