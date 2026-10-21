import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {createRequire} from 'node:module'
import test from 'node:test'
const require=createRequire(new URL('../../apps/web-platform-admin/package.json',import.meta.url))
const ts=require('typescript'),vue=require('vue')
function compile(source,bindings={}){
 const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
 const exports={};new Function('exports','require',js)(exports,name=>bindings[name]??{});return exports
}
const read=path=>readFileSync(new URL(path,import.meta.url),'utf8')
const affiliation=compile(read('./affiliation.ts'))
const shared={vue:{...vue,onMounted(){}},'@/i18n':{ElMessage:{success(){},warning(){},error(){}},ElMessageBox:{}},'@/api/client':{isAdminSessionExpired:()=>false}}
const script=(path,expose)=>read(path).match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1]+'\nexport {'+expose+'};'
for(const kind of ['master','temple'])test(`${kind} fixed directory survives an empty result and preserves a conflicting selected filter`,async()=>{
 const path=`../../apps/web-platform-admin/src/views/${kind}/${kind==='master'?'Master':'Temple'}ListView.vue`
 const state=compile(script(path,'query,directoryTags,list,traditions,loadData'),{
  ...shared,'vue-router':{useRouter:()=>({})},'../../../../../packages/admin-ui/affiliation':affiliation,
  ['@/api/'+kind]:{[kind==='master'?'getMasterList':'getTempleList']:async()=>({list:[],total:0})}
 })
 const tags=Array.from({length:25},(_,i)=>({code:`tag_${i}`,group:'tradition',beliefCode:i===24?'daoism':'han_buddhism',name:`目录${i}`,status:'enabled'}))
 state.directoryTags.value=tags;assert.equal(state.traditions.value.length,25)
 state.query.beliefCode='han_buddhism';state.query.traditionCode='tag_24'
 await state.loadData();assert.equal(state.list.value.length,0);assert.equal(state.traditions.value.length,25);assert.equal(state.query.traditionCode,'tag_24')
 state.query.beliefCode='';assert.equal(state.traditions.value.length,25)
})
test('temple profile edit omits standardized affiliation, while initial creation sends it in the single create request',async()=>{
 const source=script('../../apps/web-temple-admin/src/views/MasterEditView.vue','form,formRef,affiliation,loadMaster,handleSubmit')
 const fixture={id:'m1',dharmaName:'法号',layName:'姓名',position:'职务',beliefCode:'taoism',traditionCodes:['old_disabled'],sect:'原始资料',type:'道教',specialties:[],avatar:''}
 let update,created,updates=0,creates=0
 function stateFor(id){return compile(source,{
  ...shared,'vue-router':{useRoute:()=>({params:{id}}),useRouter:()=>({push(){}})},'@/stores/auth':{useAuthStore:()=>({templeId:'t1',templeName:'测试寺院'})},
  '../../../../packages/admin-ui/affiliation':affiliation,'../../../../packages/localization/language':{t:value=>value},
  '@/api/master':{getMasterDetail:async()=>fixture,updateMaster:async(_id,payload)=>{updates++;update=payload},createMaster:async payload=>{creates++;created=payload}}
 })}
 const edit=stateFor('m1');edit.formRef.value={validate:async callback=>await callback(true)};await edit.loadMaster();assert.equal(edit.form.beliefCode,'daoism');assert.deepEqual([...edit.form.traditionCodes],['old_disabled'])
 edit.form.sect='资料补充';await edit.handleSubmit();assert.equal(updates,1);assert.equal(update.sect,'资料补充');assert.ok(!('beliefCode'in update));assert.ok(!('traditionCodes'in update));assert.equal(creates,0)
 const create=stateFor('');create.formRef.value={validate:async callback=>await callback(true)};create.affiliation.value={validate:()=>''};Object.assign(create.form,fixture,{beliefCode:'daoism',traditionCodes:['quanzhen'],sect:''})
 await create.handleSubmit();assert.equal(creates,1);assert.equal(updates,1);assert.deepEqual(created.traditionCodes,['quanzhen']);assert.equal(created.beliefCode,'daoism');assert.equal(created.sect,'')
})
test('legacy submitted application without standard tags cannot approve or change its status',async()=>{
 let writes=0
 const source=script('../../apps/web-platform-admin/src/views/OnboardingReviewView.vue','selected,error,note,review')
 const state=compile(source,{...shared,'../../../../packages/localization/language':{t:v=>v},'../../../../packages/admin-ui/affiliation':affiliation,'@/stores/auth':{useAuthStore:()=>({})},'@/api/client':{default:{post:async()=>{writes++}}}})
 state.selected.value={id:'legacy',status:'submitted',revision:4,profile:{belief:'taoism',sect:'历史文本'}}
 await state.review(true);assert.equal(writes,0);assert.equal(state.selected.value.status,'submitted');assert.equal(state.selected.value.profile.sect,'历史文本');assert.ok(state.error.value.includes('退回补充'))
})
test('approval is a single revision-aware transaction request; the frontend never writes provider relations separately',async()=>{
 const writes=[]
 const source=script('../../apps/web-platform-admin/src/views/OnboardingReviewView.vue','selected,error,note,review')
 const state=compile(source,{...shared,'@/i18n':{ElMessage:{success(){}},ElMessageBox:{confirm:async()=>{}}},'../../../../packages/localization/language':{t:v=>v},'../../../../packages/admin-ui/affiliation':affiliation,'@/stores/auth':{useAuthStore:()=>({})},'@/api/client':{default:{post:async(path,body)=>{writes.push({path,body})},get:async()=>({list:[]})}}})
 state.selected.value={id:'current',status:'submitted',revision:9,profile:{belief:'daoism',traditionCodes:['quanzhen']}}
 await state.review(true);assert.equal(writes.length,1);assert.equal(writes[0].path,'/auth/onboarding/review');assert.equal(writes[0].body.revision,9);assert.equal(writes[0].body.approve,true)
})
