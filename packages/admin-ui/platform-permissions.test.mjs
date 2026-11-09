import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {createRequire} from 'node:module'
import test from 'node:test'
const require=createRequire(new URL('../../apps/web-platform-admin/package.json',import.meta.url))
const ts=require('typescript'),vue=require('vue'),{createRouter,createMemoryHistory}=require('vue-router')
const read=p=>readFileSync(new URL(p,import.meta.url),'utf8')
function compile(source,bindings={}){const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;const exports={};new Function('exports','require',js)(exports,n=>bindings[n]??{});return exports}
const access=compile(read('../../apps/web-platform-admin/src/router/access.ts'))
const {commerceRoutes}=compile(read('../../apps/web-platform-admin/src/commerce/routes.ts'))
const {agentCenterSections}=compile(read('../../apps/web-platform-admin/src/views/ai/centerNavigation.ts'))
const {agentCenterRoutes}=compile(read('../../apps/web-platform-admin/src/router/agentCenter.ts'),{'@/views/ai/centerNavigation':{agentCenterSections}})
const source=read('../../apps/web-platform-admin/src/router/index.ts')
const definitions=source.slice(source.indexOf('const routes:'),source.indexOf('const router ='))
const js=ts.transpileModule(definitions,{compilerOptions:{target:ts.ScriptTarget.ES2020}}).outputText
const routes=new Function('commerceRoutes','agentCenterRoutes','defaultRoute','useAuthStore','Layout',js+'\nreturn routes')(commerceRoutes,agentCenterRoutes,access.defaultRoute,()=>({roles:['platform_super']}),{})
const router=createRouter({history:createMemoryHistory(),routes})
const snapshot={clientId:'platform-admin',authzScope:'platform',permissions:['platform.products.read']}
test('custom direct URLs match menu policy, and empty grants have a safe landing',()=>{
 const role=['product_reader'];const allowed=(path,s=snapshot)=>access.canAccessRoute(router.resolve(path),role,s)
 assert.equal(allowed('/commerce/products'),true);assert.equal(allowed('/commerce/products/edit/1'),false)
 for(const path of ['/settings/role','/marketing/home-display','/settings/taxonomy','/services/overview','/finance/payout-sandbox','/commerce/creator-rewards'])assert.equal(allowed(path),false,path)
 assert.equal(access.defaultRoute(role,snapshot),'/commerce/products');const empty={...snapshot,permissions:[]}
 assert.equal(access.defaultRoute(role,empty),'/access-denied');assert.equal(allowed('/access-denied',empty),true);assert.equal(allowed('/commerce/products',empty),false)
 for(const forged of [{...snapshot,clientId:'temple-admin'},{...snapshot,authzScope:'temple'},null])assert.equal(allowed('/commerce/products',forged),false)
 assert.equal(access.canAccessRoute(router.resolve('/commerce/products'),['temple_admin'],snapshot),false)
})
test('write grants cannot open standards, onboarding or sensitive shared-prefix modules',()=>{
 const role=['catalog_editor'],s={...snapshot,permissions:['platform.products.read','platform.products.write','platform.masters.read','platform.masters.write','platform.temples.read','platform.temples.write','platform.finance.read','platform.finance.write','super.security']}
 for(const path of ['/settings/account','/settings/accounts/12','/settings/role','/settings/taxonomy','/settings/regions','/settings/directory-tags','/onboarding/review','/master/create','/master/review','/temple/review','/finance/payout-sandbox','/services/overview','/ai/agent','/audit/comment','/audit/design'])assert.equal(access.canAccessRoute(router.resolve(path),role,s),false,path)
 assert.equal(access.canAccessRoute(router.resolve('/master/list'),role,s),true);assert.equal(access.canAccessRoute(router.resolve('/commerce/products/edit/1'),role,s),true)
 assert.equal(access.canAccessRoute(router.resolve('/master/list'),['shop_admin'],s),false)
})
function component(path,expose,api={}){const script=read(path).match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1];return compile(script+'\nexport {'+expose+'};',{
 vue:{...vue,onMounted(){}},'@/i18n':{ElMessage:{warning(){},success(){}},ElMessageBox:{}},'../../../../../packages/localization/language':{t:v=>v},'@/api/auth':api,'vue-router':{useRoute:()=>({query:{}}),useRouter:()=>({})}
})}
test('role matrix preserves CAS-conflicting drafts and reloads the authoritative revision',async()=>{
 let revision=4,saved=0
 const state=component('../../apps/web-platform-admin/src/views/settings/SettingsRoleView.vue','grant,openPermissions,reloadGrant,saveGrant',{getRolePermissions:async()=>({revision,permissionCodes:['platform.products.read'],editable:true}),setRolePermissions:async(_id,r)=>{saved++;assert.equal(r,4);throw new Error('40916')}})
 await state.openPermissions({id:20,name:'编辑'});assert.equal(state.grant.revision,4)
 state.grant.codes=['platform.products.write'];await state.saveGrant();assert.equal(saved,0)
 state.grant.codes=['platform.products.read','platform.products.write'];await state.saveGrant();assert.equal(saved,1);assert.equal(state.grant.error,true);assert.equal(state.grant.visible,true);assert.equal(state.grant.codes.length,2)
 revision=6;await state.reloadGrant();assert.equal(state.grant.revision,6);assert.deepEqual([...state.grant.codes],['platform.products.read']);assert.equal(state.grant.error,false)
})
test('account binding choices fetch beyond one hundred and reject truncated paging',async()=>{
 const state=component('../../apps/web-platform-admin/src/views/settings/SettingsAccountView.vue','loadAllBindings')
 const calls=[];const all=await state.loadAllBindings(async page=>{calls.push(page);return{total:102,list:page===1?Array.from({length:100},(_,i)=>({id:String(i+1)})):[{id:'101'},{id:'102'}]}})
 assert.equal(all.length,102);assert.deepEqual(calls,[1,2]);await assert.rejects(state.loadAllBindings(async page=>({total:2,list:page===1?[{id:'1'}]:[]})),/不完整/)
})

