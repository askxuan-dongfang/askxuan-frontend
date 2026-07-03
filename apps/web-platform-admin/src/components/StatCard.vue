<template>
  <div class="stat-card dfx-card">
    <div class="stat-card__icon" :style="{ background: iconBg }">
      <el-icon :size="22"><component :is="icon" /></el-icon>
    </div>
    <div class="stat-card__body">
      <div class="stat-card__label">{{ label }}</div>
      <div class="stat-card__value dfx-serif">{{ displayValue }}</div>
      <div v-if="extra" class="stat-card__extra">{{ extra }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    label: string
    value: number | string
    icon?: any
    extra?: string
    prefix?: string
    suffix?: string
    iconColor?: string
  }>(),
  { iconColor: '#C8A96E' }
)

const iconBg = computed(() => `${props.iconColor}22`)
const displayValue = computed(() => {
  const v = props.value
  if (typeof v === 'number') {
    const formatted = v.toLocaleString('zh-CN')
    return `${props.prefix || ''}${formatted}${props.suffix || ''}`
  }
  return `${props.prefix || ''}${v}${props.suffix || ''}`
})
</script>

<style scoped>
.stat-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
  transition: transform 0.2s, border-color 0.2s;
}
.stat-card:hover {
  transform: translateY(-2px);
  border-color: var(--color-border-strong);
}
.stat-card__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 52px;
  height: 52px;
  border-radius: var(--radius-md);
  color: v-bind('iconColor');
  flex-shrink: 0;
}
.stat-card__label {
  font-size: 13px;
  color: var(--color-text-tertiary);
  margin-bottom: 6px;
}
.stat-card__value {
  font-size: 26px;
  font-weight: 700;
  color: var(--color-text-primary);
  line-height: 1.1;
}
.stat-card__extra {
  margin-top: 6px;
  font-size: 12px;
  color: var(--color-text-tertiary);
}
</style>
