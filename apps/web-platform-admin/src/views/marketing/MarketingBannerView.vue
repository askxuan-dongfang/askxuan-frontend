<template>
  <div class="dfx-page">
    <PageHeader :title='$t("首页活动与广告")' :subtitle='$t("先保存草稿，预览确认后上架；按北京时间投放，首页自动隐藏过期内容。")'>
      <template #actions><el-button type="primary" :icon="Plus" @click="openCreate">{{ $t("新增广告") }}</el-button><el-button :icon="Refresh" @click="loadData">{{ $t("刷新") }}</el-button></template>
    </PageHeader>
    <div class="dfx-card filter-bar">
      <el-select v-model="query.status" :placeholder='$t("全部发布状态")' clearable style="width:160px" @change="search">
        <el-option :label='$t("草稿")' value="draft"/><el-option :label='$t("已上架")' value="enabled"/><el-option :label='$t("已下架")' value="disabled"/>
      </el-select>
      <span class="muted">{{ $t("展示位置：信众首页 · 数字越小越靠前") }}</span>
    </div>
    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column :label='$t("内容")' min-width="260"><template #default="{row}"><div class="banner-cell">
          <el-image :src="row.imageUrl" fit="cover" class="banner-cell__img"><template #error><span class="muted">{{ $t("图片待完善") }}</span></template></el-image>
          <div><strong>{{$t(row.title)}}</strong><div class="muted">{{ $t("信众首页 · 排序 ") }}{{$t(row.sort)}}</div></div>
        </div></template></el-table-column>
        <el-table-column :label='$t("跳转目标")' min-width="170"><template #default="{row}">{{$t(targetLabel(row.linkType))}}<div class="muted">{{$t((promotionHref(row) || $t('待配置有效目标')))}}</div></template></el-table-column>
        <el-table-column :label='$t("投放时间（北京）")' min-width="215"><template #default="{row}"><div>{{$t((row.startTime || $t('上架后立即开始')))}}</div><div class="muted">{{ $t("至 ") }}{{$t((row.endTime || $t('长期展示')))}}</div></template></el-table-column>
        <el-table-column :label='$t("状态")' width="110"><template #default="{row}"><el-tag :type="row.status==='enabled'?'success':row.status==='draft'?'info':'warning'">{{$t(promotionPhase(row))}}</el-tag></template></el-table-column>
        <el-table-column :label='$t("操作")' min-width="220" fixed="right"><template #default="{row}">
          <el-button link type="primary" @click="openEdit(row)">{{ $t("编辑") }}</el-button>
          <el-button link type="primary" @click="openPreview(row)">{{$t((row.status==='enabled' ? $t('预览') : $t('预览并上架')))}}</el-button>
          <el-button v-if="row.status==='enabled'" link type="warning" :loading="busyId===row.id" @click="takeOffline(row)">{{ $t("下架") }}</el-button>
        </template></el-table-column>
      </DataTable>
    </div>
    <el-dialog v-model="dialog.visible" :title="$t((dialog.id ? $t('编辑广告') : $t('新增广告')))" width="min(620px, calc(100vw - 32px))" :close-on-click-modal="!saving" append-to-body>
      <el-alert v-if="dialog.wasPublished" :title='$t("保存修改后将转为草稿，预览并重新上架后展示。")' type="info" :closable="false" style="margin-bottom:18px"/>
      <el-form label-position="top" :disabled="saving">
        <el-form-item :label='$t("标题")' required><el-input v-model="form.title" maxlength="64" show-word-limit :placeholder='$t("本次推荐的内容标题")'/></el-form-item>
        <el-form-item :label='$t("展示位置")'><el-select v-model="form.placement" style="width:100%"><el-option :label='$t("信众首页")' value="customer_home"/></el-select></el-form-item>
        <el-form-item :label='$t("海报图片")'><ImageUploader v-model="form.imageUrl"/><div class="muted">{{ $t("建议横图，文字集中在主体区域；上架前需要可正常加载的图片，底部留出轮播指示点的位置。") }}</div></el-form-item>
        <el-form-item :label='$t("跳转内容")'><el-select v-model="form.linkType" style="width:100%" @change="form.linkValue=''">
          <el-option v-for="target in promotionTargets" :key="target.value" :value="target.value" :label="$t(target.label)"/>
        </el-select></el-form-item>
        <el-form-item v-if="!['ai','diy'].includes(form.linkType)" :label='$t("跳转目标")'><el-input v-model="form.linkValue" :placeholder="$t(promotionTargets.find(t=>t.value===form.linkType)?.placeholder)" maxlength="255"/><div v-if="form.linkType==='web'" class="muted">{{ $t("填写完整 HTTPS 网址，点击海报将在新窗口打开，并显示外部网页提示。") }}</div></el-form-item>
        <el-form-item :label='$t("排序")'><el-input-number v-model="form.sort" :min="0" :max="99999" :precision="0"/></el-form-item>
        <div class="time-fields">
          <el-form-item :label='$t("开始时间（北京时间，可不填）")'><el-date-picker v-model="form.startTime" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" :placeholder='$t("上架后立即开始")' style="width:100%"/></el-form-item>
          <el-form-item :label='$t("结束时间（北京时间，可不填）")'><el-date-picker v-model="form.endTime" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" :placeholder='$t("长期展示")' style="width:100%"/></el-form-item>
        </div>
      </el-form>
      <template #footer><el-button :disabled="saving" @click="dialog.visible=false" data-quiet-action="cancel">{{ $t("取消") }}</el-button><el-button type="primary" :loading="saving" @click="saveDraft">{{ $t("保存草稿") }}</el-button></template>
    </el-dialog>
    <el-dialog v-model="previewVisible" :title='$t("首页展示预览")' width="min(640px, calc(100vw - 32px))" append-to-body>
      <template v-if="preview">
        <div class="promotion-preview"><img v-if="preview.imageUrl" :key="preview.imageUrl" :src="preview.imageUrl" :alt='$t("广告海报预览")' @load="imageReady=true" @error="imageReady=false"/><div><small>{{$t((preview.linkType==='web' ? $t('友情推荐 · 外部网页') : $t('精选推荐')))}}</small><h2>{{$t(preview.title)}}</h2><span>{{$t((preview.linkType==='web' ? $t('前往网站') : $t('查看详情')))}} ↗</span></div></div>
        <p>{{$t(targetLabel(preview.linkType))}} · {{$t((promotionHref(preview) || $t('未配置有效跳转')))}}</p>
        <p class="muted">{{$t((preview.startTime || $t('上架后立即开始')))}}{{ $t(" 至 ") }}{{$t((preview.endTime || $t('长期展示')))}}{{ $t("（北京时间）") }}</p>
        <el-alert v-if="publishIssue" :title="$t(publishIssue)" type="warning" :closable="false"/>
        <p v-else class="muted">{{ $t("请确认海报内容、跳转目标和投放时间，再上架。") }}</p>
      </template>
      <template #footer><el-button @click="previewVisible=false">{{ $t("关闭") }}</el-button><el-button v-if="preview?.status!=='enabled'" type="primary" :disabled="!!publishIssue" :loading="saving" @click="publish">{{ $t("确认上架") }}</el-button></template>
    </el-dialog>
  </div>
