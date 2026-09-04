<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{
  items: any[]
  loading?: boolean
  total?: number
  page?: number
  size?: number
  emptyText?: string
}>(), {
  loading: false,
  total: 0,
  page: 1,
  size: 20,
  emptyText: '当前筛选下暂无数据'
})

const emit = defineEmits<{
  (event: 'update:page', value: number): void
  (event: 'change', value: number): void
}>()

const pageCount = computed(() => Math.max(1, Math.ceil(props.total / props.size)))

function changePage(nextPage: number) {
  const value = Math.min(pageCount.value, Math.max(1, nextPage))
  emit('update:page', value)
  emit('change', value)
}
</script>

<template>
  <div class="mobile-task-list" :aria-busy="loading">
    <div v-if="loading" class="mobile-task-empty" role="status">正在加载任务…</div>
    <template v-else-if="items.length">
      <slot v-for="(item, index) in items" :key="(item as any)?.id ?? index" name="item" :item="item" :index="index" />
      <div v-if="total > size" class="mobile-task-pager" aria-label="分页">
        <el-button :disabled="page <= 1" @click="changePage(page - 1)">上一页</el-button>
        <span>第 {{ page }} / {{ pageCount }} 页，共 {{ total }} 条</span>
        <el-button :disabled="page >= pageCount" @click="changePage(page + 1)">下一页</el-button>
      </div>
    </template>
    <div v-else class="mobile-task-empty">{{ emptyText }}</div>
  </div>
</template>
