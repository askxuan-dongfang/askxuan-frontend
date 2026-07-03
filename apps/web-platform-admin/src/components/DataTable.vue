<template>
  <div class="data-table">
    <el-table
      v-loading="loading"
      :data="data"
      :stripe="false"
      :border="false"
      style="width: 100%"
      :header-cell-style="{ background: 'var(--color-bg-tertiary)', color: 'var(--color-text-secondary)', fontWeight: 600 }"
      :cell-style="{ color: 'var(--color-text-primary)' }"
      @sort-change="onSortChange"
    >
      <el-table-column v-if="selection" type="selection" width="48" />
      <el-table-column v-if="showIndex" type="index" label="#" width="56" />
      <slot />
      <template #empty>
        <el-empty description="暂无数据" :image-size="80" />
      </template>
    </el-table>
    <div v-if="showPagination" class="data-table__pagination">
      <el-pagination
        v-model:current-page="innerPage"
        v-model:page-size="innerSize"
        :total="total"
        :page-sizes="pageSizes"
        layout="total, sizes, prev, pager, next, jumper"
        background
        @current-change="onPageChange"
        @size-change="onSizeChange"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'

const props = withDefaults(
  defineProps<{
    data: any[]
    loading?: boolean
    total?: number
    page?: number
    size?: number
    pageSizes?: number[]
    showPagination?: boolean
    showIndex?: boolean
    selection?: boolean
  }>(),
  {
    loading: false,
    total: 0,
    page: 1,
    size: 20,
    pageSizes: () => [10, 20, 50, 100],
    showPagination: true,
    showIndex: false,
    selection: false
  }
)

const emit = defineEmits<{
  (e: 'update:page', val: number): void
  (e: 'update:size', val: number): void
  (e: 'change', page: number, size: number): void
  (e: 'sort-change', val: { prop: string; order: string }): void
}>()

const innerPage = ref(props.page)
const innerSize = ref(props.size)

watch(
  () => props.page,
  (v) => (innerPage.value = v)
)
watch(
  () => props.size,
  (v) => (innerSize.value = v)
)

function onPageChange(p: number) {
  emit('update:page', p)
  emit('change', p, innerSize.value)
}
function onSizeChange(s: number) {
  emit('update:size', s)
  emit('update:page', 1)
  emit('change', 1, s)
}
function onSortChange(val: any) {
  emit('sort-change', { prop: val.prop, order: val.order })
}
</script>

<style scoped>
.data-table__pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}
:deep(.el-table) {
  background: transparent;
}
:deep(.el-table tr),
:deep(.el-table td.el-table__cell),
:deep(.el-table th.el-table__cell.is-leaf) {
  background-color: transparent;
  border-bottom: 1px solid var(--color-border-divider);
}
:deep(.el-table--enable-row-hover .el-table__body tr:hover > td.el-table__cell) {
  background-color: var(--color-bg-tertiary) !important;
}
:deep(.el-table__inner-wrapper::before) {
  display: none;
}
</style>
