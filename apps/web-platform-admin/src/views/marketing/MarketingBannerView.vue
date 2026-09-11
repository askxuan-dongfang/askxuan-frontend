<template>
  <div class="dfx-page">
    <PageHeader title="首页活动与广告" subtitle="先保存草稿，预览确认后上架；按北京时间投放，首页自动隐藏过期内容。">
      <template #actions><el-button type="primary" :icon="Plus" @click="openCreate">新增广告</el-button><el-button :icon="Refresh" @click="loadData">刷新</el-button></template>
    </PageHeader>
    <div class="dfx-card filter-bar">
      <el-select v-model="query.status" placeholder="全部发布状态" clearable style="width:160px" @change="search">
        <el-option label="草稿" value="draft"/><el-option label="已上架" value="enabled"/><el-option label="已下架" value="disabled"/>
      </el-select>
      <span class="muted">展示位置：信众首页 · 数字越小越靠前</span>
    </div>
    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="内容" min-width="260"><template #default="{row}"><div class="banner-cell">
          <el-image :src="row.imageUrl" fit="cover" class="banner-cell__img"><template #error><span class="muted">图片待完善</span></template></el-image>
          <div><strong>{{row.title}}</strong><div class="muted">信众首页 · 排序 {{row.sort}}</div></div>
        </div></template></el-table-column>
        <el-table-column label="跳转目标" min-width="170"><template #default="{row}">{{targetLabel(row.linkType)}}<div class="muted">{{promotionHref(row)||'待配置有效目标'}}</div></template></el-table-column>
        <el-table-column label="投放时间（北京）" min-width="215"><template #default="{row}"><div>{{row.startTime||'上架后立即开始'}}</div><div class="muted">至 {{row.endTime||'长期展示'}}</div></template></el-table-column>
        <el-table-column label="状态" width="110"><template #default="{row}"><el-tag :type="row.status==='enabled'?'success':row.status==='draft'?'info':'warning'">{{promotionPhase(row)}}</el-tag></template></el-table-column>
        <el-table-column label="操作" min-width="220" fixed="right"><template #default="{row}">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link type="primary" @click="openPreview(row)">{{row.status==='enabled'?'预览':'预览并上架'}}</el-button>
          <el-button v-if="row.status==='enabled'" link type="warning" :loading="busyId===row.id" @click="takeOffline(row)">下架</el-button>
        </template></el-table-column>
      </DataTable>
    </div>
    <el-dialog v-model="dialog.visible" :title="dialog.id?'编辑广告':'新增广告'" width="min(620px, calc(100vw - 32px))" :close-on-click-modal="!saving">
      <el-alert v-if="dialog.wasPublished" title="保存修改后将转为草稿，预览并重新上架后展示。" type="info" :closable="false" style="margin-bottom:18px"/>
      <el-form label-position="top" :disabled="saving">
        <el-form-item label="标题" required><el-input v-model="form.title" maxlength="64" show-word-limit placeholder="本次推荐的内容标题"/></el-form-item>
        <el-form-item label="展示位置"><el-select v-model="form.placement" style="width:100%"><el-option label="信众首页" value="customer_home"/></el-select></el-form-item>
        <el-form-item label="海报图片"><ImageUploader v-model="form.imageUrl"/><div class="muted">建议横图，文字集中在主体区域；上架前需要可正常加载的图片。</div></el-form-item>
        <el-form-item label="跳转内容"><el-select v-model="form.linkType" style="width:100%" @change="form.linkValue=''">
          <el-option v-for="target in promotionTargets" :key="target.value" :value="target.value" :label="target.label"/>
        </el-select></el-form-item>
        <el-form-item v-if="!['ai','diy'].includes(form.linkType)" label="跳转目标"><el-input v-model="form.linkValue" :placeholder="promotionTargets.find(t=>t.value===form.linkType)?.placeholder"/></el-form-item>
        <el-form-item label="排序"><el-input-number v-model="form.sort" :min="0" :max="99999" :precision="0"/></el-form-item>
        <div class="time-fields">
          <el-form-item label="开始时间（北京时间，可不填）"><el-date-picker v-model="form.startTime" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" placeholder="上架后立即开始" style="width:100%"/></el-form-item>
          <el-form-item label="结束时间（北京时间，可不填）"><el-date-picker v-model="form.endTime" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" placeholder="长期展示" style="width:100%"/></el-form-item>
        </div>
      </el-form>
      <template #footer><el-button :disabled="saving" @click="dialog.visible=false">取消</el-button><el-button type="primary" :loading="saving" @click="saveDraft">保存草稿</el-button></template>
    </el-dialog>
    <el-dialog v-model="previewVisible" title="首页展示预览" width="min(640px, calc(100vw - 32px))">
      <template v-if="preview">
        <div class="promotion-preview"><img v-if="preview.imageUrl" :key="preview.imageUrl" :src="preview.imageUrl" alt="广告海报预览" @load="imageReady=true" @error="imageReady=false"/><div><small>精选推荐</small><h2>{{preview.title}}</h2><span>查看详情 ↗</span></div></div>
        <p>{{targetLabel(preview.linkType)}} · {{promotionHref(preview)||'未配置有效跳转'}}</p>
        <p class="muted">{{preview.startTime||'上架后立即开始'}} 至 {{preview.endTime||'长期展示'}}（北京时间）</p>
        <el-alert v-if="publishIssue" :title="publishIssue" type="warning" :closable="false"/>
        <p v-else class="muted">请确认海报内容、跳转目标和投放时间，再上架。</p>
      </template>
      <template #footer><el-button @click="previewVisible=false">关闭</el-button><el-button v-if="preview?.status!=='enabled'" type="primary" :disabled="!!publishIssue" :loading="saving" @click="publish">确认上架</el-button></template>
    </el-dialog>
  </div>
