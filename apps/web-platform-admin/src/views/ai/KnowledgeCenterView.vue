<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import KnowledgeLibrary from './KnowledgeLibrary.vue'
</script>
<template><div class="dfx-page knowledge-center"><PageHeader title="知识中心" subtitle="管理 WeKnora 文档、检索、Wiki 和实体知识图谱"/><KnowledgeLibrary/></div></template>
<style scoped>.knowledge-center{min-width:0}:deep(.ops-card){background:var(--el-bg-color);border:1px solid var(--el-border-color-lighter);border-radius:12px;padding:24px}</style>
