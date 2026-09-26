<script setup lang="ts">
import {ref,computed,watch,onBeforeUnmount} from 'vue'
import client from '@/api/client'
import {useAuthStore} from '@/stores/auth'
import {money,settlementStatus,withdrawalStatus,type ProviderWallet} from '../../../../packages/wallet/contracts'
const metrics: [string, keyof ProviderWallet['summary']][] = [['待确认结算','pendingCents'],['已确认结算','confirmedCents'],['账面已结算','recordedPaidCents']]
const auth=useAuthStore(),page=ref(1),tab=ref('settlements'),data=ref<ProviderWallet|null>(null),error=ref(''),loading=ref(false)
let generation=0
async function load(){const seq=++generation;data.value=null;error.value='';loading.value=true;try{const result=await client.get<ProviderWallet>('/finance/wallet/temple',{params:{page:page.value}});if(seq===generation)data.value=result}catch(e){if(seq===generation)error.value=e instanceof Error?e.message:'钱包暂时无法读取'}finally{if(seq===generation)loading.value=false}}
watch([page,()=>auth.token],load,{immediate:true});onBeforeUnmount(()=>generation++)
const total=computed(()=>data.value?(tab.value==='settlements'?data.value.total:data.value.withdrawalTotal):0)
function changeTab(){page.value=1}
</script>
<template><div class="temple-wallet"><header><h1>寺院钱包</h1><p>每一笔结算，都有来处</p></header><el-alert title="仅统计本寺院结算份额，不包含大师个人收入。当前为账面记录，含演示业务；真实提现暂未开放，结算状态不代表银行到账。" type="info" :closable="false" show-icon/>
<div class="wallet-overview"><section v-for="[label,key] in metrics" :key="key"><span>{{label}}</span><strong>{{data?money(data.summary[key]):'—'}}</strong></section></div>
<el-tabs v-model="tab" @tab-change="changeTab"><el-tab-pane label="结算明细" name="settlements"/><el-tab-pane label="历史提现" name="withdrawals"/></el-tabs>
<div v-if="error" role="alert"><p>{{error}}</p><el-button @click="load">重新加载</el-button></div><p v-else-if="loading" role="status">正在读取钱包…</p><template v-else-if="data">
<template v-if="tab==='settlements'"><div class="wallet-records"><details v-for="row in data.settlements" :key="row.id"><summary><span><b>{{settlementStatus[row.status]||row.status}}</b><small>{{row.createdAt}}</small></span><strong>{{money(row.netCents)}} <small>应结金额 · 详情</small></strong></summary><dl><dt>结算编号</dt><dd>{{row.number}}</dd><dt>寺院分配金额</dt><dd>{{money(row.grossCents)}}</dd><dt>平台费用</dt><dd>{{money(row.commissionCents)}}</dd><dt>来源单号</dt><dd>{{row.sourceNo||'历史汇总结算'}}</dd></dl><router-link v-if="row.sourceType==='booking'&&row.sourceNo" :to="'/bookings/'+encodeURIComponent(row.sourceNo)">查看预约 →</router-link></details></div></template>
<template v-else><p>历史模拟提现仅供核对流程，不代表银行打款成功。</p><div class="wallet-records"><details v-for="row in data.withdrawals" :key="row.id"><summary><span><b>{{withdrawalStatus[row.status]||row.status}}</b><small>{{row.createdAt}}</small></span><strong>{{money(row.amountCents)}}</strong></summary><p>{{row.number}} · 模拟记录</p></details></div></template>
<el-empty v-if="!total" description="暂无记录，后续结算会集中展示在这里"/><el-pagination v-if="total>20||page>1" v-model:current-page="page" :page-size="20" :total="total" layout="prev,pager,next"/></template></div></template>
<style scoped>.temple-wallet{max-width:1000px;margin:auto}.temple-wallet header p{color:var(--el-text-color-secondary)}.wallet-overview{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin:24px 0}.wallet-overview section{border:1px solid var(--el-border-color);background:var(--el-bg-color);border-radius:16px;padding:24px}.wallet-overview span,.wallet-overview strong{display:block}.wallet-overview strong{font-size:28px;margin-top:12px;font-variant-numeric:tabular-nums}.wallet-records details{padding:18px;margin-bottom:12px;border:1px solid var(--el-border-color);border-radius:12px;background:var(--el-bg-color)}summary{cursor:pointer;display:flex;justify-content:space-between;align-items:center;gap:16px;min-height:44px}summary small{display:block;font-size:12px;color:var(--el-text-color-secondary);margin-top:6px}summary strong{text-align:right;font-variant-numeric:tabular-nums}dl{display:grid;grid-template-columns:120px 1fr;gap:12px;margin-top:20px}dd{margin:0;overflow-wrap:anywhere}dt{color:var(--el-text-color-secondary)}@media(max-width:700px){.wallet-overview{grid-template-columns:1fr;gap:8px}.wallet-overview section{padding:16px;display:flex;justify-content:space-between;align-items:center}.wallet-overview strong{margin:0;font-size:22px}}
</style>
