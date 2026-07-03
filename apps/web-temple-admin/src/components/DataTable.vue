<script setup lang="ts" generic="T extends Record<string, any>">
const props = withDefaults(
  defineProps<{
    data: T[]
    loading?: boolean
    total?: number
    page?: number
    size?: number
    rowKey?: string
    height?: string
  }>(),
  { loading: false, total: 0, page: 1, size: 20, rowKey: 'id', height: undefined }
)

const emit = defineEmits<{ change: [payload: { page: number; size: number }] }>()

function onCurrentChange(p: number) {
  emit('change', { page: p, size: props.size })
}
function onSizeChange(s: number) {
  emit('change', { page: 1, size: s })
}
</script>

<template>
  <div class="df-data-table">
    <el-table
      v-loading="loading"
      :data="data"
      :row-key="rowKey"
      :height="height"
      stripe
      border
      style="width: 100%"
    >
      <slot />
      <template #empty>
        <el-empty description="暂无数据" :image-size="72" />
      </template>
    </el-table>
    <div v-if="total > 0" class="df-pagination">
      <el-pagination
        background
        :current-page="page"
        :page-size="size"
        :total="total"
        :page-sizes="[10, 20, 50]"
        layout="total, sizes, prev, pager, next, jumper"
        @current-change="onCurrentChange"
        @size-change="onSizeChange"
      />
    </div>
  </div>
</template>

<style scoped>
.df-pagination {
  display: flex;
  justify-content: flex-end;
  padding: 16px 0 4px;
}
</style>
