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
    emptyDescription?: string
    emptyHint?: string
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
    height: undefined,
    emptyDescription: '暂无数据',
    emptyHint: '调整筛选条件，或稍后再来查看。'
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
  <div class="aui-data-table" :class="{ 'is-loading': loading }">
    <span class="aui-data-table__status" role="status" aria-live="polite" aria-atomic="true">{{ loading ? (data.length ? '正在更新列表' : '正在加载列表') : '' }}</span>
    <div class="aui-data-table__scroller" :aria-busy="loading">
      <el-table
        v-loading="loading && data.length > 0"
        element-loading-text="正在更新列表"
        :data="data"
        :row-key="rowKey"
        :height="height"
        :stripe="false"
        :border="false"
        style="width: 100%"
        :header-cell-style="{ background: 'var(--color-bg-tertiary, #faf6f0)', color: 'var(--color-text-secondary, #6a5a4a)', fontWeight: 'var(--type-weight-semibold)' }"
        :cell-style="{ color: 'var(--color-text-primary, #2a1e1a)' }"
        @sort-change="changeSort"
      >
        <el-table-column v-if="selection" type="selection" width="48" />
        <el-table-column v-if="showIndex" type="index" label="#" width="56" />
        <slot />
        <template #empty>
          <div v-if="loading" class="aui-table-skeleton" aria-hidden="true">
            <div v-for="row in 5" :key="row" class="aui-table-skeleton__row">
              <span class="aui-table-skeleton__dot" /><span /><span /><span />
            </div>
          </div>
          <slot v-else name="empty">
            <div class="aui-table-empty">
              <div class="aui-table-empty__mark" aria-hidden="true">
                <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="7" y="5" width="18" height="23" rx="4"/><path d="M12 12h8M12 17h8M12 22h4"/></svg>
              </div>
              <p class="aui-table-empty__title">{{ emptyDescription }}</p>
              <p v-if="emptyHint" class="aui-table-empty__hint">{{ emptyHint }}</p>
            </div>
          </slot>
        </template>
      </el-table>
    </div>
    <div v-if="showPagination && total > 0" class="aui-data-table__pagination">
      <el-pagination
        background
        :disabled="loading"
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
.aui-data-table__status {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  overflow: hidden;
  clip-path: inset(50%);
  white-space: nowrap;
}
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
:deep(.el-table__empty-text) { width: 100%; line-height: 1.6; }
.aui-table-skeleton { width: 100%; padding: 4px 18px 10px; }
.aui-table-skeleton__row {
  display: grid;
  grid-template-columns: 28px minmax(50px, 2fr) minmax(40px, 1fr) minmax(30px, 1fr);
  align-items: center;
  gap: 20px;
  min-height: 49px;
  border-bottom: 1px solid var(--color-border-divider);
}
.aui-table-skeleton__row > span {
  width: 76%;
  height: 9px;
  background: var(--admin-surface-hover);
  border-radius: 4px;
}
.aui-table-skeleton__row:nth-child(even) > span { width: 56%; }
.aui-table-skeleton__row > .aui-table-skeleton__dot { width: 26px; height: 26px; border-radius: 8px; }
.aui-table-empty { padding: 34px 20px 38px; }
.aui-table-empty__mark {
  width: 52px;
  height: 52px;
  display: grid;
  place-items: center;
  margin: 0 auto 14px;
  color: var(--admin-accent);
  background: color-mix(in srgb, var(--admin-accent) 8%, var(--admin-surface));
  border: 1px solid color-mix(in srgb, var(--admin-accent) 24%, var(--admin-border));
  border-radius: 17px 17px 10px 10px;
}
.aui-table-empty__mark svg { width: 30px; height: 30px; }
.aui-table-empty__title { margin: 0; color: var(--admin-text-secondary); font-size: var(--type-size-body); font-weight: var(--type-weight-semibold); }
.aui-table-empty__hint { margin: 6px 0 0; color: var(--admin-text-tertiary); font-size: var(--type-size-caption); }
@media (prefers-reduced-motion: no-preference) {
  .aui-table-skeleton { animation: aui-table-breathe 1.8s ease-in-out infinite alternate; }
}
@keyframes aui-table-breathe { from { opacity: .55; } to { opacity: 1; } }
:deep(.el-table tr),
:deep(.el-table td.el-table__cell),
:deep(.el-table th.el-table__cell.is-leaf) {
  background-color: transparent;
  border-bottom: 1px solid var(--color-border-divider, var(--admin-border, var(--border, #e8e0d8)));
}
/* Sticky columns overlap scrolling cells and must paint an opaque theme surface. */
:deep(.el-table td.el-table__cell.el-table-fixed-column--left),
:deep(.el-table td.el-table__cell.el-table-fixed-column--right) {
  background-color: var(--admin-surface, var(--color-bg-secondary, #fff));
}
:deep(.el-table .el-table__body tr.current-row > td.el-table__cell) {
  background-color: color-mix(in srgb, var(--admin-primary) 7%, var(--admin-surface));
}
:deep(.el-table .el-table__body tr:focus-within > td.el-table__cell) {
  background-color: var(--admin-surface-muted, var(--color-bg-tertiary, #faf6f0));
}
:deep(.el-table--enable-row-hover .el-table__body tr:hover > td.el-table__cell),
:deep(.el-table .el-table__body tr.hover-row > td.el-table__cell) {
  background-color: var(--color-bg-tertiary, #faf6f0) !important;
}
:deep(.el-table__inner-wrapper::before) { display: none; }
@media (max-width: 767px) {
  .aui-data-table__pagination {
    justify-content: flex-start;
  }
}
</style>
