<template>
 <el-button v-if="auth.roles.includes('platform_super')" link type="primary" @click="open">{{ $t("宗派 / 信俗标签") }}</el-button>
 <el-dialog v-model="visible" :title='$t("设置宗派 / 信俗标签")' width="520px" append-to-body>
  <p>{{$t(name)}}</p><p>{{ $t("标准关联独立保存，最多 12 项；历史跨类或停用关联仍显示，需明确核对后调整。") }}</p>
  <el-select v-model="selected" multiple filterable :multiple-limit="12" :aria-label='$t("宗派或信俗标签")' style="width:100%" :loading="loading">
   <el-option v-for="tag in options" :key="tag.code" :value="tag.code" :label="$t(tag.name) + (isHistorical(tag) ? $t('（历史关联，需核对）') : '')" />
  </el-select>
  <p v-if="options.some(tag=>selected.includes(tag.code)&&isHistorical(tag))" role="status">{{ $t('已有历史关联原样保留，不因资料编辑自动更改。') }}</p>
  <p v-if="error" role="alert">{{$t(error)}}</p><el-button v-if="!ready&&!loading" link @click="open">{{ $t("重新加载") }}</el-button>
  <template #footer><el-button @click="visible=false" data-quiet-action="cancel">{{ $t("取消") }}</el-button><el-button type="primary" :loading="saving" :disabled="!ready||loading" @click="save">{{ $t("保存") }}</el-button></template>
 </el-dialog>
</template>
<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import {ref,computed} from 'vue'
import {normalizeBelief} from '../../../../packages/admin-ui/affiliation'
import {useAuthStore} from '@/stores/auth'
const auth=useAuthStore()

import {getDirectoryTags,getProviderTags,assignProviderTags,type DirectoryTag} from '@/api/directoryTags'
const props=defineProps<{kind:'temple'|'master';id:string;name:string;belief?:string}>()
const emit=defineEmits<{updated:[]}>()
const visible=ref(false),loading=ref(false),saving=ref(false),ready=ref(false),error=ref(''),selected=ref<string[]>([]),tags=ref<DirectoryTag[]>([])
function isHistorical(tag:DirectoryTag){return tag.status!=='enabled'||(!!props.belief&&normalizeBelief(tag.beliefCode||'')!==normalizeBelief(props.belief))}
const options=computed(()=>{
 const result=tags.value.filter(tag=>selected.value.includes(tag.code)||!isHistorical(tag))
 for(const code of selected.value)if(!result.some(tag=>tag.code===code))result.push({code,name:code,group:'tradition',value:code,sort:0,status:'disabled'})
 return result
})
async function open(){visible.value=true;loading.value=true;ready.value=false;error.value='';try{const [list,assignment]=await Promise.all([getDirectoryTags(),getProviderTags(props.kind,props.id)]);tags.value=list.list.filter(t=>t.group==='tradition');selected.value=assignment.codes;ready.value=true}catch(e){error.value=e instanceof Error?e.message:'加载失败'}finally{loading.value=false}}
async function save(){if(!ready.value||saving.value)return;saving.value=true;error.value='';try{await assignProviderTags(props.kind,props.id,selected.value);visible.value=false;ElMessage.success(uiText('标签已更新'));emit('updated')}catch(e){error.value=e instanceof Error?e.message:'保存失败'}finally{saving.value=false}}
</script>
