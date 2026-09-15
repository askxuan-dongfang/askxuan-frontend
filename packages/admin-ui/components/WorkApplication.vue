<script setup lang="ts">
import {ref,computed,onMounted} from 'vue'
const props=defineProps<{token:string;kind:'master'|'temple'}>()
const emit=defineEmits<{exit:[]}>()
const app=ref<any>(),busy=ref(false),error=ref(''),notice=ref(''),history=ref<any[]>([])
const editable=computed(()=>['draft','rejected'].includes(app.value?.status))
const labels:Record<string,string>={draft:'待完善资料',submitted:'平台审核中',rejected:'请补充材料',approved:'已通过审核'}
async function call(path:string,body?:unknown){const r=await fetch('/api/v1/auth/onboarding/'+path,{method:body?'POST':'GET',headers:{Authorization:'Bearer '+props.token,...(body instanceof FormData?{}:{'Content-Type':'application/json'})},body:body?(body instanceof FormData?body:JSON.stringify(body)):undefined});const d=await r.json();if(d.code!==0)throw new Error([40101,40102].includes(d.code)?'登录状态已失效或身份已更新，请退出后重新登录查看最新结果':d.message||'操作未完成');return d.data}
async function load(){error.value='';try{app.value=await call('application');app.value.profile={name:'',legalName:'',contact:'',region:'',address:'',belief:'',sect:'',position:'',registrationNumber:'',description:'',evidenceIds:[],...app.value.profile};history.value=(await call('history?id='+app.value.id)).list}catch(e){error.value=(e as Error).message}}
async function save(submit:boolean){busy.value=true;error.value='';notice.value='';try{app.value=await call('application',{profile:app.value.profile,revision:app.value.revision,submit});notice.value=submit?'申请已提交，可在这里查看审核进度':'草稿已保存';await load()}catch(e){error.value=(e as Error).message}finally{busy.value=false}}
async function upload(e:Event){const input=e.target as HTMLInputElement;const f=input.files?.[0];if(!f)return;busy.value=true;error.value='';try{if(f.size>5*1024*1024)throw new Error('每份材料不能超过 5MB');const body=new FormData();body.append('file',f);const result=await call('evidence',body);app.value.profile.evidenceIds.push(result.id);notice.value='材料已上传，请保存草稿或提交申请'}catch(e){error.value=(e as Error).message}finally{input.value='';busy.value=false}}
async function download(id:string){try{const r=await fetch('/api/v1/auth/onboarding/evidence?id='+encodeURIComponent(id),{headers:{Authorization:'Bearer '+props.token}});if(!r.ok||r.headers.get('content-type')?.includes('json'))throw new Error('无法读取材料');const url=URL.createObjectURL(await r.blob());const a=document.createElement('a');a.href=url;a.download='认证材料';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)}catch(e){error.value=(e as Error).message}}
onMounted(load)
</script>
<template><section class="work-application">
<header><p>问玄东方 · {{kind==='temple'?'寺院入驻':'独立大师认证'}}</p><h1>{{app?labels[app.status]:'正在加载申请'}}</h1><p>{{kind==='temple'?'请由获得寺院授权的经办人填写机构资料。':'请填写本人资料，审核通过后开通独立大师工作台。'}}</p></header>
<p v-if="error" role="alert">{{error}}</p><p v-if="notice" role="status">{{notice}}</p>
<template v-if="app"><p v-if="app.reviewNote" class="review-note">审核意见：{{app.reviewNote}}</p>
<p v-if="app.status==='approved'">审核已通过，请重新登录以进入工作台。</p>
<form v-else @submit.prevent="save(true)"><fieldset :disabled="busy||!editable">
<label>{{kind==='temple'?'寺院名称':'对外称呼／法名'}}<input v-model="app.profile.name" required maxlength="64"/></label>
<label>{{kind==='temple'?'经办人姓名':'本人姓名'}}<input v-model="app.profile.legalName" required maxlength="64" autocomplete="name"/></label>
<label>联系电话<input v-model="app.profile.contact" required maxlength="64" type="tel"/></label>
<label>所在地区<input v-model="app.profile.region" required maxlength="64"/></label>
<label>信仰流派<select v-model="app.profile.belief" required><option value="" disabled>请选择信仰流派</option><option value="han_buddhism">汉传佛教</option><option value="tibetan_buddhism">藏传佛教</option><option value="taoism">道教</option><option value="folk">民间信仰</option></select></label>
<label>宗派<input v-model="app.profile.sect" required maxlength="32"/></label>
<template v-if="kind==='temple'"><label>详细地址<input v-model="app.profile.address" required maxlength="255"/></label><label>机构登记证号<input v-model="app.profile.registrationNumber" required maxlength="100"/></label></template>
<label v-else>身份／职务<input v-model="app.profile.position" required maxlength="32"/></label>
<label>{{kind==='temple'?'寺院简介':'个人介绍与服务专长'}}<textarea v-model="app.profile.description" maxlength="512" rows="4"/></label>
<label>证明材料<input type="file" accept="image/png,image/jpeg,application/pdf" :disabled="busy||app.profile.evidenceIds.length>=8" @change="upload"/><small>{{kind==='temple'?'请提供机构登记证明、经办人身份证明及管理授权。':'请提供本人身份证明及从业资质证明。'}}支持 PDF、PNG、JPEG，每份不超过 5MB，最多 8 份；仅本人及平台审核人员可访问。</small></label>
</fieldset>
<div v-for="(id,i) in app.profile.evidenceIds" :key="id" class="work-actions"><button type="button" @click="download(id)">查看材料 {{Number(i)+1}}</button><button v-if="editable" type="button" :disabled="busy" @click="app.profile.evidenceIds.splice(i,1)">移除</button></div>
<div v-if="editable" class="work-actions"><button type="button" :disabled="busy" @click="save(false)">保存草稿</button><button type="submit" :disabled="busy">{{busy?'正在处理…':'提交审核'}}</button></div>
</form><details v-if="history.length"><summary>申请记录</summary><p v-for="(event,i) in history" :key="i">{{event.at}} · {{({save:'保存草稿',submit:'提交审核',approved:'审核通过',rejected:'退回补充'} as Record<string,string>)[event.action]}} {{event.note}}</p></details></template>
<div class="work-actions"><button type="button" :disabled="busy" @click="load">刷新进度</button><button type="button" :disabled="busy" @click="emit('exit')">退出并返回登录</button></div>
</section></template>
<style scoped>.work-application{max-width:720px;margin:24px auto;padding:24px;color:var(--admin-text,#24443d);background:var(--admin-surface,#fffdf8);border:1px solid var(--admin-border,#deded6);border-radius:16px}.work-application header p,.work-application small{color:var(--admin-text-secondary,#66736d);line-height:1.7}.work-application h1{font-size:24px}.work-application fieldset{border:0;padding:0;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}.work-application label{display:grid;gap:8px;font-size:14px}.work-application input,.work-application select,.work-application textarea{width:100%;min-width:0;box-sizing:border-box;padding:11px;font:inherit;color:inherit;background:var(--admin-bg,#f8f7f2);border:1px solid var(--admin-border,#ccc);border-radius:8px}.work-application label:has(textarea),.work-application label:has([type=file]){grid-column:1/-1}.work-actions{display:flex;flex-wrap:wrap;gap:12px;margin-top:16px}.work-application button{min-height:44px;padding:8px 16px;border:1px solid var(--admin-border,#ccc);border-radius:8px;color:inherit;background:var(--admin-bg,#f8f7f2);cursor:pointer}.work-application button[type=submit]{background:var(--admin-primary,#28574c);color:#fff}.work-application :disabled{opacity:.6;cursor:default}.work-application :focus-visible{outline:2px solid var(--admin-primary,#28574c);outline-offset:3px}.work-application [role=alert]{color:#b53d32}.review-note{padding:14px;border-left:3px solid #a87a3b;background:var(--admin-bg,#f8f7f2)}@media(max-width:540px){.work-application{margin:12px;padding:20px}.work-application fieldset{grid-template-columns:1fr}}</style>
