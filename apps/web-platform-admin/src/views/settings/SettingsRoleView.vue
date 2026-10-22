<template>
 <div class="dfx-page">
  <PageHeader :title='$t("角色权限")' :subtitle='$t("自定义角色默认无权限；授权变更后原会话立即失效")'><template #actions><el-button type="primary" :icon="Plus" @click="openCreate">{{ $t('新建角色') }}</el-button><el-button :icon="Refresh" @click="loadData">{{ $t('刷新') }}</el-button></template></PageHeader>
  <el-alert v-if="loadError" type="error" :closable="false" :title='$t("角色或权限目录加载失败，请刷新后再操作")' />
  <div class="dfx-card section"><el-table :data="roles" v-loading="loading">
   <el-table-column :label='$t("角色名称")' prop="name" min-width="130" /><el-table-column :label='$t("编码")' prop="code" min-width="160" />
   <el-table-column :label='$t("权限范围")' min-width="150"><template #default="{row}">{{ $t(row.editable ? '自定义平台权限' : '内置固定权限') }}</template></el-table-column>
   <el-table-column :label='$t("描述")' prop="description" min-width="160" /><el-table-column :label='$t("操作")' width="190"><template #default="{row}"><el-button link @click="openEdit(row)">{{ $t('编辑说明') }}</el-button><el-button link type="primary" @click="openPermissions(row)">{{ $t(row.editable ? '分配权限' : '查看范围') }}</el-button></template></el-table-column>
  </el-table></div>
  <el-dialog v-model="dialog.visible" :title="$t(dialog.isEdit ? '编辑角色' : '新建角色')" width="460px" append-to-body><el-form :model="dialog.form" label-width="80px">
   <el-form-item :label='$t("角色名称")'><el-input v-model="dialog.form.name" maxlength="64" /></el-form-item><el-form-item :label='$t("角色编码")'><el-input v-model="dialog.form.code" :disabled="dialog.isEdit" :placeholder='$t("如 content_editor")' maxlength="50" /></el-form-item><el-form-item :label='$t("描述")'><el-input v-model="dialog.form.description" type="textarea" maxlength="255" /></el-form-item>
  </el-form><template #footer><el-button @click="dialog.visible=false" data-quiet-action="cancel">{{ $t('取消') }}</el-button><el-button type="primary" :loading="dialog.loading" @click="submit">{{ $t('保存') }}</el-button></template></el-dialog>
  <el-dialog v-model="grant.visible" :title="$t('角色权限') + ' · ' + grant.name" width="min(820px, 94vw)" append-to-body>
   <el-alert v-if="!grant.editable" type="info" :closable="false" :title='$t("内置角色保留原有业务范围，不通过平台权限矩阵修改；敏感模块仅超级管理员可用。")' />
   <el-alert v-else type="info" :closable="false" :title='$t("管理权限须同时具有对应查看权限。保存后该角色的账号需要重新登录。")' />
   <el-alert v-if="grant.error" type="error" :closable="false" :title='$t("权限加载或保存失败；若版本冲突，请重新加载后检查并提交")' />
   <el-button :loading="grant.loading" @click="reloadGrant">{{ $t('重新加载') }}</el-button>
   <el-checkbox-group v-model="grant.codes" :disabled="!grant.editable || grant.loading || grant.error" class="permission-grid"><el-checkbox v-for="p in permissions" :key="p.code" :value="p.code" :disabled="!p.assignable"><span>{{ $t(p.name) }}</span><code>{{ p.code }}</code></el-checkbox></el-checkbox-group>
   <template #footer><el-button @click="grant.visible=false" data-quiet-action="cancel">{{ $t('取消') }}</el-button><el-button v-if="grant.editable" type="primary" :disabled="grant.error" :loading="grant.loading" @click="saveGrant">{{ $t('保存权限') }}</el-button></template>
  </el-dialog>
 </div>
</template>
<script setup lang="ts">
import {ref,reactive,onMounted} from 'vue'
import {Plus,Refresh} from '@element-plus/icons-vue'
import {ElMessage} from '@/i18n'
import {t as uiText} from '../../../../../packages/localization/language'
import PageHeader from '@/components/PageHeader.vue'
import {getRoles,createRole,updateRole,getPermissions,getRolePermissions,setRolePermissions} from '@/api/auth'
import type {Role,Permission} from '@/types'
const roles=ref<Role[]>([]),permissions=ref<Permission[]>([]),loading=ref(false),loadError=ref(false)
const dialog=reactive({visible:false,loading:false,isEdit:false,id:0,form:{name:'',code:'',description:''}})
const grant=reactive({visible:false,loading:false,error:false,id:0,name:'',revision:0,codes:[] as string[],editable:false})
let grantRead=0
async function loadData(){loading.value=true;loadError.value=false;try{const[r,p]=await Promise.all([getRoles(),getPermissions()]);roles.value=r;permissions.value=p}catch{loadError.value=true}finally{loading.value=false}}
function openCreate(){dialog.isEdit=false;dialog.id=0;dialog.form={name:'',code:'',description:''};dialog.visible=true}
function openEdit(row:Role){dialog.isEdit=true;dialog.id=row.id;dialog.form={name:row.name,code:row.code,description:row.description};dialog.visible=true}
async function submit(){if(!dialog.form.name.trim()||(!dialog.isEdit&&!/^[a-z][a-z0-9_]{2,49}$/.test(dialog.form.code))){ElMessage.warning(uiText('请填写名称及有效的英文小写角色编码'));return}dialog.loading=true;try{if(dialog.isEdit)await updateRole(dialog.id,{name:dialog.form.name,description:dialog.form.description});else await createRole(dialog.form);dialog.visible=false;await loadData()}finally{dialog.loading=false}}
async function openPermissions(row:Role){grant.id=row.id;grant.name=row.name;grant.codes=[];grant.editable=false;grant.visible=true;await reloadGrant()}
async function reloadGrant(){
 const request=++grantRead,id=grant.id;grant.loading=true;grant.error=false
 try{const r=await getRolePermissions(id);if(request!==grantRead||grant.id!==id)return;grant.revision=r.revision;grant.codes=r.permissionCodes;grant.editable=r.editable}
 catch{if(request===grantRead)grant.error=true}
 finally{if(request===grantRead)grant.loading=false}
}
async function saveGrant(){
 const chosen=new Set(grant.codes)
 for(const code of chosen){if(code.endsWith('.write')&&!chosen.has(code.replace(/\.write$/,'.read'))){ElMessage.warning(uiText('管理权限须同时选择对应的查看权限'));return}}
 const id=grant.id,revision=grant.revision,view=grantRead,codes=[...grant.codes]
 grant.loading=true
 try{
  const r=await setRolePermissions(id,revision,codes)
  if(view!==grantRead||id!==grant.id)return
  grant.revision=r.revision;grant.codes=r.permissionCodes
  ElMessage.success(uiText('权限已保存，该角色原会话已失效'));grant.visible=false;await loadData()
 }catch{if(view===grantRead&&id===grant.id)grant.error=true}
 finally{if(view===grantRead&&id===grant.id)grant.loading=false}
}

onMounted(loadData)
</script>
<style scoped>
.section{padding:18px 20px;}
.permission-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin-top:16px;}
.permission-grid :deep(.el-checkbox){height:auto;margin:0;align-items:flex-start;white-space:normal;}
.permission-grid code{display:block;color:var(--color-text-secondary);font-size:var(--type-size-caption);}
@media(max-width:767px){.permission-grid{grid-template-columns:minmax(0,1fr);}}
</style>
