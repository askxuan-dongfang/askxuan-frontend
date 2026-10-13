<template>
 <el-button link type="primary" @click="open">设置地区</el-button>
 <el-dialog v-model="visible" title="设置地区" width="420px" append-to-body>
  <p>{{ name }}{{ inherited ? ' · 当前跟随所属寺院' : '' }}</p>
  <el-select v-model="selected" aria-label="地区标签" style="width:100%" :loading="loading">
   <el-option value="" :label="kind==='master' && templeBound ? '跟随所属寺院' : '未设置'" />
   <el-option v-for="r in regions" :key="r.code" :value="r.code" :label="r.name+(r.status==='disabled'?'（已停用）':'')" :disabled="r.status==='disabled'" />
  </el-select>
  <p v-if="error" role="alert">{{ error }} <el-button link @click="open">重试</el-button></p>
  <template #footer><el-button @click="visible=false">取消</el-button><el-button type="primary" :loading="saving" :disabled="loading||!!error" @click="save">保存</el-button></template>
 </el-dialog>
</template>
<script setup lang="ts">
import {ref} from 'vue'
import {ElMessage} from 'element-plus'
import {getRegions,assignRegion,type RegionTag} from '@/api/regions'
const props=defineProps<{kind:'temple'|'master';id:string;name:string;code?:string;inherited?:boolean;templeBound?:boolean}>()
const emit=defineEmits<{updated:[]}>()
const visible=ref(false),loading=ref(false),saving=ref(false),error=ref(''),selected=ref(''),regions=ref<RegionTag[]>([])
async function open(){visible.value=true;selected.value=props.inherited?'':props.code||'';loading.value=true;error.value='';try{regions.value=(await getRegions()).list||[]}catch(e){error.value=e instanceof Error?e.message:'地区加载失败'}finally{loading.value=false}}
async function save(){saving.value=true;try{await assignRegion(props.kind,props.id,selected.value);visible.value=false;ElMessage.success('地区已更新');emit('updated')}catch(e){error.value=e instanceof Error?e.message:'保存失败'}finally{saving.value=false}}
</script>
