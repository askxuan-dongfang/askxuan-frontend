<script setup lang="ts">
// 指标统计卡片
import { computed } from 'vue'

type CardColor = 'primary' | 'warning' | 'success' | 'accent' | 'info'

const props = withDefaults(
  defineProps<{
    label: string
    value: string | number
    change?: string
    up?: boolean
    color?: CardColor
    icon?: string
  }>(),
  { color: 'primary', up: true, change: '', icon: '' }
)

const colorClass = computed(() => `stat-${props.color}`)
</script>

<template>
  <div class="stat-card">
    <div class="stat-card-header">
      <span class="stat-card-label">{{ label }}</span>
      <div class="stat-card-icon" :class="colorClass">
        <el-icon :size="20"><component :is="icon" v-if="icon" /></el-icon>
      </div>
    </div>
    <div class="stat-card-value">{{ value }}</div>
    <div v-if="change" class="stat-card-change" :class="up ? 'up' : 'down'">
      <el-icon><CaretTop v-if="up" /><CaretBottom v-else /></el-icon>
      {{ change }}
    </div>
  </div>
</template>

<style scoped>
.stat-card {
  background: var(--card-bg);
  border-radius: var(--radius-lg);
  padding: 20px 24px;
  border: 1px solid var(--border);
  box-shadow: var(--shadow-sm);
  transition: var(--transition);
}
.stat-card:hover {
  box-shadow: var(--shadow);
  transform: translateY(-1px);
}
.stat-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}
.stat-card-label {
  font-size: 13px;
  color: var(--text-light);
}
.stat-card-icon {
  width: 40px;
  height: 40px;
  border-radius: var(--radius);
  display: flex;
  align-items: center;
  justify-content: center;
}
.stat-primary { background: var(--primary-light); color: var(--primary); }
.stat-warning { background: var(--warning-light); color: var(--warning); }
.stat-success { background: var(--success-light); color: var(--success); }
.stat-accent { background: var(--accent-light); color: var(--accent); }
.stat-info { background: var(--info-light); color: var(--info); }
.stat-card-value {
  font-size: 28px;
  font-weight: 700;
  color: var(--text-dark);
  line-height: 1.2;
}
.stat-card-change {
  font-size: 12px;
  margin-top: 8px;
  display: flex;
  align-items: center;
  gap: 4px;
}
.stat-card-change.up { color: var(--success); }
.stat-card-change.down { color: var(--danger); }
</style>
