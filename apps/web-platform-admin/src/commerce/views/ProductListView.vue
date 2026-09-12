<script setup lang="ts">
// 商品列表
import { ref, reactive, onMounted, computed } from "vue";
import { useRouter } from "vue-router";
import { ElMessage, ElMessageBox } from "element-plus";
import PageHeader from "@/components/PageHeader.vue";
import StatusTag from "@/components/StatusTag.vue";
import { productApi, type ProductListParams } from "@/commerce/api/product";
import { categoryApi } from "@/commerce/api/category";
import { formatMoney } from "@/commerce/utils/format";
import type { Product, ProductCategory, ProductStatus } from "@/commerce/types";

const router = useRouter();
const loading = ref(false);
const list = ref<Product[]>([]);
const total = ref(0);
const viewMode = ref("table");
const loadError = ref("");
const busyIds = ref<number[]>([]);
let generation = 0;
const pageStats = computed(() => [
  { label: "本页商品", value: list.value.length },
  {
    label: "本页在售有货",
    value: list.value.filter((p) => p.status === "on_shelf" && p.stock > 0)
      .length,
  },
  {
    label: "本页库存为零",
    value: list.value.filter((p) => p.stock === 0).length,
  },
  {
    label: "本页待补主图",
    value: list.value.filter((p) => !p.mainImage).length,
  },
]);
const categories = ref<ProductCategory[]>([]);

const query = reactive<ProductListParams>({
  keyword: "",
  categoryId: undefined,
  status: "",
  page: 1,
  size: 20,
});

async function loadCategories() {
  try {
    const res = await categoryApi.list({ page: 1, size: 100 });
    categories.value = res.list || [];
  } catch {
    categories.value = [];
  }
}

async function loadList() {
  const current = ++generation;
  loading.value = true;
  loadError.value = "";
  try {
    const res = await productApi.list({ ...query });
    if (current !== generation) return;
    list.value = res.list || [];
    total.value = res.total || 0;
  } catch {
    if (current !== generation) return;
    loadError.value = "商品加载失败，请重试";
    list.value = [];
    total.value = 0;
  } finally {
    if (current === generation) loading.value = false;
  }
}

function handleSearch() {
  query.page = 1;
  loadList();
}

function handleReset() {
  query.keyword = "";
  query.categoryId = undefined;
  query.status = "";
  query.page = 1;
  loadList();
}

function handlePageChange(p: number) {
  query.page = p;
  loadList();
}

function handleSizeChange(s: number) {
  query.size = s;
  query.page = 1;
  loadList();
}

async function handleStatusChange(row: any, status: ProductStatus) {
  if (busyIds.value.includes(row.id)) return;
  busyIds.value.push(row.id);
  try {
    await productApi.updateStatus(row.id, status as "on_shelf" | "off_shelf");
    ElMessage.success("状态已更新");
    loadList();
  } catch {
    // API client reports the failure.
  } finally {
    busyIds.value = busyIds.value.filter((id) => id !== row.id);
  }
}

async function handleDelete(row: any) {
  try {
    await ElMessageBox.confirm(`确认删除商品「${row.name}」吗？`, "提示", {
      confirmButtonText: "删除",
      cancelButtonText: "取消",
      type: "warning",
    });
    await productApi.remove(row.id);
    ElMessage.success("删除成功");
    loadList();
  } catch {
    // 取消或失败
  }
}

onMounted(() => {
  loadCategories();
  loadList();
});
</script>