</template>
<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import {computed,onMounted,reactive,ref} from 'vue'
import {Plus,Refresh} from '@element-plus/icons-vue'

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
 if(!form.title.trim()){ElMessage.warning(uiText('请填写标题'));return}
 const start=form.startTime||'',end=form.endTime||'';
 if(start&&end&&promotionTime(end,true)<=promotionTime(start)){ElMessage.warning(uiText('结束时间应晚于开始时间'));return}
 saving.value=true;
 try{const payload={...form,title:form.title.trim(),startTime:start,endTime:end};if(dialog.id)await updateBanner(dialog.id,{...payload,status:'draft'});else await createBanner(payload);dialog.visible=false;ElMessage.success(uiText('已保存草稿，预览后可上架'));await loadData()}finally{saving.value=false}
}
async function publish(){if(!preview.value||publishIssue.value||saving.value)return;saving.value=true;try{await updateBanner(preview.value.id,{status:'enabled'});previewVisible.value=false;ElMessage.success(uiText('已上架，首页按投放时间展示'));await loadData()}finally{saving.value=false}}
async function takeOffline(row:Banner){if(busyId.value)return;busyId.value=row.id;try{await updateBanner(row.id,{status:'disabled'});ElMessage.success(uiText('已下架'));await loadData()}finally{busyId.value=0}}
onMounted(loadData)
</script>
<style scoped>
.filter-bar{display:flex;align-items:center;flex-wrap:wrap;gap:16px;padding:16px;margin-bottom:16px}.table-wrap{padding:16px}.banner-cell{display:flex;align-items:center;gap:14px}.banner-cell__img{width:112px;height:64px;border-radius:8px;flex-shrink:0;background:var(--color-bg-tertiary)}.muted{color:var(--color-text-tertiary);font-size:var(--type-size-caption);line-height:1.6}.time-fields{display:grid;grid-template-columns:1fr 1fr;gap:14px}.promotion-preview{position:relative;overflow:hidden;background:#241b16;border-radius:16px;aspect-ratio:2.6;min-height:180px;color:#fff}.promotion-preview img{position:absolute;width:100%;height:100%;object-fit:cover}.promotion-preview>div{position:relative;min-height:180px;padding:24px;box-sizing:border-box;background:linear-gradient(90deg,#160f0bcc,transparent);display:flex;flex-direction:column;justify-content:center;align-items:flex-start;gap:10px}.promotion-preview h2{margin:0;font-size:26px;max-width:85%}.promotion-preview small,.promotion-preview span{color:#e4c78d}@media(max-width:600px){.time-fields{grid-template-columns:1fr}}
</style>
