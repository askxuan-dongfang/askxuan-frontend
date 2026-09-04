<script setup lang="ts">
const props = withDefaults(
  defineProps<{
    data: Record<string, unknown>[]
    loading?: boolean
    total?: number
    page?: number
    size?: number
    pageSizes?: number[]
    showPagination?: boolean
    showIndex?: boolean
    selection?: boolean
    rowKey?: string
    height?: string | number
  }>(),
  {
    loading: false,
    total: 0,
    page: 1,
    size: 20,
    pageSizes: () => [10, 20, 50, 100],
    showPagination: true,
    showIndex: false,
    selection: false,
    rowKey: 'id',
    height: undefined
  }
)

const emit = defineEmits<{
  'update:page': [value: number]
  'update:size': [value: number]
  change: [value: { page: number; size: number }]
  'sort-change': [value: { prop: string; order: string }]
}>()

function changePage(page: number) {
  emit('update:page', page)
  emit('change', { page, size: props.size })
}

function changeSize(size: number) {
  emit('update:size', size)
  emit('update:page', 1)
  emit('change', { page: 1, size })
}

function changeSort(value: { prop?: string | null; order?: string | null }) {
  emit('sort-change', { prop: value.prop || '', order: value.order || '' })
}
</script>

<template>
  <div class="aui-data-table">
    <div class="aui-data-table__scroller">
      <el-table
        v-loading="loading"
        :data="data"
        :row-key="rowKey"
        :height="height"
        :stripe="false"
        :border="false"
        style="width: 100%"
        :header-cell-style="{ background: 'var(--color-bg-tertiary, #faf6f0)', color: 'var(--color-text-secondary, #6a5a4a)', fontWeight: 600 }"
        :cell-style="{ color: 'var(--color-text-primary, #2a1e1a)' }"
        @sort-change="changeSort"
      >
        <el-table-column v-if="selection" type="selection" width="48" />
        <el-table-column v-if="showIndex" type="index" label="#" width="56" />
        <slot />
        <template #empty>
          <el-empty description="暂无数据" :image-size="72" />
        </template>
      </el-table>
    </div>
    <div v-if="showPagination && total > 0" class="aui-data-table__pagination">
      <el-pagination
        background
        :current-page="page"
        :page-size="size"
        :total="total"
        :page-sizes="pageSizes"
        layout="total, sizes, prev, pager, next, jumper"
        @current-change="changePage"
        @size-change="changeSize"
      />
    </div>
  </div>
</template>

<style scoped>
.aui-data-table,
.aui-data-table__scroller {
  min-width: 0;
  max-width: 100%;
}
.aui-data-table__scroller {
  overflow-x: auto;
  overscroll-behavior-inline: contain;
}
.aui-data-table__pagination {
  display: flex;
  justify-content: flex-end;
  max-width: 100%;
  padding: 16px 0 4px;
  overflow-x: auto;
}
:deep(.el-table) { background: transparent; }
:deep(.el-table tr),
:deep(.el-table td.el-table__cell),
:deep(.el-table th.el-table__cell.is-leaf) {
  background-color: transparent;
  border-bottom: 1px solid var(--color-border-divider, var(--admin-border, var(--border, #e8e0d8)));
}
:deep(.el-table--enable-row-hover .el-table__body tr:hover > td.el-table__cell) {
  background-color: var(--color-bg-tertiary, #faf6f0) !important;
}
:deep(.el-table__inner-wrapper::before) { display: none; }
@media (max-width: 767px) {
  .aui-data-table__pagination {
    justify-content: flex-start;
  }
}
</style>
