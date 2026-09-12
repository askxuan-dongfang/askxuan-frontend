<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue'
import { getThemePreference, isThemePreference, setThemePreference, subscribeThemePreference } from '../theme'

const preference = ref(getThemePreference())
const unsubscribe = subscribeThemePreference(value => { preference.value = value })
onBeforeUnmount(unsubscribe)
function changeAppearance(event: Event) {
  const value = (event.target as HTMLSelectElement).value
  if (isThemePreference(value)) setThemePreference(value)
}
</script>

<template>
  <label class="ax-appearance">
    <svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><circle cx="12" cy="12" r="8"/><path d="M12 4a8 8 0 0 1 0 16V4Z" fill="currentColor" stroke="none"/></svg>
    <span>外观</span>
    <select :value="preference" aria-label="外观" @change="changeAppearance">
      <option value="light">浅色</option>
      <option value="dark">深色</option>
      <option value="system">跟随系统</option>
    </select>
  </label>
</template>
