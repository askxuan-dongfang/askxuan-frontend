<script setup lang="ts">
import {ref,watch,onMounted} from 'vue'
import dayjs from 'dayjs'
import client from '@/api/client'
import {listMasters} from '@/api/master'
import {useAuthStore} from '@/stores/auth'
import PageHeader from '@/components/PageHeader.vue'
import {ElMessage} from '@/i18n'
import type {Master} from '@/types'
type Schedule={id:number;revision:number;date:string;status:string;timeSlots:string[]}
const auth=useAuthStore(),masters=ref<Master[]>([]),mastersLoading=ref(true),masterCode=ref(''),date=ref(dayjs().format('YYYY-MM-DD'))
const status=ref('available'),slots=ref<string[]>([]),revision=ref(0),hasSchedule=ref(false),loading=ref(false),saving=ref(false),error=ref(''),ready=ref(false)
const start=ref('09:00'),end=ref('12:00');let generation=0
async function load(){const seq=++generation;ready.value=false;error.value='';slots.value=[];if(!masterCode.value||!date.value)return;loading.value=true;try{const r=await client.get<{list:Schedule[]}>('/admin/temples/schedules',{params:{masterCode:masterCode.value,date:date.value}});if(seq!==generation)return;const row=r.list[0];hasSchedule.value=!!row;revision.value=row?.revision??0;status.value=row?.status||'available';slots.value=row?.timeSlots||[];ready.value=true}catch(e){if(seq===generation)error.value=e instanceof Error?e.message:'排班加载失败'}finally{if(seq===generation)loading.value=false}}
function addSlot(){if(start.value>=end.value){ElMessage.warning('结束时间需晚于开始时间');return}const slot=start.value+'-'+end.value;if(!slots.value.includes(slot))slots.value=[...slots.value,slot].sort()}
async function save(){if(!ready.value||saving.value)return;saving.value=true;try{await client.put('/admin/temples/schedules',{masterCode:masterCode.value,date:date.value,status:status.value,revision:revision.value,timeSlots:status.value==='off'?[]:slots.value});ElMessage.success('排班已更新，法师端与信众可预约时段同步生效');await load()}catch(e){error.value=e instanceof Error?e.message:'保存失败';ready.value=false}finally{saving.value=false}}
watch([masterCode,date],load)
onMounted(async()=>{try{let page=1;const all:Master[]=[];while(true){const r=await listMasters({templeId:auth.templeId,page,size:100});all.push(...r.list);if(!r.list.length||all.length>=r.total)break;page++}masters.value=all;masterCode.value=all[0]?.id||''}catch(e){error.value=e instanceof Error?e.message:'法师列表加载失败'}finally{mastersLoading.value=false}})
</script>
<template><div class="df-page"><PageHeader :title="$t('排班日历')" :subtitle="$t('与法师端共用日程，按日安排可预约时段')"/>
<el-alert :closable="false" type="info" :title="$t('排班调整仅影响新预约，已有订单仍需履约。休息日及不在排班内的时段不可新约，已有冲突请从异常跟进处理。')"/>
<div class="filters"><el-select v-model="masterCode" filterable :loading="mastersLoading" :disabled="saving||mastersLoading" :placeholder="$t('选择本寺院法师')"><el-option v-for="m in masters" :key="m.id" :value="m.id" :label="m.dharmaName"/></el-select><el-date-picker v-model="date" :disabled="saving" type="date" value-format="YYYY-MM-DD" :clearable="false"/><el-button :disabled="saving" @click="load">{{$t('刷新')}}</el-button></div>
<div v-if="error" role="alert"><p>{{$t(error)}}</p><el-button @click="load">{{$t('重新加载')}}</el-button></div>
<p v-if="mastersLoading" role="status">{{$t('正在加载法师列表')}}</p>
<el-empty v-else-if="!masters.length&&!error" :description="$t('暂无可排班法师')"/>
<section v-else-if="ready" class="df-card schedule" v-loading="loading"><p>{{date}} · {{$t(!hasSchedule?'尚未设置日期排班，当前沿用服务时段':'已与法师端同步')}}</p><el-form :disabled="!auth.can('temple.schedules.write')||saving" label-position="top"><el-form-item :label="$t('当日安排')"><el-radio-group v-model="status"><el-radio value="available">{{$t('可预约')}}</el-radio><el-radio value="off">{{$t('休息日')}}</el-radio></el-radio-group></el-form-item>
<template v-if="status==='available'"><div class="slots"><el-tag v-for="slot in slots" :key="slot" :closable="auth.can('temple.schedules.write')&&!saving" @close="slots=slots.filter(s=>s!==slot)">{{slot}}</el-tag></div><el-form-item :label="$t('增加时段')"><div class="filters"><el-time-select v-model="start" start="00:00" end="23:30" step="00:30"/><el-time-select v-model="end" start="00:30" end="23:30" step="00:30"/><el-button @click="addSlot">{{$t('添加')}}</el-button></div></el-form-item></template>
<el-button v-if="auth.can('temple.schedules.write')" type="primary" :loading="saving" @click="save">{{$t('保存排班')}}</el-button><p v-else>{{$t('当前岗位可查看排班，由运营或寺院管理员修改。')}}</p></el-form></section></div></template>
<style scoped>.filters{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin:20px 0}.filters>.el-select{width:230px}.schedule{padding:24px;max-width:850px}.slots{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0 24px}.schedule p{color:var(--admin-text-secondary)}@media(max-width:767px){.filters>*{width:100%!important}.schedule{padding:16px}}</style>
