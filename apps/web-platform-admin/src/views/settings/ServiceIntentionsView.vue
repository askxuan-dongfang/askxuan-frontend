<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import PageHeader from '@/components/PageHeader.vue'
import {computed,onMounted,ref,watch} from 'vue'
import client from '@/api/client'

const tags=[['peace','求平安'],['wealth','求财运'],['love','求姻缘'],['career','求事业'],['study','求学业'],['taisui','化太岁'],['rite','做法事']]
type Row={kind:string;id:string;name:string;serviceCode:string;serviceName:string;tags:string;mode:'inherit'|'custom';selected:string[]}
const rows=ref<Row[]>([]),busy=ref(false),error=ref(''),tab=ref('rule'),keyword=ref(''),page=ref(1)
const filtered=computed(()=>rows.value.filter(r=>(tab.value==='rule'?r.kind==='rule':r.kind!=='rule')&&`${r.name} ${r.id} ${r.serviceName} ${r.serviceCode}`.includes(keyword.value.trim())))
const shown=computed(()=>filtered.value.slice((page.value-1)*20,page.value*20))
watch([tab,keyword],()=>{page.value=1})
async function load(){busy.value=true;try{const d=await client.get<{list:Row[]}>('/admin/platform/intentions/bindings');rows.value=d.list.map(r=>({...r,selected:r.tags?r.tags.split(','):[]}));error.value=''}catch(e){error.value=e instanceof Error?e.message:'加载失败'}finally{busy.value=false}}
async function save(row:Row,mode:'inherit'|'custom'='custom'){busy.value=true;try{await client.put('/admin/platform/intentions/bindings',{kind:row.kind,id:row.id,serviceCode:row.serviceCode,tags:mode==='inherit'?[]:row.selected,mode});ElMessage.success((mode==='inherit' ? uiText('已恢复标准服务规则') : uiText('关联已保存')));await load()}catch(e){error.value=e instanceof Error?e.message:'保存失败'}finally{busy.value=false}}
const rowKey = (r: Row) => `${r.kind}:${r.id}:${r.serviceCode}`
onMounted(load)
</script>
<template>
  <section class="dfx-page service-intentions"><PageHeader :title='$t("心愿与服务关联")' :subtitle='$t("七个心愿入口保持固定。新服务自动继承标准规则；提供者可单独调整，手动空选表示不进入心愿页。上下架与资质校验仍然生效。")' />
    <el-alert v-if="error" :title="$t(error)" type="error" :closable="false"/><el-button v-if="error" @click="load">{{ $t("重试") }}</el-button>
    <div class="dfx-card"><el-tabs v-model="tab"><el-tab-pane :label='$t("标准服务规则")' name="rule"/><el-tab-pane :label='$t("提供者服务")' name="provider"/></el-tabs>
    <el-input v-model="keyword" clearable :placeholder='$t("搜索名称、编码或服务")' style="max-width:360px;margin-bottom:16px"/>
    <el-table :data="shown" v-loading="busy" :row-key="rowKey">
      <el-table-column prop="name" :label='$t("提供者 / 规则")' min-width="180"/>
      <el-table-column :label='$t("类型")' width="90"><template #default="{row}">{{$t((row.kind==='master' ? $t('师傅') : (row.kind==='temple' ? $t('寺院') : $t('标准规则'))))}}</template></el-table-column>
      <el-table-column prop="serviceName" :label='$t("实际服务")' width="120"/>
      <el-table-column v-if="tab==='provider'" :label='$t("当前来源")' width="110"><template #default="{row}"><el-tag :type="row.mode==='inherit'?'info':'success'">{{$t((row.mode==='inherit' ? $t('跟随标准') : $t('手动配置')))}}</el-tag></template></el-table-column>
      <el-table-column :label='$t("关联心愿")' min-width="420"><template #default="{row}"><el-checkbox-group v-model="row.selected"><el-checkbox v-for="[code,name] in tags" :key="code" :value="code">{{$t(name)}}</el-checkbox></el-checkbox-group></template></el-table-column>
      <el-table-column :label='$t("操作")' width="180"><template #default="{row}"><el-button :disabled="busy" @click="save(row)">{{ $t("保存") }}</el-button><el-button v-if="row.kind!=='rule'&&row.mode==='custom'" link :disabled="busy" @click="save(row,'inherit')">{{ $t("恢复默认") }}</el-button></template></el-table-column>
    </el-table>
    <el-pagination v-model:current-page="page" :page-size="20" :total="filtered.length" layout="total, prev, pager, next" style="margin-top:20px"/>
    </div>
  </section>
</template>
