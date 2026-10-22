<script setup lang="ts">
import { ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import PageHeader from '@/components/PageHeader.vue'
import {ref,onMounted} from 'vue'

import client from '@/api/client'
interface ManagedAccount { id:number; accountId:number; masterCode:string; username:string; email:string; status:string; activationStatus:string; accountStatus:'enabled'|'disabled' }
const list=ref<ManagedAccount[]>([]),masters=ref<any[]>([]),master=ref(''),email=ref(''),username=ref(''),busy=ref(false),error=ref(''),notice=ref('')
async function load(){error.value='';try{const [accounts,candidates]=await Promise.all([client.get<{list:ManagedAccount[]}>('/auth/onboarding/managed'),client.get<{list:any[]}>('/auth/onboarding/managed/candidates')]);list.value=accounts.list;masters.value=candidates.list}catch(e){list.value=[];masters.value=[];error.value=(e as Error).message}}
async function create(){busy.value=true;error.value='';notice.value='';try{await client.post('/auth/onboarding/managed',{masterCode:master.value,email:email.value,username:username.value});notice.value='已分配账号。请通知本人前往大师端，选择“寺院分配账号激活”，通过此邮箱验证并设置密码。';email.value='';username.value='';master.value='';await load()}catch(e){error.value=(e as Error).message}finally{busy.value=false}}
async function revoke(id:number){try{await ElMessageBox.confirm(uiText('停用后该账号不能登录，已有登录会话也将失效。大师档案和订单会保留。'),uiText('停用账号'));busy.value=true;await client.post('/auth/onboarding/managed/revoke',{id});await load()}catch(e){if(e!=='cancel'&&e!=='close')error.value=e instanceof Error?e.message:'操作失败'}finally{busy.value=false}}
async function restore(id:number){try{await ElMessageBox.confirm(uiText('恢复后，已激活账号可重新登录；未激活账号仍须本人验证邮箱并设置密码。'),uiText('恢复账号'));busy.value=true;await client.post('/auth/onboarding/managed/restore',{id});await load()}catch(e){if(e!=='cancel'&&e!=='close')error.value=e instanceof Error?e.message:'操作失败'}finally{busy.value=false}}
onMounted(load)
</script>
<template><div class="df-page"><PageHeader :title='$t("大师账号分配")' :subtitle='$t("为本寺已认证的纳管大师分配账号，由本人在大师端验证邮箱并设置密码。")' /><p v-if="error" role="alert">{{$t(error)}} <el-button link @click="load">{{$t("重新加载")}}</el-button></p><p v-if="notice" role="status">{{$t(notice)}}</p><div class="aui-panel-stack"><div class="df-card"><form class="managed-account-form" @submit.prevent="create"><label>{{ $t("选择本寺大师") }}<el-select v-model="master" :placeholder='$t("选择已完成认证的大师")' filterable><el-option v-for="m in masters" :key="m.code" :value="m.code" :label="$t(m.name)"/></el-select></label><label>{{ $t("本人邮箱") }}<el-input v-model="email" type="email" required maxlength="254"/></label><label>{{ $t("登录用户名") }}<el-input v-model="username" required pattern="[a-z][a-z0-9_]{3,31}" maxlength="32" :placeholder='$t("4–32 位小写字母、数字或下划线")'/></label><el-button native-type="submit" type="primary" :disabled="busy||!master">{{ $t("分配账号") }}</el-button></form></div><div class="df-card"><h2 class="aui-section-title">{{ $t("已分配账号") }}</h2><el-table :data="list"><el-table-column prop="masterCode" :label='$t("大师编号")'/><el-table-column prop="username" :label='$t("用户名")'/><el-table-column prop="email" :label='$t("激活邮箱")'/><el-table-column :label='$t("激活状态")'><template #default="{row}">{{$t((row.status==='pending' ? $t('待本人激活') : (row.status==='activated' ? $t('已激活') : $t('已停用'))))}}</template></el-table-column><el-table-column :label='$t("账号状态")'><template #default="{row}"><span>{{ $t(row.accountStatus==='enabled'?'已启用':'已停用') }}</span><p v-if="row.status==='activated'&&row.accountStatus==='disabled'">{{ $t('平台已停用，请联系平台核对。') }}</p></template></el-table-column><el-table-column :label='$t("操作")'><template #default="{row}"><el-button v-if="row.status==='revoked'" :disabled="busy" @click="restore(row.id)">{{ $t("恢复账号") }}</el-button><el-button v-else :disabled="busy" @click="revoke(row.id)">{{ $t("停用账号") }}</el-button></template></el-table-column></el-table></div></div></div></template>
<style scoped>
.managed-account-form { display: grid; gap: 20px; max-width: 640px; }
.managed-account-form > label { display: grid; gap: 8px; color: var(--admin-text-secondary); font-size: var(--type-size-body); }
.managed-account-form > .el-button { justify-self: start; }
@media(max-width:767px) { .managed-account-form > .el-button { width: 100%; } }
</style>
