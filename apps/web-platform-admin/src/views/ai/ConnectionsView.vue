<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
const links = [{path:'/ai/connections/models',title:'大模型'},{path:'/ai/connections/search',title:'联网搜索'},{path:'/ai/connections/knowledge',title:'知识模型'}]
</script>
<template><div class="dfx-page connections-workspace"><PageHeader title="模型与连接" subtitle="统一管理问事、联网检索及 WeKnora 使用的服务连接"/><nav aria-label="连接类型" class="connection-tabs"><router-link v-for="item in links" :key="item.path" :to="item.path">{{item.title}}</router-link></nav><router-view/></div></template>
<style scoped>.connections-workspace{min-width:0}.connection-tabs{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 20px}.connection-tabs a{padding:10px 18px;border-radius:8px;color:var(--el-text-color-regular);text-decoration:none;min-height:44px;box-sizing:border-box}.connection-tabs .router-link-active{background:var(--el-color-primary-light-9);color:var(--el-color-primary);font-weight:600}.connection-tabs a:focus-visible{outline:2px solid var(--el-color-primary);outline-offset:2px}</style>