<template>
  <div class="page-wrap">
    <PageHeader
      title="商品列表"
      subtitle="商品内容、陈列预览、上下架与库存，一处管理"
    >
      <template #extra>
        <el-button
          type="primary"
          @click="router.push('/commerce/products/edit')"
        >
          <el-icon><Plus /></el-icon>
          新建商品
        </el-button>
      </template>
    </PageHeader>

    <div class="catalog-overview">
      <div v-for="item in pageStats" :key="item.label">
        <small>{{ item.label }}</small
        ><strong>{{ item.value }}</strong>
      </div>
    </div>
    <el-alert
      v-if="loadError"
      :title="loadError"
      type="error"
      :closable="false"
      show-icon
    />
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
          <el-select
            v-model="query.status"
            placeholder="全部状态"
            clearable
            style="width: 140px"
          >
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
      <div class="catalog-view-switch">
        <div>
          <h2>商品陈列</h2>
          <span>共 {{ total }} 件 · 分类与标签同步显示在顾客端</span>
        </div>
        <el-radio-group v-model="viewMode"
          ><el-radio-button value="table">管理列表</el-radio-button
          ><el-radio-button value="cards"
            >顾客视角</el-radio-button
          ></el-radio-group
        >
      </div>
      <div
        v-if="viewMode === 'cards'"
        class="catalog-preview-grid"
        v-loading="loading"
      >
        <article v-for="row in list" :key="row.id">
          <div class="catalog-preview-image">
            <el-image :src="row.mainImage" fit="cover"
              ><template #error><span>物</span></template></el-image
            ><small v-if="row.stock === 0">暂时售罄</small
            ><small v-else-if="row.tags">{{
              row.tags.split(/[,，]/)[0]
            }}</small>
          </div>
          <div class="catalog-preview-copy">
            <small>{{ row.categoryName || "东方好物" }}</small>
            <h3>{{ row.name }}</h3>
            <el-tag v-if="row.isExperience" type="warning" size="small"
              >体验商品</el-tag
            >

            <strong>{{ formatMoney(row.price) }}</strong
            ><StatusTag :status="row.status" domain="product" />
          </div>
          <div class="catalog-preview-actions">
            <el-button
              text
              type="primary"
              @click="router.push(`/commerce/products/edit/${row.id}`)"
              >编辑展示</el-button
            ><el-button
              text
              :disabled="busyIds.includes(row.id)"
              @click="
                handleStatusChange(
                  row,
                  row.status === 'on_shelf' ? 'off_shelf' : 'on_shelf',
                )
              "
              >{{ row.status === "on_shelf" ? "下架" : "上架" }}</el-button
            >
          </div>
        </article>
        <el-empty
          v-if="!list.length && !loading"
          description="当前筛选下暂无商品"
        />
      </div>
      <el-table
        v-else
        v-loading="loading"
        :data="list"
        style="width: 100%"
        empty-text="暂无商品"
      >
        <el-table-column label="商品" min-width="280">
          <template #default="{ row }">
            <div class="product-cell">
              <el-image :src="row.mainImage" fit="cover" class="product-thumb">
                <template #error>
                  <div class="product-thumb-placeholder">无图</div>
                </template>
              </el-image>
              <div class="product-info">
                <div class="product-name">
                  {{ row.name }}
                  <el-tag v-if="row.isExperience" type="warning" size="small"
                    >体验商品</el-tag
                  >
                </div>
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
            <el-button
              text
              type="primary"
              size="small"
              @click="router.push(`/commerce/products/edit/${row.id}`)"
              >编辑</el-button
            >
            <el-button
              v-if="row.status !== 'on_shelf'"
              text
              type="success"
              size="small"
              :disabled="busyIds.includes(row.id)"
              @click="handleStatusChange(row, 'on_shelf')"
              >上架</el-button
            >
            <el-button
              v-else
              text
              type="warning"
              size="small"
              :disabled="busyIds.includes(row.id)"
              @click="handleStatusChange(row, 'off_shelf')"
              >下架</el-button
            >
            <el-button
              text
              type="danger"
              size="small"
              @click="handleDelete(row)"
              >删除</el-button
            >
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
.catalog-overview {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
  margin: 0 0 22px;
}
.catalog-overview > div {
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 20px;
  background: var(--admin-surface);
}
.catalog-overview small {
  display: block;
  color: var(--text-light);
  font-size: 12px;
}
.catalog-overview strong {
  display: block;
  font: 600 29px var(--font-serif);
  margin-top: 12px;
  color: var(--primary);
}
.catalog-view-switch {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
  padding: 20px 24px;
  border-bottom: 1px solid var(--border);
}
.catalog-view-switch h2 {
  font: 600 19px var(--font-serif);
  margin: 0 0 6px;
}
.catalog-view-switch span {
  font-size: 12px;
  color: var(--text-light);
}
.catalog-preview-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 20px;
  padding: 22px;
}
.catalog-preview-grid > article {
  border: 1px solid var(--border);
  border-radius: 17px;
  overflow: hidden;
  background: var(--admin-surface);
}
.catalog-preview-image {
  aspect-ratio: 1;
  position: relative;
  background: var(--admin-surface-muted);
}
.catalog-preview-image > .el-image {
  width: 100%;
  height: 100%;
}
.catalog-preview-image span {
  display: grid;
  place-items: center;
  height: 100%;
  font: 40px var(--font-serif);
  color: var(--admin-accent);
}
.catalog-preview-image > small {
  position: absolute;
  left: 10px;
  top: 10px;
  padding: 5px 9px;
  background: rgba(var(--admin-surface-rgb),.87);
  border-radius: 6px;
  color: var(--admin-accent);
  max-width: 90%;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 11px;
}
.catalog-preview-copy {
  padding: 14px;
}
.catalog-preview-copy > small {
  font-size: 11px;
  color: var(--text-light);
}
.catalog-preview-copy h3 {
  font: 500 14px/1.55 var(--font-sans);
  margin: 7px 0;
}
.catalog-preview-copy p {
  font-size: 12px;
  color: var(--text-light);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.catalog-preview-copy > strong {
  font-size: 21px;
  color: var(--primary);
  margin-right: 12px;
}
.catalog-preview-actions {
  display: flex;
  justify-content: space-between;
  border-top: 1px solid var(--border);
  padding: 8px 12px;
}
@media (max-width: 850px) {
  .catalog-overview {
    grid-template-columns: 1fr 1fr;
  }
  .catalog-preview-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 12px;
    padding: 12px;
  }
  .catalog-preview-copy {
    padding: 10px;
  }
  .catalog-preview-copy h3 {
    font-size: 15px;
  }
  .catalog-view-switch {
    padding: 16px;
  }
}

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
  background: var(--admin-bg);
  color: var(--text-light);
  font-size: var(--type-size-caption);
}
.product-name {
  font-weight: var(--type-weight-medium);
  color: var(--text-dark);
}
.product-no {
  font-size: var(--type-size-caption);
  color: var(--text-light);
  margin-top: 2px;
}
.price {
  color: var(--primary);
  font-weight: var(--type-weight-semibold);
}
</style>
