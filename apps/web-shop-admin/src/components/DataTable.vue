<script setup lang="ts">
// 通用数据卡片：标题 + 插槽内容（描述列表 / 表格等）
withDefaults(
  defineProps<{
    title?: string
    padding?: boolean
  }>(),
  { title: '', padding: true }
)
</script>

<template>
  <div class="df-card data-card">
    <div v-if="title || $slots.header" class="data-card-header">
      <slot name="header">
        <h3>{{ title }}</h3>
      </slot>
      <slot name="extra" />
    </div>
    <div class="data-card-body" :class="{ 'no-padding': !padding }">
      <slot />
    </div>
  </div>
</template>

<style scoped>
.data-card {
  overflow: hidden;
}
.data-card-header {
  padding: 16px 24px;
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.data-card-header h3 {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-dark);
  margin: 0;
}
.data-card-body {
  padding: 24px;
}
.data-card-body.no-padding {
  padding: 0;
}
</style>
