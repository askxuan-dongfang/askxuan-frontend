<script setup lang="ts">
import { ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { ref, watch, nextTick, onBeforeUnmount } from 'vue'
import * as echarts from 'echarts/core'
import { GraphChart } from 'echarts/charts'
import { TooltipComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import client from '@/api/client'
import { modelLibraryApi, modelOptions } from '@/api/modelLibrary'
import WikiEditor from './WikiEditor.vue'
import WikiMaintenance from './WikiMaintenance.vue'

echarts.use([GraphChart, TooltipComponent, CanvasRenderer])
const props = defineProps<{ baseId: string }>()
const emit = defineEmits<{changed:[]}>()
interface State { revision:number; knowledge_count:number; chunk_count:number; processing_count:number; indexing_strategy:{wiki_enabled:boolean;graph_enabled:boolean}; wiki_config?:{synthesis_model_id:string;extraction_granularity?:string;max_pages_per_ingest?:number;content_instructions?:string;extraction_instructions?:string} }
interface Page {slug:string;title:string;summary:string;content:string;page_type:string;status:string;version:number;source_refs:string[];references:{id:string;source:string;approved:boolean}[];in_links:string[];out_links:string[]}
interface Stats {total_pages:number;total_links:number;pending_tasks:number;pending_issues:number;orphan_count:number;is_active:boolean}
interface Graph {nodes:{slug:string;title:string;page_type:string}[];edges:{source:string;target:string}[];meta:{total:number;returned:number;truncated:boolean}}
const state=ref<State>(),stats=ref<Stats>(),pages=ref<Page[]>([]),detail=ref<Page>(),total=ref(0),page=ref(1),query=ref(''),busy=ref(false),error=ref(''),view=ref('pages'),graph=ref<Graph>(),canvas=ref<HTMLElement>(),drawer=ref(false)
const settings=ref(false),saving=ref(false),models=ref<{id:string;name:string}[]>([]),enabled=ref(false),model=ref('')
const granularity=ref('standard'),maxPages=ref(12),contentInstructions=ref(''),extractionInstructions=ref('')
let generation=0, detailRequest=0, chart:echarts.ECharts|undefined, observer:ResizeObserver|undefined
const typeName=(type:string)=>({concept:'概念',entity:'条目',index:'索引',summary:'摘要',synthesis:'综合',comparison:'比较'}[type]||type)
const statusName=(status:string)=>({published:'引擎已生成',draft:'草稿',archived:'已归档'}[status]||status)
const path=()=>`/ai/admin/knowledge-bases/${props.baseId}/wiki`
function dispose(){observer?.disconnect();chart?.dispose();chart=undefined}
async function refresh(reset=false){
 const id=++generation; const root=path(); busy.value=true;error.value='';detailRequest++;detail.value=undefined;drawer.value=false
 if(reset){settings.value=false;state.value=undefined;stats.value=undefined;pages.value=[];graph.value=undefined;total.value=0;page.value=1;query.value='';dispose()}
 try{
  const s=await client.get<State>(root);if(id!==generation)return;state.value=s
  if(!s.indexing_strategy.wiki_enabled){stats.value=undefined;pages.value=[];graph.value=undefined;dispose();return}
  const [a,b,c]=await Promise.all([client.get<Stats>(root+'/stats'),client.get<{pages:Page[];total:number}>(root+`/pages?page=${page.value}&query=${encodeURIComponent(query.value)}`),client.get<Graph>(root+'/graph')])
  if(id!==generation)return;stats.value=a;pages.value=b.pages||[];total.value=b.total;graph.value=c;await draw()
 }catch(e){if(id===generation)error.value=e instanceof Error?e.message:'读取知识引擎失败'}finally{if(id===generation)busy.value=false}
}
async function configure(){const kb=props.baseId;error.value='';try{const library=await modelLibraryApi.list();const m=modelOptions(library,'document');if(kb!==props.baseId)return;models.value=m;enabled.value=!!state.value?.indexing_strategy.wiki_enabled;model.value=state.value?.wiki_config?.synthesis_model_id||library.uses.document||'';const cfg=state.value?.wiki_config;granularity.value=cfg?.extraction_granularity||'standard';maxPages.value=cfg?.max_pages_per_ingest??12;contentInstructions.value=cfg?.content_instructions||'';extractionInstructions.value=cfg?.extraction_instructions||'';settings.value=true}catch(e){error.value=e instanceof Error?e.message:'读取模型失败'}}
async function save(){const kb=props.baseId;const root=path();const revision=state.value?.revision;if(!revision)return
 try{await ElMessageBox.confirm((enabled.value ? uiText('启用后，新上传或重解析的文档会调用所选模型生成 Wiki，产生模型用量。已有文档请按需重解析并重新审核。') : uiText('关闭后不再生成 Wiki，已审核原文检索不受影响。')),uiText('保存 Wiki 配置'),{confirmButtonText:uiText('保存'),cancelButtonText:uiText('取消')})}catch{return}
 if(kb!==props.baseId)return;saving.value=true;error.value='';try{await client.put(root,{enabled:enabled.value,model:model.value,revision,extraction_granularity:granularity.value,max_pages_per_ingest:maxPages.value,content_instructions:contentInstructions.value,extraction_instructions:extractionInstructions.value},{timeout:60000});if(kb===props.baseId){settings.value=false;await refresh();emit('changed')}}catch(e){if(kb===props.baseId)error.value=e instanceof Error?e.message:'保存失败，请刷新重试'}finally{saving.value=false}}
async function open(slug:string){const id=++detailRequest;const kb=props.baseId;detail.value=undefined;drawer.value=true;error.value='';try{const p=await client.get<Page>(path()+'/page?slug='+encodeURIComponent(slug));if(id===detailRequest&&kb===props.baseId)detail.value=p}catch(e){if(id===detailRequest)error.value=e instanceof Error?e.message:'读取条目失败'}}
async function draw(){await nextTick();dispose();if(view.value!=='graph'||!canvas.value||!graph.value?.nodes.length)return
 chart=echarts.init(canvas.value);const nodes=graph.value.nodes
 chart.setOption({animation:false,tooltip:{renderMode:'richText'},series:[{type:'graph',layout:'force',roam:true,draggable:true,force:{repulsion:180,edgeLength:90},data:nodes.map(n=>({id:n.slug,name:n.title,value:n.page_type,symbolSize:20})),links:graph.value.edges,lineStyle:{opacity:.25,color:'#81948f'},itemStyle:{color:'#426d60'},label:{show:nodes.length<35,position:'bottom',fontSize:11},emphasis:{focus:'adjacency',label:{show:true}},edgeSymbol:['none','arrow'],edgeSymbolSize:5}]})
 chart.on('click',(event)=>{const d=event.data as {id?:string};if(event.dataType==='node'&&d.id)void open(d.id)})
 observer=new ResizeObserver(()=>chart?.resize());observer.observe(canvas.value)
}
watch(()=>props.baseId,()=>{void refresh(true)},{immediate:true});watch(view,()=>{void draw()})
onBeforeUnmount(()=>{generation++;detailRequest++;dispose()})
</script>
<template>
 <section class="wiki" v-loading="busy">
  <header><div><h3>{{ $t("Wiki 与知识关系") }}</h3><p>{{ $t("从文档提炼条目、连接概念，再回到原文核对。生成内容需人工审校。") }}</p></div><div><el-button :disabled="!state||saving" @click="configure">{{ $t("Wiki 设置") }}</el-button><el-button @click="refresh()">{{ $t("刷新状态") }}</el-button></div></header>
  <el-alert v-if="error" :title="$t(error)" type="error" :closable="false" />
  <div v-if="state" class="metrics"><article><strong>{{$t(state.knowledge_count)}}</strong><span>{{ $t("原始文档") }}</span></article><article><strong>{{$t(state.processing_count)}}</strong><span>{{ $t("解析任务") }}</span></article><article><strong>{{$t((stats?.total_pages ?? '—'))}}</strong><span>{{ $t("Wiki 条目") }}</span></article><article><strong>{{$t((stats?.total_links ?? '—'))}}</strong><span>{{ $t("条目连接") }}</span></article></div>
  <el-alert v-if="state&&!state.indexing_strategy.wiki_enabled" :title='$t("当前知识库尚未启用 Wiki 生成")' :description='$t("文档解析与 Harness 检索仍可使用。在 Wiki 设置中选择已配置模型并启用后，这里会显示真实条目、来源与关系。")' type="info" :closable="false" />
  <template v-if="state?.indexing_strategy.wiki_enabled">
   <p class="status">{{$t((stats?.is_active ? $t('引擎正在生成') : ((stats?.pending_tasks??0)>0 ? $t('等待生成') : $t('生成队列当前空闲'))))}}{{ $t(" · 待处理 ") }}{{$t((stats?.pending_tasks ?? '—'))}}{{ $t(" · 待处理问题 ") }}{{$t((stats?.pending_issues ?? '—'))}}{{ $t(" · 孤立条目 ") }}{{$t((stats?.orphan_count ?? '—'))}}</p>
   <el-radio-group v-model="view" :aria-label='$t("Wiki 视图")'><el-radio-button value="pages">{{ $t("条目与出处") }}</el-radio-button><el-radio-button value="graph">{{ $t("关系图") }}</el-radio-button><el-radio-button value="quality">{{ $t("质量检查") }}</el-radio-button></el-radio-group>
   <WikiMaintenance v-if="view==='quality'" :base-id="baseId"/><template v-if="view==='pages'"><WikiEditor :base-id="baseId" @changed="refresh()"/><el-form class="search" @submit.prevent="page=1;refresh()"><el-input v-model="query" :placeholder='$t("搜索条目标题与内容")' :aria-label='$t("Wiki 搜索")' maxlength="200" clearable/><el-button native-type="submit">{{ $t("搜索") }}</el-button></el-form>
   <el-table :data="pages" :empty-text='$t("还没有条目；请等待生成，或检查模型与处理队列")' @row-click="(row:Page)=>open(row.slug)"><el-table-column :label='$t("条目")' min-width="200"><template #default="{row}"><el-button link type="primary" @click.stop="open(row.slug)">{{$t(row.title)}}</el-button><p class="summary">{{$t(row.summary)}}</p></template></el-table-column><el-table-column :label='$t("类型")' width="90"><template #default="{row}">{{$t(typeName(row.page_type))}}</template></el-table-column><el-table-column :label='$t("生成状态")' width="110"><template #default="{row}">{{$t(statusName(row.status))}}</template></el-table-column><el-table-column prop="version" :label='$t("版本")' width="80"/></el-table>
   <el-pagination v-if="total>20" v-model:current-page="page" :total="total" :page-size="20" layout="prev,pager,next,total" @current-change="refresh()"/></template>
   <template v-if="view==='graph'"><p>{{ $t("连线表示 Wiki 条目引用关系。拖动、缩放查看，点击节点阅读原文出处；也可切换条目列表。") }}</p><p v-if="graph?.meta.truncated">{{ $t("显示 ") }}{{$t(graph.meta.returned)}} / {{$t(graph.meta.total)}}{{ $t(" 个节点，较大知识库请使用条目搜索。") }}</p><div v-if="graph?.nodes.length" ref="canvas" class="graph" role="img" :aria-label='$t("可拖动的 Wiki 条目关系图；完整可访问入口见条目列表")'/><el-empty v-else :description='$t("尚未生成可展示的关系")'/></template>
  </template>
  <footer><strong>{{ $t("实体知识图谱") }}</strong><p>{{$t((state?.indexing_strategy.graph_enabled ? $t('此库已开启实体抽取配置；Neo4j 服务可用性和抽取结果须另行验证。') : $t('此库未开启 Neo4j 实体抽取。当前关系图是 Wiki 条目之间的引用，不能作为专业算法或事实推理的证明。')))}}</p><p>{{ $t("Harness 继续检索已审核原文，并保留出处。Wiki 展示不等于自动放行生成内容。") }}</p></footer>
  <el-dialog v-model="settings" :title='$t("Wiki 生成设置")' width="min(540px,94vw)" append-to-body><el-form label-position="top"><el-form-item :label='$t("启用 Wiki 生成")'><el-switch v-model="enabled"/></el-form-item><el-form-item :label='$t("已配置的生成模型")'><el-select v-model="model" filterable :aria-label='$t("Wiki 生成模型")' :disabled="!enabled" :placeholder='$t("选择模型")'><el-option v-for="m in models" :key="m.id" :value="m.id" :label="$t(m.name)"/></el-select></el-form-item><el-form-item :label='$t("概念抽取粒度")'><el-select v-model="granularity" :disabled="!enabled"><el-option value="focused" :label='$t("精简：文档主要主题")'/><el-option value="standard" :label='$t("标准：主要主题与有实质论述的概念")'/><el-option value="exhaustive" :label='$t("细致：包含顺带提及的概念（需更多审校）")'/></el-select></el-form-item><el-form-item :label='$t("每份文档最多生成条目（1–32）")'><el-input-number v-model="maxPages" :min="1" :max="32" :precision="0" :disabled="!enabled"/></el-form-item><el-form-item :label='$t("条目编写要求")'><el-input v-model="contentInstructions" type="textarea" :rows="5" maxlength="4000" show-word-limit :disabled="!enabled" :placeholder='$t("定义、出处、不同版本、方法表格、适用边界与关联条目")'/></el-form-item><el-form-item :label='$t("抽取范围与重点")'><el-input v-model="extractionInstructions" type="textarea" :rows="4" maxlength="4000" show-word-limit :disabled="!enabled" :placeholder='$t("指定本专题的术语、文献、流派和原文明确记载的关系")'/></el-form-item></el-form><p>{{ $t("标准粒度适合专题知识库；细致粒度可能增加碎片条目和模型用量。保存不会重建历史条目，仅影响新上传或重解析的文档。已有文档应分批重解析并重新审核，生成结果需核对出处。") }}</p><el-alert v-if="!models.length" :title='$t("尚无可用的生成模型，请先到模型库添加大模型")' type="warning" :closable="false"/><el-alert v-if="error" :title="$t(error)" type="error" :closable="false"/><template #footer><el-button @click="settings=false">{{ $t("取消") }}</el-button><el-button type="primary" :loading="saving" :disabled="enabled&&(!model||!maxPages||maxPages<1||maxPages>32)" @click="save">{{ $t("保存") }}</el-button></template></el-dialog>
  <el-drawer v-model="drawer" :title="$t((detail?.title || $t('读取条目')))" size="min(780px,94vw)" append-to-body><template v-if="detail"><p>{{$t(typeName(detail.page_type))}} · {{$t(statusName(detail.status))}}{{ $t(" · 版本 ") }}{{$t(detail.version)}}</p><WikiEditor :base-id="baseId" :slug="detail.slug" @changed="open(detail.slug)"/><pre class="content">{{detail.content}}</pre><h4>{{ $t("原文来源") }}</h4><ul><li v-for="source in detail.references" :key="source.id"><el-tag :type="source.approved?'success':'warning'">{{$t((source.approved ? $t('已审核原文') : $t('原文未启用')))}}</el-tag> {{$t(source.source)}}</li></ul><p v-if="!detail.references?.length">{{ $t("未找到可核对的登记原文，需人工补充或检查源文档是否已删除。") }}</p><h4>{{ $t("关联条目") }}</h4><el-button v-for="slug in detail.out_links" :key="slug" link type="primary" @click="open(slug)">{{$t(slug)}}</el-button></template><el-alert v-else-if="error" :title="$t(error)" type="error" :closable="false"/><el-skeleton v-else :rows="8" animated/></el-drawer>
 </section>
</template>
<style scoped>
.wiki{margin:24px 0}.wiki header{display:flex;justify-content:space-between;align-items:flex-start;gap:16px}.wiki h3{margin:0}.wiki p,.wiki span{font-size:13px;color:var(--el-text-color-secondary);line-height:1.65}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:20px 0}.metrics article{background:var(--el-fill-color-light);border-radius:12px;padding:16px}.metrics strong,.metrics span{display:block}.metrics strong{font-size:24px}.search{display:flex;gap:12px;margin:18px 0}.summary{margin:4px 0;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}.graph{height:470px;border:1px solid var(--el-border-color);border-radius:12px}.content{font:inherit;white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.85}.wiki footer{border-top:1px solid var(--el-border-color);margin-top:24px;padding-top:18px}.wiki li{overflow-wrap:anywhere;line-height:1.7}.el-pagination{margin-top:20px}@media(max-width:900px){.metrics{grid-template-columns:repeat(2,1fr)}.graph{height:350px}}
</style>
