<script setup lang="ts">
defineProps<{
  identity: 'platform' | 'shop' | 'temple'
  label: string
}>()

const assetBase = import.meta.env.BASE_URL
</script>

<template>
  <span class="ax-brand-logo" role="img" :aria-label="label">
    <img class="ax-brand-logo__light" :src="`${assetBase}logos/logo-${identity}-light.svg`" alt="" width="96" height="96" />
    <img class="ax-brand-logo__dark" :src="`${assetBase}logos/logo-${identity}-dark.svg`" alt="" width="96" height="96" />
  </span>
</template>

<style scoped>
.ax-brand-logo {
  display: inline-flex;
  flex-shrink: 0;
  vertical-align: middle;
  line-height: 0;
}
.ax-brand-logo img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.ax-brand-logo__light {
  display: block;
}
.ax-brand-logo__dark {
  display: none;
}
:global(html[data-theme='dark'] .ax-brand-logo__light) {
  display: none;
}
:global(html[data-theme='dark'] .ax-brand-logo__dark) {
  display: block;
}
</style>
