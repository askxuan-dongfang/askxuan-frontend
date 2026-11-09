<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
</script>
<template><div class="dfx-page"><PageHeader :title='$t("功能权限")' /><el-empty :description='$t("此账号尚未分配功能权限，请联系超级管理员分配后重新登录。")' /></div></template>
