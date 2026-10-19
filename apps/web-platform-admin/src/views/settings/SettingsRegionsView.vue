<template>
 <div class="dfx-page">
  <PageHeader :title='$t("地区标签")' :subtitle='$t("用于寺院和师傅的地区展示与筛选。可在寺院列表、法师列表中设置归属。")'><template #actions><el-button type="primary" @click="open()">{{ $t("新增地区") }}</el-button><el-button @click="load">{{ $t("刷新") }}</el-button></template></PageHeader>
  <div class="dfx-card" style="padding:20px">
   <p>{{ $t("停用后不再作为新的筛选和分配选项，已有归属保留。寺院绑定师傅默认跟随寺院，可单独设置。") }}</p>
   <p v-if="error" role="alert">{{$t(error)}} <el-button link @click="load">{{ $t("重试") }}</el-button></p>
   <el-table :data="list" v-loading="loading" :empty-text='$t("暂无地区标签")'>
    <el-table-column prop="name" :label='$t("地区名称")'/><el-table-column prop="code" :label='$t("编码")'/>
    <el-table-column prop="sort" :label='$t("排序")' width="100"/>
    <el-table-column :label='$t("状态")' width="100"><template #default="{row}">{{$t((row.status==='enabled' ? $t('启用') : $t('停用')))}}</template></el-table-column>
    <el-table-column :label='$t("操作")' width="100"><template #default="{row}"><el-button link type="primary" @click="open(row)">{{ $t("编辑") }}</el-button></template></el-table-column>
   </el-table>
  </div>
  <el-dialog v-model="visible" :title="$t((creating ? $t('新增地区') : $t('编辑地区')))" width="440px">
   <el-form label-position="top" @submit.prevent="save">
    <el-form-item :label='$t("地区名称")'><el-input v-model="form.name" maxlength="32"/></el-form-item>
    <el-form-item :label='$t("编码（小写字母、数字、下划线，创建后不可更改）")'><el-input v-model="form.code" :disabled="!creating" maxlength="32"/></el-form-item>
    <el-form-item :label='$t("排序（小值在前）")'><el-input-number v-model="form.sort" :min="0" :max="9999"/></el-form-item>
    <el-form-item :label='$t("状态")'><el-radio-group v-model="form.status"><el-radio value="enabled">{{ $t("启用") }}</el-radio><el-radio value="disabled">{{ $t("停用") }}</el-radio></el-radio-group></el-form-item>
    <p v-if="saveError" role="alert">{{$t(saveError)}}</p>
   </el-form>
   <template #footer><el-button @click="visible=false">{{ $t("取消") }}</el-button><el-button type="primary" :loading="saving" @click="save">{{ $t("保存") }}</el-button></template>
  </el-dialog>
 </div>
</template>
<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import {ref,reactive,onMounted} from 'vue'

import PageHeader from '@/components/PageHeader.vue'
import {getRegions,saveRegion,type RegionTag} from '@/api/regions'
const list=ref<RegionTag[]>([]),loading=ref(false),error=ref(''),saveError=ref(''),visible=ref(false),creating=ref(true),saving=ref(false)
const form=reactive<RegionTag>({code:'',name:'',sort:60,status:'enabled'})
async function load(){loading.value=true;error.value='';try{list.value=(await getRegions()).list||[]}catch(e){error.value=e instanceof Error?e.message:'加载失败'}finally{loading.value=false}}
function open(row?:RegionTag){creating.value=!row;Object.assign(form,row||{code:'',name:'',sort:60,status:'enabled'});saveError.value='';visible.value=true}
async function save(){if(!form.name.trim()||!/^[a-z][a-z0-9_]{2,31}$/.test(form.code)){saveError.value='请填写地区名称及 3—32 位有效编码';return} saving.value=true;saveError.value='';try{await saveRegion({...form,name:form.name.trim()},creating.value);visible.value=false;ElMessage.success(uiText('地区标签已保存'));await load()}catch(e){saveError.value=e instanceof Error?e.message:'保存失败'}finally{saving.value=false}}
onMounted(load)
</script>
