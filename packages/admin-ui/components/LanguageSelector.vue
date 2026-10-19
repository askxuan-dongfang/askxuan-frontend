<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue'
import { getLanguagePreference, isLanguagePreference, languageChoices, setLanguagePreference, subscribeLanguage } from '../language'
const preference = ref(getLanguagePreference())
const unsubscribe = subscribeLanguage(() => { preference.value = getLanguagePreference() })
onBeforeUnmount(unsubscribe)
function change(event: Event) {
  const value = (event.target as HTMLSelectElement).value
  if (isLanguagePreference(value)) setLanguagePreference(value)
}
</script>

<template>
  <label class="ax-appearance">
    <span aria-hidden="true">文</span><span>{{ $t('语言') }}</span>
    <select :value="preference" :aria-label="$t('语言')" @change="change">
      <option v-for="choice in languageChoices" :key="choice.value" :value="choice.value">{{ choice.value === 'system' ? $t(choice.label) : choice.label }}</option>
    </select>
  </label>
</template>
