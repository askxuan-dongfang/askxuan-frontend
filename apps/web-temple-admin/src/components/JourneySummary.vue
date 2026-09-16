<script setup lang="ts">
import {ref,onMounted,onUnmounted} from 'vue'
import client from '@/api/client'
const counts=ref<Record<string,number>>(),error=ref('');let active=true
async function load(){try{const data=await client.get<{counts:Record<string,number>}>('/bookings/journeys',{params:{filter:'all',page:1}});if(active){counts.value=data.counts;error.value=''}}catch(e){if(active)error.value=(e as Error).message}}
onMounted(load);onUnmounted(()=>{active=false})
</script>
<template><section class="df-card journey-summary"><div><h3>服务履约</h3><p v-if="counts">{{counts.confirmed}} 待执行 · {{counts.executing}} 执行中 · {{counts.revision}} 待补充 · {{counts.receipt}} 待信众确认</p><p v-else-if="!error">正在读取履约概览…</p><p v-else role="status">履约概览读取失败 <button @click="load">重试</button></p></div><router-link to="/fulfillment">进入履约工作台 ↗</router-link></section></template>
<style scoped>.journey-summary{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:18px 22px;margin-bottom:20px;border-left:3px solid var(--el-color-primary)}h3{margin:0 0 7px}p{margin:0;color:var(--el-text-color-secondary)}a{color:var(--el-color-primary);white-space:nowrap}button{color:var(--el-color-primary);background:none;border:0;cursor:pointer}@media(max-width:600px){.journey-summary{align-items:flex-start;flex-direction:column}}</style>