</template>
<script setup lang="ts">
import {computed,onMounted,reactive,ref} from 'vue'
import {Plus,Refresh} from '@element-plus/icons-vue'
import {ElMessage} from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import ImageUploader from '@/components/ImageUploader.vue'
import {getBanners,createBanner,updateBanner} from '@/api/marketing'
import type {Banner} from '@/types'
import {promotionTargets,promotionHref,promotionImageURL,promotionPhase,promotionTime} from '../../../../../packages/domain-marketing/src'
const list=ref<Banner[]>([]),total=ref(0),loading=ref(false),saving=ref(false),busyId=ref(0)
const query=reactive({status:'',placement:'customer_home',page:1,size:20})
const empty=()=>({title:'',placement:'customer_home',imageUrl:'',linkType:'temple',linkValue:'',sort:0,startTime:'',endTime:''})
const form=reactive(empty()),dialog=reactive({visible:false,id:0,wasPublished:false})
const preview=ref<Banner|null>(null),previewVisible=ref(false),imageReady=ref(false)
const targetLabel=(value:string)=>promotionTargets.find(t=>t.value===value)?.label||'未配置'
async function loadData(){loading.value=true;try{const data=await getBanners(query);list.value=data.list||[];total.value=data.total||0}finally{loading.value=false}}
function search(){query.page=1;void loadData()}
function openCreate(){Object.assign(form,empty());Object.assign(dialog,{visible:true,id:0,wasPublished:false})}
function openEdit(row:Banner){Object.assign(form,{title:row.title,placement:row.placement||'customer_home',imageUrl:row.imageUrl,linkType:row.linkType,linkValue:row.linkValue,sort:row.sort,startTime:row.startTime,endTime:row.endTime});Object.assign(dialog,{visible:true,id:row.id,wasPublished:row.status==='enabled'})}
function openPreview(row:Banner){preview.value={...row};imageReady.value=false;previewVisible.value=true}
const publishIssue=computed(()=>{
 const b=preview.value;if(!b)return '请选择广告';
 if(!promotionImageURL(b.imageUrl)||!imageReady.value)return '海报尚未正常加载，请完善图片后上架。';
 if(!promotionHref(b))return '跳转目标无效，请编辑完善。';
 const start=promotionTime(b.startTime),end=promotionTime(b.endTime,true);
 if(Number.isNaN(start)||Number.isNaN(end)||end<=start)return '投放时间无效，请编辑调整。';
 if(end<Date.now())return '投放已结束，请调整结束时间。';return '';
})
async function saveDraft(){
 if(!form.title.trim()){ElMessage.warning('请填写标题');return}
 const start=form.startTime||'',end=form.endTime||'';
 if(start&&end&&promotionTime(end,true)<=promotionTime(start)){ElMessage.warning('结束时间应晚于开始时间');return}
 saving.value=true;
 try{const payload={...form,title:form.title.trim(),startTime:start,endTime:end};if(dialog.id)await updateBanner(dialog.id,{...payload,status:'draft'});else await createBanner(payload);dialog.visible=false;ElMessage.success('已保存草稿，预览后可上架');await loadData()}finally{saving.value=false}
}
async function publish(){if(!preview.value||publishIssue.value||saving.value)return;saving.value=true;try{await updateBanner(preview.value.id,{status:'enabled'});previewVisible.value=false;ElMessage.success('已上架，首页按投放时间展示');await loadData()}finally{saving.value=false}}
async function takeOffline(row:Banner){if(busyId.value)return;busyId.value=row.id;try{await updateBanner(row.id,{status:'disabled'});ElMessage.success('已下架');await loadData()}finally{busyId.value=0}}
onMounted(loadData)
</script>
<style scoped>
.filter-bar{display:flex;align-items:center;flex-wrap:wrap;gap:16px;padding:16px;margin-bottom:16px}.table-wrap{padding:16px}.banner-cell{display:flex;align-items:center;gap:14px}.banner-cell__img{width:112px;height:64px;border-radius:8px;flex-shrink:0;background:var(--color-bg-tertiary)}.muted{color:var(--color-text-tertiary);font-size:var(--type-size-caption);line-height:1.6}.time-fields{display:grid;grid-template-columns:1fr 1fr;gap:14px}.promotion-preview{position:relative;overflow:hidden;background:#241b16;border-radius:16px;aspect-ratio:2.6;min-height:180px;color:#fff}.promotion-preview img{position:absolute;width:100%;height:100%;object-fit:cover}.promotion-preview>div{position:relative;min-height:180px;padding:24px;box-sizing:border-box;background:linear-gradient(90deg,#160f0bcc,transparent);display:flex;flex-direction:column;justify-content:center;align-items:flex-start;gap:10px}.promotion-preview h2{margin:0;font-size:26px;max-width:85%}.promotion-preview small,.promotion-preview span{color:#e4c78d}@media(max-width:600px){.time-fields{grid-template-columns:1fr}}
</style>
