<script setup lang="ts">
import { ref, watch, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import client from '@/api/client'
import PageHeader from '@/components/PageHeader.vue'
type Row = {id:string;templeName:string;masterName:string;serviceName:string;bookingDate:string;timeSlot:string;status:string;latest:string;receiptCount:number;needsRevision:number}
type Index = {list:Row[];total:number;counts:Record<string,number>}
const route=useRoute(), router=useRouter(), data=ref<Index>(), error=ref(''), loading=ref(false), search=ref('')
const labels:Record<string,string>={pending:'待接单',confirmed:'待执行',in_progress:'执行中',pending_receipt:'待信众确认',completed:'已完成',reviewed:'已评价',cancelled:'已取消'}
const filters=[['all','全部'],['pending','待接单'],['confirmed','待执行'],['in_progress','执行中'],['revision','待补充'],['receipt','待信众确认'],['archive','回执档案']]
let generation=0
async function load(){const run=++generation;loading.value=true;try{const result=await client.get<Index>('/bookings/journeys',{params:{filter:String(route.query.filter||'all'),page:Number(route.query.page||1),q:String(route.query.q||'')}});if(run!==generation)return;data.value=result;error.value=''}catch(e){if(run===generation)error.value=(e as Error).message}finally{if(run===generation)loading.value=false}}
function filter(value:string){router.replace({query:{...route.query,filter:value,page:'1'}})}
watch(()=>route.fullPath,()=>{search.value=String(route.query.q||'');void load()},{immediate:true})
const timer=setInterval(()=>{if(document.visibilityState==='visible')void load()},30000)
onUnmounted(()=>{generation++;clearInterval(timer)})
</script>
<template>
 <div class="df-page journey-work">
  <PageHeader title="履约工作台" subtitle="把每一次托付，落实为可查看的服务记录。"><router-link to="/bookings">预约订单 ↗</router-link></PageHeader>
  <div v-if="data" class="journey-stats">
   <button @click="filter('pending')"><strong>{{data.counts.pending}}</strong>待接单</button>
   <button @click="filter('confirmed')"><strong>{{data.counts.confirmed}}</strong>待执行</button>
   <button @click="filter('in_progress')"><strong>{{data.counts.executing}}</strong>执行中</button>
   <button @click="filter('revision')"><strong>{{data.counts.revision}}</strong>待补充回执</button>
  </div>
  <div class="df-card journey-panel">
   <nav class="journey-filters" aria-label="履约筛选"><button v-for="f in filters" :key="f[0]" :aria-pressed="String(route.query.filter||'all')===f[0]" @click="filter(f[0])">{{f[1]}}</button></nav>
   <form class="journey-search" @submit.prevent="router.replace({query:{...route.query,q:search,page:'1'}})"><el-input v-model="search" maxlength="60" aria-label="搜索服务或大师" placeholder="搜索服务或大师" clearable/><el-button native-type="submit">搜索</el-button></form>
   <el-alert v-if="error" :title="error" type="error" :closable="false"/><el-button v-if="error" @click="load">重新加载</el-button>
   <p v-if="loading&&!data" role="status">正在读取服务记录…</p>
   <div v-if="data&&!error" :aria-busy="loading">
    <p v-if="!data.list.length" class="journey-empty">当前没有符合条件的服务。新的已付款预约会出现在这里。</p>
    <article v-for="row in data.list" :key="row.id" class="journey-row">
     <div class="journey-row-title"><h3>{{row.serviceName}}</h3><el-tag :type="row.needsRevision?'warning':'info'">{{row.needsRevision?'需补充回执':labels[row.status]||row.status}}</el-tag></div>
     <p>{{row.bookingDate}} · {{row.timeSlot}} · {{row.masterName||'寺院全院执行'}}</p>
     <p v-if="row.latest" class="journey-latest">{{row.latest}}</p>
     <div class="journey-row-foot"><small>{{row.receiptCount?`${row.receiptCount} 份回执已留存`:'尚未提交最终回执'}}</small><router-link :to="`/bookings/${row.id}`">{{row.needsRevision?'补充回执':row.status==='in_progress'?'记录执行进展':'查看服务记录'}} ↗</router-link></div>
    </article>
    <el-pagination v-if="data.total>20" :current-page="Number(route.query.page||1)" :page-size="20" :total="data.total" layout="prev, pager, next" @current-change="page=>router.replace({query:{...route.query,page:String(page)}})"/>
   </div>
  </div>
 </div>
</template>
<style scoped>
.journey-stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:20px}.journey-stats button{padding:18px;text-align:left;border:1px solid var(--admin-border-strong);border-radius:12px;background:var(--el-bg-color);color:var(--el-text-color-regular);cursor:pointer}.journey-stats strong{display:block;font-size:28px;color:var(--el-text-color-primary);margin-bottom:5px;font-variant-numeric:tabular-nums}.journey-panel{padding:22px}.journey-filters{display:flex;gap:8px;flex-wrap:wrap}.journey-filters button{border:1px solid var(--admin-border-strong);border-radius:20px;padding:8px 14px;color:var(--el-text-color-regular);background:transparent;cursor:pointer}.journey-filters button[aria-pressed=true]{background:var(--el-color-primary);color:var(--el-color-white)}.journey-search{display:flex;gap:8px;max-width:440px;margin:18px 0}.journey-row{padding:20px 0;border-top:1px solid var(--admin-border-strong)}.journey-row-title,.journey-row-foot{display:flex;justify-content:space-between;align-items:center;gap:12px}.journey-row h3{margin:0}.journey-row p,.journey-row small{color:var(--el-text-color-secondary)}.journey-latest{white-space:pre-wrap;border-left:2px solid var(--el-color-primary);padding-left:12px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}.journey-empty{padding:30px;text-align:center;color:var(--el-text-color-secondary)}a{color:var(--el-color-primary);text-decoration:none}button:focus-visible,a:focus-visible{outline:2px solid var(--el-color-primary);outline-offset:3px}@media(max-width:600px){.journey-stats{grid-template-columns:repeat(2,1fr)}.journey-panel{padding:14px}.journey-row-foot{align-items:flex-start}}
</style>
