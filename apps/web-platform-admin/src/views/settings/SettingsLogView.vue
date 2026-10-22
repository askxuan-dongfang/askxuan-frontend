<template>
 <div class="dfx-page">
  <PageHeader :title='$t("操作日志")' :subtitle='$t("已验签管理账号的写操作记录；不采集密码、邮箱、密钥或请求正文")'><template #actions><el-button :icon="Refresh" @click="loadData">{{ $t('刷新') }}</el-button></template></PageHeader>
  <el-alert type="info" :closable="false" :title='$t("待确认或结果未知不等于业务失败。请先核对业务数据，避免重复提交。")' />
  <div class="dfx-card filter-bar"><el-input-number v-model="query.actorId" :min="1" :controls="false" :placeholder='$t("操作人ID")' /><el-input v-model="query.action" clearable :placeholder='$t("操作权限编码")' @keyup.enter="onSearch" /><el-select v-model="query.result" clearable :placeholder='$t("操作结果")'><el-option v-for="item in results" :key="item.value" :value="item.value" :label="$t(item.label)" /></el-select><el-button type="primary" @click="onSearch">{{ $t('查询') }}</el-button></div>
  <el-alert v-if="loadError" type="error" :closable="false" :title='$t("操作日志加载失败，请重试")' />
  <div class="dfx-card table-wrap"><DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
   <el-table-column :label='$t("操作时间")' min-width="175"><template #default="{row}">{{ formatDate(row.startedAt) }}</template></el-table-column><el-table-column :label='$t("操作人ID")' prop="actorId" width="110" /><el-table-column :label='$t("角色")' min-width="160"><template #default="{row}">{{ row.actorRoles.join(', ') }}</template></el-table-column><el-table-column :label='$t("操作")' prop="action" min-width="190" /><el-table-column :label='$t("目标")' min-width="150"><template #default="{row}">{{ row.targetType }}{{ row.targetId ? ' · '+row.targetId : '' }}</template></el-table-column>
   <el-table-column :label='$t("结果")' width="110"><template #default="{row}"><el-tag :type="row.result==='success'?'success':row.result==='failed'||row.result==='denied'?'danger':'warning'">{{ $t(resultLabel(row.result)) }}</el-tag></template></el-table-column><el-table-column :label='$t("状态 / 业务码")' min-width="140"><template #default="{row}">{{ row.httpStatus || '—' }} / {{ row.businessCode < 0 ? '—' : row.businessCode }}</template></el-table-column><el-table-column :label='$t("请求路径模板")' prop="routeTemplate" min-width="250" show-overflow-tooltip /><el-table-column :label='$t("追踪编号")' prop="requestId" min-width="270" />
  </DataTable></div>
 </div>
</template>
<script setup lang="ts">
import {ref,reactive,onMounted} from 'vue'
import {Refresh} from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import {getOperationLogs,type AdminOperation} from '@/api/system'
import {formatDate} from '@/utils/format'
const loading=ref(false),loadError=ref(false),list=ref<AdminOperation[]>([]),total=ref(0)
const query=reactive({actorId:undefined as number|undefined,action:'',result:'',page:1,size:20})
const results=[{value:'success',label:'成功'},{value:'denied',label:'已拒绝'},{value:'failed',label:'失败'},{value:'pending',label:'待确认'},{value:'unknown',label:'结果未知'}]
function resultLabel(value:string){return results.find(item=>item.value===value)?.label||value}
async function loadData(){loading.value=true;loadError.value=false;try{const r=await getOperationLogs(query);list.value=r.list||[];total.value=r.total||0}catch{loadError.value=true}finally{loading.value=false}}
function onSearch(){query.page=1;void loadData()}
onMounted(loadData)
</script>
<style scoped>
.filter-bar{display:flex;flex-wrap:wrap;gap:12px;padding:16px;margin:16px 0;}
.filter-bar :deep(.el-input),.filter-bar :deep(.el-select){width:200px;}
.table-wrap{padding:16px;}
</style>
