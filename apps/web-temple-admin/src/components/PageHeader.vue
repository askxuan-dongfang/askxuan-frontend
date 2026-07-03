<script setup lang="ts">
defineProps<{ title: string; subtitle?: string }>()
</script>

<template>
  <div class="df-page-header">
    <div class="df-ph-left">
      <h2 class="df-ph-title">{{ title }}</h2>
      <p v-if="subtitle" class="df-ph-sub">{{ subtitle }}</p>
    </div>
    <div class="df-ph-actions">
      <slot />
    </div>
  </div>
</template>

<style scoped>
.df-page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 20px;
}
.df-ph-title {
  font-size: 20px;
  font-weight: 700;
  color: #2a1e1a;
  display: flex;
  align-items: center;
}
.df-ph-title::before {
  content: '';
  display: inline-block;
  width: 4px;
  height: 20px;
  background: linear-gradient(180deg, #c45a3c 0%, #c8a96e 100%);
  border-radius: 2px;
  margin-right: 10px;
}
.df-ph-sub {
  margin: 6px 0 0 14px;
  font-size: 13px;
  color: #8a7a6a;
}
.df-ph-actions {
  display: flex;
  gap: 10px;
  align-items: center;
}
</style>
