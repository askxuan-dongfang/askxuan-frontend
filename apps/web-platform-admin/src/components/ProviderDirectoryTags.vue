<template>
 <el-button v-if="auth.roles.includes('platform_super')" link type="primary" @click="open">{{ $t("宗派 / 信俗标签") }}</el-button>
 <el-dialog v-model="visible" :title='$t("设置宗派 / 信俗标签")' width="520px" append-to-body>
  <p>{{$t(name)}}</p><p>{{ $t("可关联多个标签，最多 12 项。标签来自“筛选标签”统一字典，地区切换不会改变目录。") }}</p>
  <el-select v-model="selected" multiple filterable :multiple-limit="12" :aria-label='$t("宗派或信俗标签")' style="width:100%" :loading="loading">
   <el-option v-for="tag in tags" :key="tag.code" :value="tag.code" :label="$t((tag.name + ((tag.status==='disabled' ? $t('（已停用，请移除）') : ''))))" :disabled="tag.status==='disabled'" />
  </el-select>
  <p v-if="error" role="alert">{{$t(error)}}</p><el-button v-if="!ready&&!loading" link @click="open">{{ $t("重新加载") }}</el-button>
  <template #footer><el-button @click="visible=false">{{ $t("取消") }}</el-button><el-button type="primary" :loading="saving" :disabled="!ready||loading" @click="save">{{ $t("保存") }}</el-button></template>
 </el-dialog>
</template>
<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import {ref} from 'vue'
import {useAuthStore} from '@/stores/auth'
const auth=useAuthStore()

import {getDirectoryTags,getProviderTags,assignProviderTags,type DirectoryTag} from '@/api/directoryTags'
const props=defineProps<{kind:'temple'|'master';id:string;name:string}>()
const emit=defineEmits<{updated:[]}>()
const visible=ref(false),loading=ref(false),saving=ref(false),ready=ref(false),error=ref(''),selected=ref<string[]>([]),tags=ref<DirectoryTag[]>([])
async function open(){visible.value=true;loading.value=true;ready.value=false;error.value='';try{const [list,assignment]=await Promise.all([getDirectoryTags(),getProviderTags(props.kind,props.id)]);tags.value=list.list.filter(t=>t.group==='tradition');selected.value=assignment.codes;ready.value=true}catch(e){error.value=e instanceof Error?e.message:'加载失败'}finally{loading.value=false}}
async function save(){if(!ready.value||saving.value)return;saving.value=true;error.value='';try{await assignProviderTags(props.kind,props.id,selected.value);visible.value=false;ElMessage.success(uiText('标签已更新'));emit('updated')}catch(e){error.value=e instanceof Error?e.message:'保存失败'}finally{saving.value=false}}
</script>
