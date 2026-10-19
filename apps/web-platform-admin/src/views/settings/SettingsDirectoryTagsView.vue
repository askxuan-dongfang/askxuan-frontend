<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import {ref,reactive,onMounted,computed} from 'vue'

import PageHeader from '@/components/PageHeader.vue'
import {getDirectoryTags,saveDirectoryTag,type DirectoryTag} from '@/api/directoryTags'
const list=ref<DirectoryTag[]>([]),loading=ref(false),error=ref(''),saveError=ref(''),visible=ref(false),creating=ref(true),saving=ref(false)
const beliefs=[{code:'han_buddhism',name:'汉传佛教'},{code:'tibetan_buddhism',name:'藏传佛教'},{code:'theravada_buddhism',name:'南传佛教'},{code:'daoism',name:'道教'},{code:'folk',name:'民间信仰'}]
const groups={tradition:'宗派 / 信俗',position:'师傅身份',specialty:'擅长领域'}
const selected=ref<DirectoryTag['group']>('tradition')
const filtered=computed(()=>list.value.filter(t=>t.group===selected.value))
const form=reactive<DirectoryTag>({beliefCode:'',code:'',group:'tradition',name:'',value:'',sort:100,status:'enabled'})
async function load(){loading.value=true;error.value='';try{list.value=(await getDirectoryTags()).list}catch(e){error.value=e instanceof Error?e.message:'加载失败'}finally{loading.value=false}}
function open(row?:DirectoryTag){creating.value=!row;Object.assign(form,{beliefCode:''},row||{code:'',group:selected.value,name:'',value:'',sort:100,status:'enabled'});saveError.value='';visible.value=true}
async function save(){if(saving.value)return;if(!form.name.trim()||!form.value.trim()||!/^[a-z][a-z0-9_]{2,31}$/.test(form.code)){saveError.value='请填写名称、匹配值及 3—32 位有效编码';return}if(form.group==='tradition'&&!form.beliefCode){saveError.value='请选择所属信仰类型';return}saving.value=true;saveError.value='';try{await saveDirectoryTag({...form,beliefCode:form.group==='tradition'?form.beliefCode:''},creating.value);visible.value=false;ElMessage.success(uiText('筛选标签已保存'));await load()}catch(e){saveError.value=e instanceof Error?e.message:'保存失败'}finally{saving.value=false}}
onMounted(load)
</script>
<template>
 <div class="dfx-page">
  <PageHeader :title='$t("筛选标签")' :subtitle='$t("寺院与师傅目录的固定筛选选项。切换地区、搜索结果为空时仍保留标签。")'><template #actions><el-button type="primary" @click="open()">{{ $t("新增标签") }}</el-button><el-button @click="load">{{ $t("刷新") }}</el-button></template></PageHeader>
  <section class="dfx-card" style="padding:20px">
   <p>{{ $t("宗派 / 信俗可在寺院、师傅详情中多选关联。身份和擅长领域的匹配值对应师傅资料；修改展示名称不会改动匹配值。服务筛选继续使用统一服务目录。") }}</p>
   <el-radio-group v-model="selected" :aria-label='$t("标签分组")' style="margin-block:16px"><el-radio-button v-for="(name,key) in groups" :key="key" :value="key">{{$t(name)}}</el-radio-button></el-radio-group>
   <p v-if="error" role="alert">{{$t(error)}}</p>
   <el-table :data="filtered" v-loading="loading" :empty-text='$t("暂无标签")'>
    <el-table-column prop="name" :label='$t("展示名称")'/><el-table-column prop="code" :label='$t("编码")'/><el-table-column prop="value" :label='$t("匹配值")'/>
    <el-table-column v-if="selected==='tradition'" :label='$t("所属信仰类型")'><template #default="{row}">{{$t(beliefs.find(b=>b.code===row.beliefCode)?.name || '待设置')}}</template></el-table-column>
    <el-table-column prop="sort" :label='$t("排序")' width="90"/>
    <el-table-column :label='$t("状态")' width="90"><template #default="{row}">{{$t((row.status==='enabled' ? $t('启用') : $t('停用')))}}</template></el-table-column>
    <el-table-column :label='$t("操作")' width="100"><template #default="{row}"><el-button link type="primary" @click="open(row)">{{ $t("编辑") }}</el-button></template></el-table-column>
   </el-table>
  </section>
  <el-dialog v-model="visible" :title="$t((creating ? $t('新增筛选标签') : $t('编辑筛选标签')))" width="480px">
   <el-form label-position="top" @submit.prevent="save">
    <el-form-item :label='$t("分组")'><el-select v-model="form.group" :disabled="!creating"><el-option v-for="(name,key) in groups" :key="key" :value="key" :label="$t(name)"/></el-select></el-form-item>
    <el-form-item v-if="form.group==='tradition'" :label='$t("所属信仰类型")' required><el-select v-model="form.beliefCode" :placeholder='$t("请选择所属信仰类型")'><el-option v-for="belief in beliefs" :key="belief.code" :value="belief.code" :label="$t(belief.name)"/></el-select></el-form-item>
    <el-form-item :label='$t("展示名称")'><el-input v-model="form.name" maxlength="32"/></el-form-item>
    <el-form-item :label='$t("编码（小写字母、数字、下划线）")'><el-input v-model="form.code" :disabled="!creating" maxlength="32"/></el-form-item>
    <el-form-item :label='$t("匹配值（创建后固定；身份和领域填写资料中的原名称）")'><el-input v-model="form.value" :disabled="!creating" maxlength="64"/></el-form-item>
    <el-form-item :label='$t("排序")'><el-input-number v-model="form.sort" :min="0" :max="9999"/></el-form-item>
    <el-form-item :label='$t("状态")'><el-radio-group v-model="form.status"><el-radio value="enabled">{{ $t("启用") }}</el-radio><el-radio value="disabled">{{ $t("停用") }}</el-radio></el-radio-group></el-form-item>
    <p v-if="saveError" role="alert">{{$t(saveError)}}</p>
   </el-form>
   <template #footer><el-button @click="visible=false">{{ $t("取消") }}</el-button><el-button type="primary" :loading="saving" @click="save">{{ $t("保存") }}</el-button></template>
  </el-dialog>
 </div>
</template>
