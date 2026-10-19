<template>
 <el-button link type="primary" @click="open">{{ $t("设置地区") }}</el-button>
 <el-dialog v-model="visible" :title='$t("设置地区")' width="420px" append-to-body>
  <p>{{ $t(name) }}{{ $t((inherited ? $t(' · 当前跟随所属寺院') : '')) }}</p>
  <el-select v-model="selected" :aria-label='$t("地区标签")' style="width:100%" :loading="loading">
   <el-option value="" :label="$t((kind==='master' && templeBound ? $t('跟随所属寺院') : $t('未设置')))" />
   <el-option v-for="r in regions" :key="r.code" :value="r.code" :label="$t((r.name + ((r.status==='disabled' ? $t('（已停用）') : ''))))" :disabled="r.status==='disabled'" />
  </el-select>
  <p v-if="error" role="alert">{{ $t(error) }} <el-button link @click="open">{{ $t("重试") }}</el-button></p>
  <template #footer><el-button @click="visible=false">{{ $t("取消") }}</el-button><el-button type="primary" :loading="saving" :disabled="loading||!!error" @click="save">{{ $t("保存") }}</el-button></template>
 </el-dialog>
</template>
<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import {ref} from 'vue'

import {getRegions,assignRegion,type RegionTag} from '@/api/regions'
const props=defineProps<{kind:'temple'|'master';id:string;name:string;code?:string;inherited?:boolean;templeBound?:boolean}>()
const emit=defineEmits<{updated:[]}>()
const visible=ref(false),loading=ref(false),saving=ref(false),error=ref(''),selected=ref(''),regions=ref<RegionTag[]>([])
async function open(){visible.value=true;selected.value=props.inherited?'':props.code||'';loading.value=true;error.value='';try{regions.value=(await getRegions()).list||[]}catch(e){error.value=e instanceof Error?e.message:'地区加载失败'}finally{loading.value=false}}
async function save(){saving.value=true;try{await assignRegion(props.kind,props.id,selected.value);visible.value=false;ElMessage.success(uiText('地区已更新'));emit('updated')}catch(e){error.value=e instanceof Error?e.message:'保存失败'}finally{saving.value=false}}
</script>
