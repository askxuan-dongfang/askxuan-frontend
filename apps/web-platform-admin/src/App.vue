<script setup lang="ts">
import { ElConfigProvider } from 'element-plus'
import { computed } from 'vue'
import { appLanguage } from './i18n'
import zhTw from 'element-plus/es/locale/lang/zh-tw'
import zhCn from 'element-plus/es/locale/lang/zh-cn'
const locale = computed(() => appLanguage.value === 'zh-Hant' ? zhTw : zhCn)
</script>

<template>
  <ElConfigProvider :locale="locale">
    <RouterView />
  </ElConfigProvider>
</template>
