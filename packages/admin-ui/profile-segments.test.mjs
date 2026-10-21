import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {createRequire} from 'node:module'
import test from 'node:test'
const require=createRequire(new URL('../../apps/web-platform-admin/package.json',import.meta.url))
const ts=require('typescript'),vue=require('vue')
const affiliationSource=readFileSync(new URL('./affiliation.ts',import.meta.url),'utf8')
function moduleOf(source,bindings){
 const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
 const exports={};new Function('exports','require',js)(exports,name=>bindings[name]??{});return exports
}
const affiliation=moduleOf(affiliationSource,{})
const text=readFileSync(new URL('../../apps/web-platform-admin/src/views/master/MasterDetailView.vue',import.meta.url),'utf8')
const script=text.match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1]+'\nexport {form,master,serviceCatalog,serviceTags,tagEdits,startEdit,saveProfile,saveServices,dirty,profileFailed,serviceFailed,profileBaseline,servicesReady,serviceLoadError,loadDetail,loadServiceConfig};'
const original={id:'m1',dharmaName:'原法号',layName:'姓名',position:'职务',beliefCode:'han_buddhism',sect:'旧宗派说明',type:'汉传佛教',specialties:[],avatar:'',traditionCodes:['old_code']}
function fixture(api){
 const state=moduleOf(script,{
  vue:{...vue,onMounted(){},onUnmounted(){}},'vue-router':{useRoute:()=>({params:{id:'m1'}}),useRouter:()=>({}),onBeforeRouteLeave(){}},
  '@/stores/auth':{useAuthStore:()=>({roles:['platform_super']})},'@/i18n':{ElMessage:{success(){},warning(){},error(){}},ElMessageBox:{}},
  '../../../../../packages/localization/language':{t:v=>v},'@/api/client':{isAdminSessionExpired:()=>false},
  '../../../../../packages/admin-ui/affiliation':affiliation,'@/api/master':api
 })
 state.master.value={...original};state.servicesReady.value=true;state.serviceCatalog.value=[{code:'S001',name:'祈福'}];state.serviceTags.value=[];state.startEdit();return state
}
test('profile success and service failure preserve only the failed draft for retry',async()=>{
 let profileCalls=0,serviceCalls=0
 const state=fixture({updatePlatformMaster:async(_id,payload)=>{profileCalls++;return{...original,...payload}},updatePlatformMasterServiceTags:async(_id,tags)=>{serviceCalls++;if(serviceCalls===1)throw new Error('服务暂时失败');return{list:tags}}})
 state.form.value.dharmaName='新法号';state.tagEdits.value[0].enabled=true;state.tagEdits.value[0].price=12
 await state.saveProfile();await state.saveServices()
 assert.equal(profileCalls,1);assert.equal(state.profileFailed.value,false);assert.equal(state.serviceFailed.value,true)
 assert.equal(state.form.value.dharmaName,'新法号');assert.equal(state.tagEdits.value[0].price,12);assert.equal(state.dirty.value,true)
 await state.saveServices()
 assert.equal(profileCalls,1);assert.equal(serviceCalls,2);assert.equal(state.dirty.value,false);assert.equal(state.serviceTags.value[0].price,12)
})
test('profile failure never sends a service request or drops the profile draft',async()=>{
 let serviceCalls=0
 const state=fixture({updatePlatformMaster:async()=>{throw new Error('版本冲突，请比较后重试')},updatePlatformMasterServiceTags:async()=>{serviceCalls++;return{list:[]}}})
 state.form.value.sect='保留的草稿'
 await state.saveProfile()
 assert.equal(serviceCalls,0);assert.equal(state.profileFailed.value,true);assert.equal(state.form.value.sect,'保留的草稿');assert.equal(state.dirty.value,true)
})
test('edits made during a pending save are still unsaved after its response',async()=>{
 let finish,calls=0,payload
 const state=fixture({updatePlatformMaster:(_id,data)=>{calls++;payload=data;return new Promise(resolve=>{finish=resolve})}})
 state.form.value.dharmaName='提交时名字';const pending=state.saveProfile();await state.saveProfile()
 state.form.value.dharmaName='请求中继续编辑';finish({...original,...payload});await pending
 assert.equal(calls,1);assert.equal(payload.dharmaName,'提交时名字');assert.equal(state.form.value.dharmaName,'请求中继续编辑');assert.equal(state.dirty.value,true)
})

test('service load failure leaves the profile visible and blocks empty service replacement',async()=>{
 let writes=0
 const state=fixture({getPlatformMasterDetail:async()=>({...original}),getServiceTypes:async()=>({list:[{code:'S001',name:'祈福'}]}),getPlatformMasterServiceTags:async()=>{throw new Error('服务读取超时')},updatePlatformMasterServiceTags:async()=>{writes++;return{list:[]}}})
 await state.loadDetail();assert.equal(state.master.value.dharmaName,original.dharmaName);assert.equal(state.servicesReady.value,false);assert.equal(state.serviceLoadError.value,'服务读取超时')
 state.startEdit();await state.saveServices();assert.equal(writes,0)
})

test('changing belief cannot save a conflicting relation or silently discard historical tags',async()=>{
 let writes=0
 const state=fixture({updatePlatformMaster:async()=>{writes++;return original}})
 state.form.value.beliefCode='daoism';await state.saveProfile()
 assert.equal(writes,0);assert.equal(state.form.value.beliefCode,'daoism');assert.deepEqual([...state.master.value.traditionCodes],['old_code']);assert.equal(state.dirty.value,true)
})
