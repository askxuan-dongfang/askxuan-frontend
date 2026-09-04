<script setup lang="ts">
type Tone = 'brand' | 'primary' | 'accent' | 'success' | 'warning' | 'info' | 'danger'

const props = withDefaults(
  defineProps<{
    title?: string
    label?: string
    value: string | number
    icon?: unknown
    tone?: Tone
    color?: Tone
    iconColor?: string
    prefix?: string
    suffix?: string
    trend?: number
    change?: string
    up?: boolean
    extra?: string
  }>(),
  { title: '', label: '', tone: 'brand', prefix: '', suffix: '', change: '', extra: '' }
)

const toneColors: Record<Tone, string> = {
  brand: '#c45a3c',
  primary: '#c45a3c',
  accent: '#c8a96e',
  success: '#5b8c5a',
  warning: '#d4a843',
  info: '#6687a8',
  danger: '#b84632'
}

function resolvedLabel(): string {
  return props.label || props.title
}

function resolvedColor(): string {
  return props.iconColor || toneColors[props.color || props.tone]
}

function displayValue(): string {
  const value = typeof props.value === 'number' ? props.value.toLocaleString('zh-CN') : props.value
  return `${props.prefix}${value}${props.suffix}`
}

function trendText(): string {
  if (props.trend !== undefined) return `${Math.abs(props.trend)}% 较上周`
  return props.change || props.extra
}

function trendDirection(): 'up' | 'down' | 'neutral' {
  if (props.trend !== undefined) return props.trend >= 0 ? 'up' : 'down'
  if (props.up === undefined) return 'neutral'
  return props.up ? 'up' : 'down'
}
</script>

<template>
  <section class="aui-stat-card">
    <div
      v-if="icon"
      class="aui-stat-card__icon"
      :style="{ backgroundColor: `${resolvedColor()}1a`, color: resolvedColor() }"
      aria-hidden="true"
    >
      <el-icon :size="22"><component :is="icon" /></el-icon>
    </div>
    <div class="aui-stat-card__body">
      <div class="aui-stat-card__label">{{ resolvedLabel() }}</div>
      <div class="aui-stat-card__value">{{ displayValue() }}</div>
      <div v-if="trendText()" class="aui-stat-card__trend" :class="`is-${trendDirection()}`">
        <span v-if="trendDirection() !== 'neutral'" aria-hidden="true">{{ trendDirection() === 'up' ? '↑' : '↓' }}</span>
        {{ trendText() }}
      </div>
    </div>
  </section>
</template>

<style scoped>
.aui-stat-card {
  display: flex;
  align-items: center;
  min-width: 0;
  gap: 16px;
  padding: 20px;
  overflow: hidden;
  background: var(--color-bg-primary, var(--card-bg, #fff));
  border: 1px solid var(--color-border-divider, var(--admin-border, var(--border, #e8e0d8)));
  border-radius: var(--radius-lg, 12px);
  box-shadow: var(--shadow-sm, 0 4px 16px rgba(70, 45, 32, 0.06));
  transition: transform 180ms ease, border-color 180ms ease, box-shadow 180ms ease;
}
.aui-stat-card:hover {
  transform: translateY(-1px);
  border-color: var(--color-border-strong, #d8c9bb);
  box-shadow: var(--shadow-md, 0 8px 24px rgba(70, 45, 32, 0.1));
}
.aui-stat-card__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  border-radius: 12px;
  flex: 0 0 48px;
}
.aui-stat-card__body {
  min-width: 0;
  flex: 1;
}
.aui-stat-card__label {
  overflow: hidden;
  color: var(--color-text-tertiary, var(--text-light, #8a7a6a));
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.aui-stat-card__value {
  margin-top: 3px;
  overflow-wrap: anywhere;
  color: var(--color-text-primary, var(--text-dark, #2a1e1a));
  font-family: var(--font-serif, 'Noto Serif SC', 'Songti SC', serif);
  font-size: 26px;
  font-variant-numeric: tabular-nums;
  font-weight: 700;
  line-height: 1.25;
}
.aui-stat-card__trend {
  display: flex;
  align-items: center;
  gap: 3px;
  margin-top: 5px;
  color: var(--color-text-tertiary, var(--text-light, #8a7a6a));
  font-size: 12px;
}
.aui-stat-card__trend.is-up { color: var(--admin-success, #3f7d52); }
.aui-stat-card__trend.is-down { color: var(--admin-danger, #b84632); }
@media (prefers-reduced-motion: reduce) {
  .aui-stat-card { transition: none; }
  .aui-stat-card:hover { transform: none; }
}
</style>