test('late authorization responses cannot restore a logged-out identity or overwrite a new login',async()=>{
 const {createAuthorizationBootstrap,StaleAuthorizationError}=compile(read('../../apps/web-platform-admin/src/utils/adminAccess.ts'))
 const requests=[];let value=null
 const bootstrap=createAuthorizationBootstrap(()=>new Promise(resolve=>requests.push(resolve)),v=>{value=v})
 const old=bootstrap.ensure();assert.equal(bootstrap.ensure(),old)
 bootstrap.invalidate();const fresh=bootstrap.ensure();requests[1]({role:'new'});await fresh
 requests[0]({role:'old'});await assert.rejects(old,StaleAuthorizationError);assert.deepEqual(value,{role:'new'})
 bootstrap.invalidate();assert.equal(value,null)
})

test('a late matrix read cannot replace a newly opened role with another role permissions',async()=>{
 const reads=[];const state=component('../../apps/web-platform-admin/src/views/settings/SettingsRoleView.vue','grant,openPermissions',{getRolePermissions:id=>new Promise(resolve=>reads.push({id,resolve}))})
 const first=state.openPermissions({id:20,name:'A'}),second=state.openPermissions({id:21,name:'B'})
 reads[1].resolve({revision:7,permissionCodes:['platform.products.read'],editable:true});await second
 reads[0].resolve({revision:4,permissionCodes:['platform.operations.read'],editable:true});await first
 assert.equal(state.grant.id,21);assert.equal(state.grant.revision,7);assert.deepEqual([...state.grant.codes],['platform.products.read'])
})

