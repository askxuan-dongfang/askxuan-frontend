<script setup lang="ts">
import type { Component } from 'vue'
import { computed } from 'vue'
import { CaretTop, CaretBottom } from '@element-plus/icons-vue'

type Tone = 'brand' | 'accent' | 'success' | 'warning' | 'info'

const props = withDefaults(
  defineProps<{
    title: string
    value: string | number
    icon?: Component
    tone?: Tone
    suffix?: string
    trend?: number
  }>(),
  { tone: 'brand', suffix: '', trend: undefined }
)

const toneColor = computed(() => {
  const map: Record<Tone, string> = {
    brand: '#C45A3C',
    accent: '#C8A96E',
    success: '#5B8C5A',
    warning: '#D4A843',
    info: '#8A7A6A'
  }
  return map[props.tone]
})
const trendUp = computed(() => (props.trend ?? 0) >= 0)
</script>

<template>
  <div class="df-stat-card df-card">
    <div class="df-stat-icon" :style="{ background: toneColor + '1a', color: toneColor }">
      <el-icon v-if="icon" :size="22"><component :is="icon" /></el-icon>
    </div>
    <div class="df-stat-body">
      <div class="df-stat-title">{{ title }}</div>
      <div class="df-stat-value">
        {{ value }}<span v-if="suffix" class="df-stat-suffix">{{ suffix }}</span>
      </div>
      <div v-if="trend !== undefined" class="df-stat-trend" :class="{ up: trendUp, down: !trendUp }">
        <el-icon><CaretTop v-if="trendUp" /><CaretBottom v-else /></el-icon>
        {{ Math.abs(trend) }}% 较上周
      </div>
    </div>
  </div>
</template>

<style scoped>
.df-stat-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
}
.df-stat-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.df-stat-body {
  flex: 1;
  min-width: 0;
}
.df-stat-title {
  font-size: 13px;
  color: #8a7a6a;
}
.df-stat-value {
  font-family: 'Noto Serif SC', serif;
  font-size: 26px;
  font-weight: 700;
  color: #2a1e1a;
  line-height: 1.3;
  margin-top: 2px;
}
.df-stat-suffix {
  font-size: 14px;
  font-weight: 500;
  color: #6a5a4a;
  margin-left: 4px;
}
.df-stat-trend {
  display: flex;
  align-items: center;
  gap: 2px;
  font-size: 12px;
  margin-top: 4px;
}
.df-stat-trend.up {
  color: #5b8c5a;
}
.df-stat-trend.down {
  color: #c45a3c;
}
</style>
