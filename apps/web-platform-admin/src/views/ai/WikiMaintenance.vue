<script setup lang="ts">
import { ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import {ref,watch} from 'vue'

import client from '@/api/client'
const props=defineProps<{baseId:string}>(),emit=defineEmits<{changed:[]}>()
interface Issue {id:string;slug:string;issue_type:string;status:string;description:string}
interface Lint {health_score:number;summary:string;issues:{type:string;severity:string;page_slug:string;description:string;auto_fixable:boolean}[]}
const lint=ref<Lint>(),issues=ref<Issue[]>([]),busy=ref(false),error=ref('');let generation=0
const root=()=>`/ai/admin/knowledge-bases/${props.baseId}/wiki`
async function load(){const n=++generation;busy.value=true;error.value='';try{const [a,b]=await Promise.all([client.get<Lint>(root()+'/lint'),client.get<Issue[]>(root()+'/issues')]);if(n!==generation)return;lint.value=a;issues.value=b||[]}catch(e){if(n===generation)error.value=e instanceof Error?e.message:'检查失败'}finally{if(n===generation)busy.value=false}}
async function action(kind:string,payload={}){try{await ElMessageBox.confirm((kind==='auto-fix' ? uiText('修复引擎可自动处理的失效链接等结构问题，正文观点仍需人工审校。') : uiText('保存此次 Wiki 维护操作？')),uiText('Wiki 维护'),{cancelButtonText:uiText('取消')})}catch{return}busy.value=true;try{await client.post(root()+'/'+kind,payload,{timeout:60000});await load();emit('changed')}catch(e){error.value=e instanceof Error?e.message:'维护失败'}finally{busy.value=false}}
watch(()=>props.baseId,()=>{lint.value=undefined;issues.value=[];void load()},{immediate:true})
</script>
<template><section v-loading="busy"><header><h3>{{ $t("Wiki 质量与关系维护") }}</h3><el-button @click="load">{{ $t("重新检查") }}</el-button><el-button @click="action('rebuild-links')">{{ $t("重建引用关系") }}</el-button><el-button @click="action('auto-fix')">{{ $t("修复结构问题") }}</el-button></header><el-alert v-if="error" :title="$t(error)" type="error" :closable="false"/><p>{{ $t("结构健康度 ") }}{{$t((lint?.health_score ?? '—'))}} / 100 · {{$t(lint?.summary)}}{{ $t("（不代表内容事实准确率）") }}</p><el-table :data="lint?.issues||[]" :empty-text='$t("没有发现结构问题")'><el-table-column prop="page_slug" :label='$t("条目")'/><el-table-column prop="type" :label='$t("类型")'/><el-table-column prop="description" :label='$t("问题")' min-width="220"/><el-table-column :label='$t("可自动修复")' width="110"><template #default="{row}">{{$t((row.auto_fixable ? $t('是') : $t('需人工处理')))}}</template></el-table-column></el-table><h4>{{ $t("待处理内容问题") }}</h4><el-table :data="issues" :empty-text='$t("没有待处理内容问题")'><el-table-column prop="slug" :label='$t("条目")'/><el-table-column prop="description" :label='$t("说明")' min-width="220"/><el-table-column :label='$t("处理")'><template #default="{row}"><el-button link @click="action('issue',{issue:row.id,status:'resolved'})">{{ $t("已解决") }}</el-button><el-button link @click="action('issue',{issue:row.id,status:'ignored'})">{{ $t("忽略") }}</el-button></template></el-table-column></el-table></section></template>
<style scoped>section{margin-top:20px}header{display:flex;gap:10px;align-items:center;flex-wrap:wrap}header h3{flex:1}p{font-size:13px;color:var(--el-text-color-secondary)}</style>
