<script lang="ts">
export default {
  name: 'AdminPageHeader',
  props: {
    title: { type: String, required: true },
    subtitle: { type: String, default: '' }
  }
}
</script>

<template>
  <header class="aui-page-header">
    <div class="aui-page-header__main">
      <h1 class="aui-page-header__title">{{ title }}</h1>
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
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 20px;
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
  font-family: var(--font-serif, 'Noto Serif SC', 'Songti SC', serif);
  font-size: 22px;
  font-weight: 700;
  letter-spacing: 1px;
  line-height: 1.35;
}
.aui-page-header__title::before {
  width: 4px;
  height: 20px;
  margin-right: 10px;
  display: inline-block;
  flex: 0 0 4px;
  content: '';
  background: linear-gradient(180deg, var(--admin-primary, #c45a3c), var(--admin-accent, #c8a96e));
  border-radius: 999px;
}
.aui-page-header__subtitle {
  margin: 6px 0 0 14px;
  color: var(--color-text-tertiary, var(--admin-text-tertiary, var(--text-light, #8a7a6a)));
  font-size: 13px;
  line-height: 1.6;
}
.aui-page-header__actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
  flex-wrap: wrap;
}
@media (max-width: 767px) {
  .aui-page-header {
    align-items: stretch;
    flex-direction: column;
    padding-bottom: 14px;
  }
  .aui-page-header__title {
    font-size: 20px;
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
