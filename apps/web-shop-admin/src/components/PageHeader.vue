<script setup lang="ts">
// 页面标题头：标题 + 副标题 + 右侧操作区
withDefaults(
  defineProps<{
    title: string
    subtitle?: string
  }>(),
  { subtitle: '' }
)
</script>

<template>
  <div class="page-header-block">
    <div class="page-header-block-left">
      <h2 class="page-header-block-title">{{ title }}</h2>
      <p v-if="subtitle" class="page-header-block-subtitle">{{ subtitle }}</p>
    </div>
    <div class="page-header-block-right">
      <slot name="extra" />
    </div>
  </div>
</template>

<style scoped>
.page-header-block {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 20px;
  gap: 16px;
  flex-wrap: wrap;
}
.page-header-block-title {
  font-size: 20px;
  font-weight: 600;
  color: var(--text-dark);
  margin: 0;
}
.page-header-block-subtitle {
  font-size: 13px;
  color: var(--text-light);
  margin: 4px 0 0;
}
.page-header-block-right {
  display: flex;
  align-items: center;
  gap: 8px;
}
</style>