test('moderation roles land on delegated reports, while mixed-type queues remain super only',()=>{
 const s={...snapshot,permissions:['platform.moderation.read']},r=['moderator']
 assert.equal(access.defaultRoute(r,s),'/audit/report');assert.equal(access.canAccessRoute(router.resolve('/audit/report'),r,s),true)
 for(const path of ['/audit/comment','/audit/design'])assert.equal(access.canAccessRoute(router.resolve(path),r,s),false)
})

test('write actions respect both the identity boundary and the specific write grant',()=>{
 const finance={...snapshot,permissions:['platform.finance.read']}
 assert.equal(access.hasPlatformPermission(['finance_reader'],finance,'platform.finance.write',['platform_super']),false)
 assert.equal(access.hasPlatformPermission(['finance_editor'],{...finance,permissions:['platform.finance.write']},'platform.finance.write',['platform_super']),true)
 assert.equal(access.hasPlatformPermission(['customer'],{...finance,permissions:['platform.finance.write']},'platform.finance.write',['platform_super']),false)
 assert.equal(access.hasPlatformPermission(['finance_editor'],{...finance,clientId:'temple-admin',permissions:['platform.finance.write']},'platform.finance.write',['platform_super']),false)
 assert.equal(access.hasPlatformPermission(['platform_service'],null,'platform.finance.write',['platform_super']),false)
 assert.equal(access.hasPlatformPermission(['shop_admin'],null,'platform.finance.write',['platform_super']),false)
 assert.equal(access.hasPlatformPermission(['shop_admin'],null,'platform.products.write',['platform_super','shop_admin']),true)
})
function finance(path,expose,api,auth={roles:['platform_super']}){
 const script=read('../../apps/web-platform-admin/src/views/finance/'+path).match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1]
 return compile(script+'\nexport {'+expose+'};',{
  vue:{...vue,onMounted(){},onBeforeUnmount(){}},'@/stores/auth':{useAuthStore:()=>auth},'@/router/access':access,
  '@/api/finance':api,'@/i18n':{ElMessage:{warning(){},success(){}},ElMessageBox:{confirm:async()=>{},prompt:async()=>({value:'原因'})}},
  '../../../../../packages/localization/language':{t:v=>v}
 })
}
test('a failed finance refresh retains data but cannot submit settlement or withdrawal actions',async()=>{
 for(const [path,apiName,actionName,expose] of [
  ['FinanceTempleView.vue','getSettlements','confirm','loadData,list,confirm,loading,loadError'],
  ['FinanceMasterView.vue','getSettlements','confirmSettle','loadData,sList,confirmSettle,loading,loadError'],
  ['FinanceReconcileView.vue','getWithdrawals','auditW','loadWithdrawals,wList,auditW,loading,loadError']
 ]){
  let failed=false,writes=0;const row={id:1,settlementNo:'S1',withdrawalNo:'W1',status:'pending',settleAmount:9.9,amount:9.9}
  const state=finance(path,expose,{[apiName]:async()=>{if(failed)throw new Error('连接失败');return{list:[row],total:1}},confirmSettlement:async()=>{writes++},auditWithdrawal:async()=>{writes++}})
  const load=state.loadData||state.loadWithdrawals;await load();failed=true;await load()
  assert.equal(state.loadError.value,true);assert.equal((state.list||state.sList||state.wList).value.length,1)
  await state[actionName](row,'approve');assert.equal(writes,0,path)
 }
})
test('commission writes require a successful current configuration read',async()=>{
 let failed=false,writes=0
 const state=finance('FinanceOverviewView.vue','loadData,saveConfig,configs,configsReady',{getFinanceOverview:async()=>({}),getCommissionConfigs:async()=>{if(failed)throw new Error('读取失败');return[{id:1,rate:.1,description:''}]},updateCommissionConfig:async()=>{writes++}})
 await state.loadData();assert.equal(state.configsReady.value,true);failed=true;await state.loadData()
 assert.equal(state.configs.value.length,1);assert.equal(state.configsReady.value,false)
 await state.saveConfig(state.configs.value[0]);assert.equal(writes,0)
})
