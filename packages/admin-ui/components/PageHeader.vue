<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import FeatureIcon from './FeatureIcon.vue'
defineProps<{title: string; subtitle?: string}>()
const route = useRoute()
const feature = computed(() => {
  const path = route.path
  if (/review|comment|report$/.test(path)) return 'review'
  if (/onboarding|role|account/.test(path)) return 'shield'
  if (/finance|wallet|earnings|reconcile/.test(path)) return 'wallet'
  if (/order|booking|fulfillment|blessing/.test(path)) return 'orders'
  if (/logistics|returns/.test(path)) return 'delivery'
  if (/master|user/.test(path)) return 'people'
  if (/gallery|banner|design|media/.test(path)) return 'media'
  if (/temple/.test(path)) return 'building'
  if (/marketing|coupon|rewards|points/.test(path)) return 'gift'
  if (/reports|statistics/.test(path)) return 'chart'
  if (/settings\/ai/.test(path)) return 'ai'
  if (/settings/.test(path)) return 'settings'
  if (/dashboard|^\/commerce$/.test(path)) return 'home'
  return 'catalog'
})
</script>

<template>
  <header class="aui-page-header">
    <div class="aui-page-header__main">
      <h1 class="aui-page-header__title"><FeatureIcon :name="feature" :size="24" /><span>{{ title }}</span></h1>
      <p v-if="subtitle" class="aui-page-header__subtitle">{{ subtitle }}</p>
    </div>
    <div
      v-if="$slots.actions || $slots.extra || $slots.default"
      class="aui-page-header__actions"
    >
      <slot name="actions" />
      <slot name="extra" />
      <slot />
    </div>
  </header>
</template>

<style scoped>
.aui-page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: var(--admin-section-gap);
  padding-bottom: 16px;
  border-bottom: 1px solid var(--color-border-divider, var(--admin-border, var(--border, #e8e0d8)));
}
.aui-page-header__main {
  min-width: 0;
}
.aui-page-header__title {
  display: flex;
  align-items: center;
  margin: 0;
  color: var(--color-text-primary, var(--text-dark, #2a1e1a));
  font-family: var(--font-serif);
  font-size: clamp(var(--type-size-page), 2vw, var(--type-size-hero));
  font-weight: var(--type-weight-semibold);
  letter-spacing: .01em;
  line-height: 1.4;
}
.aui-page-header__title { align-items: flex-start; gap: 10px; }
.aui-page-header__title > svg { flex: none; margin-top: calc((1.4em - 24px) / 2); color: var(--color-brand, var(--admin-primary)); }
.aui-page-header__title > span { min-width: 0; overflow-wrap: anywhere; }
.aui-page-header__subtitle {
  margin: 6px 0 0 34px;
  color: var(--color-text-secondary, var(--admin-text-secondary, var(--text-medium, #66736c)));
  font-size: var(--type-size-label);
  line-height: 1.6;
}
.aui-page-header__actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: var(--admin-action-gap);
  flex-wrap: wrap;
  flex-shrink: 0;
  max-width: 100%;
}
@media (max-width: 767px) {
  .aui-page-header {
    align-items: stretch;
    flex-direction: column;
    padding-bottom: 14px;
  }
  .aui-page-header__title {
    font-size: var(--type-size-section);
  }
  .aui-page-header__actions {
    justify-content: stretch;
  }
  .aui-page-header__actions :deep(.el-button) {
    min-height: 40px;
    flex: 1 1 auto;
    margin-left: 0;
  }
}
</style>
