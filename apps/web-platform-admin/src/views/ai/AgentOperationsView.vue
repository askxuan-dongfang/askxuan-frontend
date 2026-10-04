<script setup lang="ts">
import client from '@/api/client'
import { computed, onMounted, onBeforeUnmount, reactive, ref, watch } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Setting, Connection, VideoPlay, List, Clock, Refresh, Check, ArrowRight, Plus, Delete, Search } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import KnowledgeLibrary from './KnowledgeLibrary.vue'
import KnowledgeModels from './KnowledgeModels.vue'
import { agentOperationsApi as api, type AgentWorkspace, type AgentConfig, type DebugRun, type ProductionRun, type ToolTrace, type EvaluationRun, type EvaluationCase } from '@/api/agentOperations'

import { addCapability, changeCapability, capabilityKind } from './agentCapabilities'

const workspace = ref<AgentWorkspace>(), loading = ref(true), busy = ref(false), loadError = ref('')
const form = ref<AgentConfig>(), baseline = ref(''), tab = ref('config'), selectedSkill = ref('')
const models = ref<{ id: string; name: string }[]>([])
const knowledgeBases=ref<{id:string;name:string;enabled:boolean}[]>([])
async function loadKnowledgeBases(){try{const v=await client.get<{list:typeof knowledgeBases.value}>("/ai/admin/knowledge-bases");knowledgeBases.value=v.list||[]}catch{knowledgeBases.value=[]}}
const workspaceGroups = [{ id:'capabilities',name:'知识与能力',tabs:['models','knowledge','skills'] },{ id:'development',name:'智能体开发',tabs:['config'] },{ id:'release',name:'调试与发布',tabs:['debug','evaluation','runs','versions'] }]
const currentGroup = computed(()=>workspaceGroups.find(g=>g.tabs.includes(tab.value))!)
const engineModels=ref<{id:string;name:string;type:string}[]>([])
async function loadEngineModels(){try{engineModels.value=(await client.get<{list:typeof engineModels.value}>("/ai/admin/knowledge-models")).list||[]}catch{engineModels.value=[]}}
const sections = [{id:'models',name:'模型与连接',icon:Setting},{id:'knowledge',name:'知识库',icon:Connection},{ id: 'config', name: '智能体配置', icon: Setting }, { id: 'skills', name: '技能与工具', icon: Connection }, { id: 'debug', name: '调试工作台', icon: VideoPlay }, { id: 'evaluation', name: '质量评测', icon: Check }, { id: 'runs', name: '运行记录', icon: List }, { id: 'versions', name: '版本发布', icon: Clock }]
const dirty = computed(() => JSON.stringify(form.value) !== baseline.value || Object.keys(caseErrors).length > 0)
const selectedPolicy = computed(() => form.value?.skills.find(s => s.code === selectedSkill.value))
const selectedInfo = computed(() => workspace.value?.catalog.find(s => s.code === selectedSkill.value))
const enabledSkills = computed(() => form.value?.skills.filter(s => s.enabled) || [])
const missingSkills = computed(() => workspace.value?.catalog.filter(s => !form.value?.skills.some(p => p.code === s.code)) || [])
const capabilityPicker = ref(false), capabilitySearch = ref(''), capabilityFilter = ref('all')
const kindLabel = (info?: AgentWorkspace['catalog'][number]) => ({ mcp: 'MCP 工具', builtin: '内置工具', skill: '业务技能' }[capabilityKind(info)])
const availableCapabilities = computed(() => missingSkills.value.filter(s =>
  (capabilityFilter.value === 'all' || capabilityKind(s) === capabilityFilter.value) &&
  `${s.name} ${s.code} ${s.description} ${s.toolServer || ''}`.toLowerCase().includes(capabilitySearch.value.trim().toLowerCase())))
function addSkill(info: AgentWorkspace['catalog'][number]) {
  if (!form.value || busy.value || !addCapability(form.value, info)) return
  selectedSkill.value = info.code
  ElMessage.success(`${info.name}已加入草稿`)
}
async function changeSkill(code: string, action: 'remove' | 'disable' | 'enable') {
  if (!form.value || busy.value || (code === 'general' && action !== 'enable')) return
  const info = workspace.value?.catalog.find(s => s.code === code)
  if (action === 'enable' && info?.sourceStatus === 'disabled') { ElMessage.warning('源技能已停用，当前无法启用'); return }
  const related = form.value.evaluation.filter(c => c.skillCode === code)
  if (action === 'remove' || (action === 'disable' && related.length)) {
    const verb = action === 'remove' ? '移除' : '停用'
    try { await ElMessageBox.confirm(`${verb}“${skillName(code)}”${related.length ? `会同时移除草稿中关联的 ${related.length} 条评测用例` : '只修改当前草稿'}。${action === 'remove' ? '之后可从能力库重新添加；源技能和历史记录保留。' : '技能配置保留，之后可以重新启用。'}发布后才会影响用户端。`, `${verb}能力`, { confirmButtonText: verb, cancelButtonText: '取消', type: 'warning' }) } catch { return }
  }
  if (!form.value || !changeCapability(form.value, code, action)) return
  for (const c of related) if (action !== 'enable') { delete caseInputs[c.id]; delete caseErrors[c.id] }
  if (!form.value.skills.some(s => s.code === selectedSkill.value)) selectedSkill.value = form.value.skills[0]?.code || ''
  if (!form.value.skills.some(s => s.code === debug.skillCode && s.enabled)) debug.skillCode = form.value.skills.find(s => s.enabled)?.code || ''
}
const skillName = (code: string) => workspace.value?.catalog.find(s => s.code === code)?.name || code
const statuses: Record<string, string> = { passed: '已通过', running: '执行中', completed: '已完成', failed: '失败', awaiting_input: '待补充资料', expired: '已过期', cancelled: '已结束' }
const statusText = (s: string) => statuses[s] || s
const timeText = (s: string) => s ? new Date(s.includes('T') ? s : s.replace(' ', 'T')).toLocaleString() : '—'

async function load(preserve = false) {
  if (!preserve) loading.value = true
  loadError.value = ''
  try {
    const value = await api.workspace()
    if (preserve && dirty.value) {
      if (workspace.value?.revision !== value.revision) { loadError.value = '后台配置已变化，请复制保留未保存内容，再重新加载，避免覆盖其他修改'; return }
      workspace.value = value; return
    }
    Object.keys(caseInputs).forEach(k => delete caseInputs[k]); Object.keys(caseErrors).forEach(k => delete caseErrors[k]); workspace.value = value; form.value = structuredClone(value.draft); form.value.evaluation ||= []; form.value.retrieval ||= {candidateCount:12,resultCount:5,rerankModel:'',rerankRequired:false,graphEnabled:false}; form.value.retrieval.candidateCount ||= 12; form.value.retrieval.resultCount ||= 5; baseline.value = JSON.stringify(form.value)
    if (!value.draft.skills.some(s => s.code === selectedSkill.value)) selectedSkill.value = value.draft.skills[0]?.code || ''
    if (!debug.skillCode || !value.draft.skills.some(s => s.code === debug.skillCode && s.enabled)) debug.skillCode = value.draft.skills.find(s => s.enabled)?.code || ''
  } catch { loadError.value = '智能体管理加载失败，请重试；首次接入需要完成数据库迁移。' }
  finally { loading.value = false }
}
async function reload() {
  if (dirty.value) { try { await ElMessageBox.confirm('重新加载将丢弃尚未保存的修改。', '重新加载', { confirmButtonText: '重新加载', cancelButtonText: '继续编辑' }) } catch { return } }
  await load()
}
async function save() {
  if (!workspace.value || !form.value) return
  if (Object.keys(caseErrors).length) { ElMessage.warning("请先修正评测资料格式"); return }
  busy.value = true
  try { await api.save(workspace.value.revision, JSON.parse(JSON.stringify(form.value))); await load(); ElMessage.success('草稿已保存，请运行评测集后发布') }
  catch { /* keep editable draft on conflict or validation failure */ } finally { busy.value = false }
}
async function publish() {
  if (!workspace.value || dirty.value || !workspace.value.tested) return
  let note: string
  try { const value = await ElMessageBox.prompt('生成固定版本，初始发布比例为 0%。请在版本页逐步扩大范围；原稳定版本继续服务。', '发布智能体配置', { inputPlaceholder: '说明本次调整内容', inputValidator: value => Boolean(value?.trim()) && value.length <= 500 || '请填写 1 至 500 字说明', confirmButtonText: '确认发布', cancelButtonText: '取消' }); note = value.value } catch { return }
  busy.value = true
  try { await api.publish(workspace.value.revision, note); await load(); ElMessage.success('版本已发布') } catch { /* retain state */ } finally { busy.value = false }
}
async function rollback(version: number) {
  if (!workspace.value) return
  let note: string
  try { const value = await ElMessageBox.prompt(`新请求将使用${version ? `版本 v${version}` : '原始问事配置'}，当前草稿保持不变。`, '回滚配置', { inputPlaceholder: '填写回滚原因', inputValidator: value => Boolean(value?.trim()) && value.length <= 500 || '请填写 1 至 500 字原因', confirmButtonText: '确认回滚', cancelButtonText: '取消' }); note = value.value } catch { return }
  busy.value = true
  try { await api.rollback(workspace.value.revision, version, note); await load(true); ElMessage.success('已回滚') } catch { /* client displays error */ } finally { busy.value = false }
}


const evaluations = ref<EvaluationRun[]>([]), evaluation = ref<EvaluationRun>(), evalBusy = ref(false), evalError = ref('')
const caseInputs = reactive<Record<string, string>>({}), caseErrors = reactive<Record<string, string>>({})
let evalTimer: ReturnType<typeof setTimeout> | undefined
function addCase() {
  if (!form.value || form.value.evaluation.length >= 100) return
  form.value.evaluation.push({ id: crypto.randomUUID(), name: '新的评测用例', skillCode: enabledSkills.value[0]?.code || '', question: '请根据合成资料提供审慎的文化与生活参考。', inputs: {}, minChars: 20, contains: [], excludes: [], expectInvalid: false })
}
function editCaseInputs(c: EvaluationCase, text: string) {
  caseInputs[c.id] = text
  try { const v = JSON.parse(text); if (!v || Array.isArray(v) || typeof v !== 'object') throw new Error(); c.inputs = v; delete caseErrors[c.id] }
  catch { caseErrors[c.id] = '请填写 JSON 对象，例如 {"birthDate":"1990-01-02"}' }
}
function removeCase(id: string) { if (form.value) form.value.evaluation = form.value.evaluation.filter(c => c.id !== id); delete caseErrors[id]; delete caseInputs[id] }
async function loadEvaluations() { try { evaluations.value = (await api.evaluations()).list; const active = evaluations.value.find(e => e.status === 'running'); if (active) { evaluation.value = active; void pollEvaluation(active.id) } } catch { evalError.value = '评测记录加载失败，请刷新重试' } }
async function pollEvaluation(id: string) {
  if (evalTimer) clearTimeout(evalTimer)
  try { const v = await api.evaluation(id); if (disposed || evaluation.value?.id !== id) return; evaluation.value = v; evalError.value = ''; if (v.status === 'running') evalTimer = setTimeout(() => { void pollEvaluation(id) }, 1500); else { await load(true); evaluations.value = (await api.evaluations()).list } }
  catch { if (!disposed) evalError.value = '评测状态获取失败；可重新获取，避免重复启动' }
}
async function startEvaluation() {
  if (!workspace.value || dirty.value || Object.keys(caseErrors).length) return
  evalBusy.value = true
  try { evaluation.value = await api.startEvaluation(workspace.value.revision); void pollEvaluation(evaluation.value.id) } catch { /* server explains missing coverage */ } finally { evalBusy.value = false }
}
async function setRollout(percentage: number) {
  if (!workspace.value) return
  let note: string
  try { const result = await ElMessageBox.prompt(`候选版本 v${workspace.value.rollout.versionId} 将覆盖 ${percentage}% 的账号，其余继续使用稳定版本。`, '调整发布比例', { inputPlaceholder: '填写变更原因', inputValidator: v => Boolean(v?.trim()) && v.length <= 450 || '请填写 1 至 450 字原因', confirmButtonText: '应用比例', cancelButtonText: '取消' }); note = result.value } catch { return }
  busy.value = true
  try { await api.setRollout(workspace.value.rollout.revision, percentage, note); await load(true); ElMessage.success('发布比例已更新') } catch { /* retain state */ } finally { busy.value = false }
}
watch(tab, value => { if (value === 'evaluation') void loadEvaluations() })

const debug = reactive({ kind: 'classic', skillCode: '', question: '请根据这份测试资料，说明可以提供哪些有依据的参考。' })
const inputValues = reactive<Record<string, string>>({}), run = ref<DebugRun>(), debugBusy = ref(false), pollError = ref('')
const debugInfo = computed(() => workspace.value?.catalog.find(s => s.code === debug.skillCode))
const debugFields = computed(() => (debugInfo.value?.inputSchema.fields || []).filter(f => !f.visibleWhen || inputValues[f.visibleWhen.key] === f.visibleWhen.value))
const einoAvailable = computed(() => debugInfo.value?.einoSupported && form.value?.skills.find(s => s.code === debug.skillCode)?.useTool)
const inProgress = computed(() => run.value?.status === 'running')
const pending = computed(() => run.value?.status === 'awaiting_input')
let timer: ReturnType<typeof setTimeout> | undefined, pollGeneration = 0, disposed = false
watch(() => debug.skillCode, () => { Object.keys(inputValues).forEach(k => delete inputValues[k]); if (!einoAvailable.value) debug.kind = 'classic' })
function sample() {
  const values: Record<string, string> = { birthDate: '1990-01-02', birthTime: '12:30', gender: 'male', name: '测试用户', question: '合成资料验证' }
  Object.assign(values, { calendarType: 'solar', astroBirthDate: '1990-01-02', astroBirthTime: '08:30', latitude: '31.23', longitude: '121.47', transitDateTime: '2026-09-29T12:30', eventTime: '2026-09-29T12:30', targetDate: '2026-09-29', yearPillar: '己巳', monthPillar: '丙子', dayPillar: '丁卯', hourPillar: '甲辰', lunarMonth: '8', lunarDay: '19', hourIndex: '7', yongShenTarget: '父母', pairNumbers: '12 34', tripleNumbers: '12 34 56', numbers: '12 34 56', divinationText: '山水', count: '3', countCategory: 'item', measureKind: '丈尺', majorValue: '1', minorValue: '2', upperCue: '天', lowerCue: '地', hexagramName: '乾为天', movingLine: '3', toPalace: '夫妻' })
  for (const field of debugInfo.value?.inputSchema.fields || []) if (field.defaultValue) inputValues[field.key] = field.defaultValue
  for (const field of debugFields.value) if (values[field.key]) inputValues[field.key] = values[field.key]
}
function inputs() {
  const result: Record<string, unknown> = {}
  for (const field of debugFields.value) { const value = inputValues[field.key]?.trim(); if (value) result[field.key] = value }
  return result
}
function stopPoll() { if (timer) clearTimeout(timer); timer = undefined; pollGeneration++ }
async function poll(id: string, generation: number) {
  try {
    const result = await api.debug(id)
    if (disposed || generation !== pollGeneration) return
    run.value = result; pollError.value = ''
    if (result.status === 'running') timer = setTimeout(() => { void poll(id, generation) }, 1200)
    else { await load(true) }
  } catch { if (!disposed && generation === pollGeneration) pollError.value = '状态获取失败，执行可能仍在继续。请重新获取，避免重复启动。' }
}
function refreshRun() { if (!run.value) return; stopPoll(); void poll(run.value.id, pollGeneration) }
async function startDebug() {
  if (!workspace.value || dirty.value || !debug.skillCode) return
  debugBusy.value = true; pollError.value = ''; stopPoll()
  try { run.value = await api.start({ revision: workspace.value.revision, ...debug, inputs: inputs() }); void poll(run.value.id, pollGeneration) }
  catch { /* editable inputs retained */ } finally { debugBusy.value = false }
}
async function resumeDebug() {
  if (!run.value) return
  debugBusy.value = true
  try { await api.resume(run.value.id, run.value.interruptId, inputs()); run.value.status = 'running'; refreshRun() } catch { /* retain correction */ } finally { debugBusy.value = false }
}
async function cancelDebug() {
  if (!run.value) return
  debugBusy.value = true
  try { await api.cancel(run.value.id); refreshRun() } catch { /* retain current run */ } finally { debugBusy.value = false }
}

const recordKind = ref('production'), records = ref<ProductionRun[]>([]), debugRecords = ref<DebugRun[]>([]), recordsLoading = ref(false), recordsError = ref(''), page = ref(1), hasMore = ref(false), status = ref('')
let recordGeneration = 0
async function loadRecords() {
  const generation = ++recordGeneration; recordsLoading.value = true; recordsError.value = ''
  try {
    if (recordKind.value === 'production') { const value = await api.runs(page.value, status.value); if (generation === recordGeneration) { records.value = value.list; hasMore.value = value.hasMore } }
    else { const value = await api.debugList(); if (generation === recordGeneration) debugRecords.value = value.list }
  } catch { if (generation === recordGeneration) recordsError.value = '运行记录加载失败，请重试' }
  finally { if (generation === recordGeneration) recordsLoading.value = false }
}
watch([tab, recordKind, page, status], () => { if (tab.value === 'runs') void loadRecords() })
function changeStatus() { page.value = 1 }
const versionDialog = ref(false), versionConfig = ref<AgentConfig>(), versionNumber = ref(0)
async function showVersion(id: number) {
  busy.value = true
  try { const value = await api.version(id); versionConfig.value = value.config; versionNumber.value = id; versionDialog.value = true } catch { /* no stale version shown */ } finally { busy.value = false }
}
const drawer = ref(false), tools = ref<ToolTrace[]>([]), toolsLoading = ref(false), toolsError = ref(''), detailRun = ref<ProductionRun>()
async function showTools(row: ProductionRun) {
  detailRun.value = row; tools.value = []; toolsError.value = ''; drawer.value = true; toolsLoading.value = true
  try { const value = await api.tools(row.id); if (detailRun.value?.id === row.id) tools.value = value.list }
  catch { toolsError.value = '工具轨迹加载失败' } finally { toolsLoading.value = false }
}
function showDebug(row: DebugRun) { stopPoll(); run.value = row; debug.skillCode = row.skillCode; debug.kind = row.kind; tab.value = 'debug'; refreshRun() }
onBeforeRouteLeave(async () => {
  if (!dirty.value || !workspace.value) return true
  try { await ElMessageBox.confirm('当前草稿尚未保存，离开后将丢弃修改。', '离开智能体管理', { confirmButtonText: '离开', cancelButtonText: '继续编辑' }); return true } catch { return false }
})
function beforeUnload(e: BeforeUnloadEvent) { if (dirty.value && workspace.value) { e.preventDefault(); e.returnValue = '' } }
onMounted(() => { window.addEventListener('beforeunload', beforeUnload); void load(); void loadKnowledgeBases(); void api.models().then(v => { models.value = v.list }).catch(() => {}) })
onBeforeUnmount(() => { disposed = true; if (evalTimer) clearTimeout(evalTimer); stopPoll(); recordGeneration++; window.removeEventListener('beforeunload', beforeUnload) })
</script>

<template>
  <div class="dfx-page agent-ops" v-loading="loading">
    <PageHeader title="问事智能体开发中心" subtitle="管理知识与工具、编排智能体、评测并发布">
      <template #actions><el-button :icon="Refresh" :disabled="busy" @click="reload">重新加载</el-button></template>
    </PageHeader>
    <el-alert v-if="loadError" :title="loadError" type="error" :closable="false" show-icon><el-button text @click="reload">重试</el-button></el-alert>
    <template v-if="workspace && form">
      <el-alert :title="workspace.runtimeMode === 'harness' ? '用户端执行引擎：Eino Harness' : '用户端执行引擎：传统问事流程'" :description="workspace.runtimeMode === 'harness' ? '按需选择工具、读取关联报告、补问资料并继续。质量评测使用相同执行引擎；每轮最多 4 次模型调用和 4 次工具调用。' : '当前用户请求尚未通过 Harness 执行。'" type="info" :closable="false" />
      <section class="ops-overview" aria-label="发布状态">
        <div class="ops-identity"><span class="ops-symbol"><Connection /></span><div><strong>{{ workspace.active?.name || '问事助手' }}</strong><p>{{ workspace.liveEnabled ? (workspace.activeVersion ? `候选 v${workspace.activeVersion} · 覆盖 ${workspace.rollout.percentage}%` : '使用原始问事配置') : '运营配置尚未接管线上问事' }}</p></div></div>
        <div class="ops-stat"><span>草稿</span><strong>r{{ workspace.revision }}</strong></div>
        <div class="ops-stat"><span>已启用技能</span><strong>{{ enabledSkills.length }}</strong></div>
        <div class="ops-stat"><span>发布检查</span><strong :class="{ ready: workspace.tested && !dirty }">{{ dirty ? '有未保存修改' : workspace.tested ? '评测已通过' : '待评测' }}</strong></div>
      </section>
      <nav class="ops-workspaces" aria-label="工作区"><button v-for="group in workspaceGroups" :key="group.id" :aria-current="currentGroup.id === group.id ? 'page' : undefined" @click="tab = group.tabs[0]">{{ group.name }}</button></nav>
      <nav class="ops-tabs" aria-label="智能体管理模块"><button v-for="item in sections.filter(item=>currentGroup.tabs.includes(item.id))" :key="item.id" type="button" :aria-current="tab === item.id ? 'page' : undefined" :class="{ active: tab === item.id }" @click="tab = item.id"><el-icon><component :is="item.icon" /></el-icon>{{ item.name }}</button></nav>

      <KnowledgeModels v-if="tab === 'models'"/>
      <KnowledgeLibrary v-if="tab === 'knowledge'"/>
      <section v-show="tab === 'config'" class="ops-card">
        <div class="ops-section-head"><div><h2>定义问事助手</h2><p>职责与技能共同决定回答方式。保存草稿不会立即改变用户端。</p></div><router-link to="/settings/ai">模型连接设置 <el-icon><ArrowRight /></el-icon></router-link></div>
        <el-form label-position="top" :disabled="busy" @submit.prevent="save">
          <div class="ops-grid"><el-form-item label="名称"><el-input v-model="form.name" maxlength="40" aria-label="智能体名称" /></el-form-item><el-form-item label="默认模型"><el-select v-model="form.model" filterable aria-label="智能体默认模型" placeholder="沿用模型设置中的默认值" clearable><el-option v-if="form.model && !models.some(m => m.id === form?.model)" :value="form.model" :label="form.model" /><el-option v-for="m in models" :key="m.id" :value="m.id" :label="m.name" /></el-select><span class="ops-hint">用于未主动选择模型的文字问事。</span></el-form-item></div>
          <el-form-item label="职责与回答要求"><el-input v-model="form.instruction" type="textarea" :rows="6" maxlength="2500" show-word-limit aria-label="职责与回答要求" /></el-form-item>
          <el-form-item label="绑定知识库"><el-select v-model="form.knowledgeBaseIds" multiple placeholder="选择已审核知识库（不选则不检索）" @visible-change="loadKnowledgeBases" style="width:100%"><el-option v-for="b in knowledgeBases" :key="b.id" :label="b.name+(b.enabled?'':'（停用）')" :value="b.id" :disabled="!b.enabled"/></el-select><p class="ops-hint">知识库范围随智能体版本发布；模型不能自行扩大权限。</p></el-form-item><el-form-item label="知识与记忆"><el-switch v-model="form.knowledgeEnabled" active-text="允许检索已审核知识"/><el-switch v-model="form.memoryEnabled" active-text="允许读取用户明确保存的记忆" style="margin-left:24px"/><p class="ops-hint">随智能体版本评测和发布生效。停用不会删除资料；用户可逐条停用或删除自己的记忆。</p></el-form-item>
          <template v-if="form.retrieval"><el-divider content-position="left">Harness 检索策略</el-divider><div class="ops-grid"><el-form-item label="候选片段数量"><el-input-number v-model="form.retrieval.candidateCount" :min="5" :max="40"/></el-form-item><el-form-item label="最终引用片段数量"><el-input-number v-model="form.retrieval.resultCount" :min="1" :max="Math.min(10,form.retrieval.candidateCount)"/></el-form-item></div><el-form-item label="重排模型"><el-select v-model="form.retrieval.rerankModel" clearable @change="!form.retrieval.rerankModel && (form.retrieval.rerankRequired=false)" placeholder="关闭专用重排" @visible-change="loadEngineModels"><el-option v-if="form.retrieval.rerankModel&&!engineModels.some(m=>m.id===form?.retrieval?.rerankModel)" :value="form.retrieval.rerankModel" :label="form.retrieval.rerankModel"/><el-option v-for="m in engineModels.filter(m=>m.type==='Rerank')" :key="m.id" :value="m.id" :label="m.name"/></el-select></el-form-item><el-form-item label="重排不可用时"><el-switch v-model="form.retrieval.rerankRequired" :disabled="!form.retrieval.rerankModel" active-text="严格失败，停止本次检索" inactive-text="回退混合检索并记录降级"/></el-form-item><el-form-item label="实体图谱"><el-switch v-model="form.retrieval.graphEnabled" active-text="检索已审核原文关联的实体关系"/><p class="ops-hint">必须先完成 Neo4j 抽取。资料与图谱只作为参考，不作为工具指令。策略与当前草稿一起评测、发布和回滚。</p></el-form-item></template>
          <el-form-item label="对话回答输出上限"><el-input-number v-model="form.maxOutputTokens" :min="64" :max="32768" :step="1024" aria-label="回答输出上限" /><span class="ops-hint">Token；同时受全局模型设置限制。Eino 调试最多输出 512 Token。</span></el-form-item>
        </el-form>
      </section>

      <section v-show="tab === 'skills'" class="ops-skills">
        <aside class="ops-card ops-skill-list"><h2>已添加的能力</h2><p class="ops-hint">{{ form.skills.length }} 项已添加 · {{ enabledSkills.length }} 项启用</p><el-button class="ops-add-capability" :icon="Plus" :disabled="busy || !missingSkills.length" @click="capabilityPicker = true">添加能力{{ missingSkills.length ? `（${missingSkills.length}）` : '' }}</el-button><button v-for="skill in form.skills" :key="skill.code" type="button" :class="{ selected: selectedSkill === skill.code }" :aria-pressed="selectedSkill === skill.code" @click="selectedSkill = skill.code"><span>{{ skillName(skill.code) }}</span><span class="ops-pill" :class="{ muted: !skill.enabled }">{{ skill.enabled ? '已启用' : '已停用' }}</span></button><p class="ops-hint">从能力库逐项添加。停用保留配置，移除后仍可重新添加。</p></aside>
        <div v-if="selectedPolicy && selectedInfo" class="ops-card">
          <div class="ops-section-head"><div><h2>{{ selectedInfo.name }}</h2><p>{{ selectedInfo.description }}</p></div><el-switch :model-value="selectedPolicy.enabled" @change="changeSkill(selectedPolicy!.code, $event ? 'enable' : 'disable')" :disabled="busy || selectedPolicy.code === 'general' || (!selectedPolicy.enabled && selectedInfo.sourceStatus === 'disabled')" :aria-label="`启用${selectedInfo.name}`" /></div>
          <div class="ops-capability-meta"><el-tag>{{ kindLabel(selectedInfo) }}</el-tag><span>{{ selectedInfo.version }}</span><span v-if="selectedInfo.toolServer">服务：{{ selectedInfo.toolServer }}</span></div>
          <el-alert v-if="selectedInfo.sourceStatus === 'disabled'" title="源技能已停用，请停用或移除当前草稿中的这项能力" type="warning" :closable="false" />
          <el-form label-position="top" :disabled="busy" @submit.prevent>
            <el-form-item label="技能说明与回答规则"><el-input v-model="selectedPolicy.prompt" type="textarea" :rows="9" maxlength="5000" show-word-limit aria-label="技能回答规则" /></el-form-item>
            <el-form-item label="允许此智能体调用工具"><div class="ops-tool-row"><el-switch v-model="selectedPolicy.useTool" :disabled="!selectedInfo.toolAvailable || !selectedPolicy.enabled" aria-label="使用计算工具" /><strong>{{ selectedInfo.toolName || '此技能不需要外部计算工具' }}</strong><el-tag v-if="selectedInfo.einoSupported" size="small" type="info">支持 Harness 调用</el-tag></div><span class="ops-hint">关闭后，此智能体不再调用该技能的计算工具；需要计算依据的专题将无法生成。工具接入状态不代表实时连通性，请在调试工作台验证。</span></el-form-item>
          </el-form>
          <p v-if="selectedInfo.sourceRef" class="ops-hint">来源：{{ selectedInfo.sourceRef }}</p>
          <h3>输入资料要求</h3><p class="ops-hint">随发布版本固定，来自已接入技能的输入契约。</p>
          <el-table :data="selectedInfo.inputSchema.fields || []" empty-text="无需结构化资料"><el-table-column label="资料"><template #default="{ row }">{{ row.label || row.key }}</template></el-table-column><el-table-column prop="type" label="类型" width="120" /><el-table-column label="要求" width="110"><template #default="{ row }">{{ row.required ? '必填' : '按需填写' }}</template></el-table-column></el-table>
          <div class="ops-capability-footer"><span class="ops-hint">{{ selectedPolicy.code === 'general' ? '日常问事是必要的兜底能力，保持启用。' : '移除只影响当前智能体草稿，源能力与历史报告保留。' }}</span><el-button v-if="selectedPolicy.code !== 'general'" type="danger" plain :icon="Delete" :disabled="busy" @click="changeSkill(selectedPolicy!.code, 'remove')">移除能力</el-button></div>
        </div>
        <el-empty v-else class="ops-card" description="选择一项能力查看配置" />
      </section>

      <el-drawer v-model="capabilityPicker" title="添加能力" size="min(580px, 100vw)">
        <p class="ops-hint">从已接入能力库添加到当前智能体。添加后保存草稿、完成评测并发布。</p>
        <el-input v-model="capabilitySearch" :prefix-icon="Search" clearable placeholder="搜索名称、工具或服务" aria-label="搜索能力" />
        <el-radio-group v-model="capabilityFilter" class="ops-capability-filters" aria-label="能力类型"><el-radio-button value="all">全部</el-radio-button><el-radio-button value="mcp">MCP 工具</el-radio-button><el-radio-button value="builtin">内置工具</el-radio-button><el-radio-button value="skill">业务技能</el-radio-button></el-radio-group>
        <el-empty v-if="!availableCapabilities.length" :description="missingSkills.length ? '没有匹配的能力' : '能力库中的项目均已添加'" />
        <article v-for="info in availableCapabilities" :key="info.code" class="ops-library-item"><div><strong>{{ info.name }}</strong><el-tag size="small">{{ kindLabel(info) }}</el-tag><p>{{ info.description }}</p><small>{{ info.toolServer ? `${info.toolServer} / ` : '' }}{{ info.toolName || info.code }} · {{ info.version }}</small></div><el-button :disabled="busy || info.sourceStatus === 'disabled'" :aria-label="`添加${info.name}`" @click="addSkill(info)">{{ info.sourceStatus === 'disabled' ? '源已停用' : '添加' }}</el-button></article>
      </el-drawer>

      <section v-show="tab === 'debug'" class="ops-debug-grid">
        <div class="ops-card"><div class="ops-section-head"><div><h2>试一次真实问事</h2><p>仅填写测试资料；调用现有模型与工具，会产生模型费用。</p></div></div>
          <el-alert v-if="dirty || !workspace.draftSaved" title="请先保存草稿，再开始调试" type="info" :closable="false" />
          <p class="ops-hint">{{ workspace.persistentRecovery ? '待补充任务加密保存 24 小时，可从运行记录恢复；正在调用时意外中断需重新开始。' : '未配置恢复密钥；服务重启后需重新开始调试。' }}</p><el-form label-position="top" @submit.prevent>
            <el-form-item label="技能"><el-select v-model="debug.skillCode" :disabled="inProgress || pending || debugBusy" aria-label="调试技能"><el-option v-for="s in enabledSkills" :key="s.code" :value="s.code" :label="skillName(s.code)" /></el-select></el-form-item>
            <el-form-item label="执行方式"><el-radio-group v-model="debug.kind" :disabled="inProgress || pending || debugBusy"><el-radio-button value="classic">原问事流程</el-radio-button><el-radio-button value="eino" :disabled="!einoAvailable">Eino 多步验证</el-radio-button></el-radio-group><span class="ops-hint">单次调试用于排查；发布需要通过质量评测。用户端执行模式以上方状态为准。</span></el-form-item>
            <el-form-item label="测试问题"><el-input v-model="debug.question" type="textarea" :rows="3" maxlength="1500" :disabled="inProgress || pending" aria-label="测试问题" /></el-form-item>
            <div class="ops-section-head"><h3>结构化资料</h3><el-button text :disabled="inProgress || debugBusy" @click="sample">填入合成示例</el-button></div>
            <div class="ops-grid"><el-form-item v-for="field in debugFields" :key="field.key" :label="`${field.label || field.key}${field.required ? ' · 必填' : ''}`"><el-select v-if="field.options?.length" v-model="inputValues[field.key]" clearable :disabled="inProgress || debugBusy" :aria-label="field.label || field.key"><el-option v-for="o in field.options" :key="o.value" :value="o.value" :label="o.label || o.value" /></el-select><el-input v-else v-model="inputValues[field.key]" :disabled="inProgress || debugBusy" :aria-label="field.label || field.key" :type="field.type === 'floorplan' ? 'textarea' : field.type === 'datetime' ? 'datetime-local' : field.type === 'date' && inputValues.calendarType === 'lunar' ? 'text' : field.type" :min="field.min" :max="field.max" :step="field.validation === 'integer' ? 1 : 'any'" :placeholder="field.type === 'date' ? 'YYYY-MM-DD' : field.type === 'time' ? 'HH:mm' : '填写测试资料'" :maxlength="field.type === 'floorplan' ? 20000 : 500" /><span v-if="field.helpText" class="ops-hint">{{ field.helpText }}</span></el-form-item></div>
            <p v-if="!debugFields.length" class="ops-hint">此技能无需额外资料。</p>
            <el-alert v-if="pending" :title="run?.clarification || '请补充资料后继续'" type="warning" :closable="false" />
            <div class="ops-debug-actions"><template v-if="pending"><el-button type="primary" :loading="debugBusy" @click="resumeDebug">补充并继续</el-button><el-button :disabled="debugBusy" @click="cancelDebug">结束本次调试</el-button></template><el-button v-else type="primary" :icon="VideoPlay" :loading="debugBusy || inProgress" :disabled="dirty || !workspace.draftSaved || !debug.skillCode || !debug.question.trim() || busy" @click="startDebug">{{ inProgress ? '正在执行' : '开始调试' }}</el-button><el-button v-if="run" text :icon="Refresh" @click="refreshRun">获取状态</el-button></div>
          </el-form>
        </div>
        <div class="ops-card ops-debug-result" aria-live="polite"><div class="ops-section-head"><h2>执行结果</h2><el-tag v-if="run" :type="run.status === 'completed' ? 'success' : run.status === 'failed' ? 'danger' : 'info'">{{ statusText(run.status) }}</el-tag></div>
          <el-alert v-if="pollError" :title="pollError" type="error" :closable="false" />
          <template v-if="run"><p class="ops-hint">草稿 r{{ run.revision }} · {{ run.model }}</p><ol class="ops-events"><li v-for="(event, index) in run.events" :key="index"><span class="ops-event-dot" /><div>{{ event.label }}<time>{{ timeText(event.at) }}</time></div></li></ol><el-alert v-if="run.error" :title="run.error" type="error" :closable="false" /><pre v-if="run.result" class="ops-answer">{{ run.result }}</pre><div class="ops-run-counts"><span>模型尝试 {{ run.modelAttempts }}</span><span>工具尝试 {{ run.toolAttempts }}</span><span>{{ run.promptTokens == null ? 'Token 用量暂未采集' : `输入 ${run.promptTokens} / 输出 ${run.completionTokens} Token` }}</span></div></template>
          <div v-else class="ops-empty"><el-icon><VideoPlay /></el-icon><h3>先验证，再发布</h3><p>查看补问、计算和回答的执行过程。</p></div>
        </div>
      </section>


      <section v-show="tab === 'evaluation'" class="ops-card">
        <div class="ops-section-head"><div><h2>可重复的质量检查</h2><p>每个启用技能至少配置一条正常回答用例。仅填写合成资料，用例随版本保存；执行会调用模型和计算工具。</p></div><el-button :disabled="busy || form.evaluation.length >= 100" @click="addCase">添加用例</el-button></div>
        <el-empty v-if="!form.evaluation.length" description="添加测试问题与预期结果，建立发布检查" />
        <el-collapse>
          <el-collapse-item v-for="c in form.evaluation" :key="c.id" :name="c.id" :title="`${c.name} · ${skillName(c.skillCode)}`">
            <el-form label-position="top" :disabled="busy" @submit.prevent>
              <div class="ops-grid"><el-form-item label="用例名称"><el-input v-model="c.name" aria-label="用例名称" maxlength="50" /></el-form-item><el-form-item label="验证技能"><el-select v-model="c.skillCode" aria-label="评测技能"><el-option v-for="s in enabledSkills" :key="s.code" :value="s.code" :label="skillName(s.code)" /></el-select></el-form-item></div>
              <el-form-item label="测试问题"><el-input v-model="c.question" aria-label="评测问题" type="textarea" :rows="2" maxlength="1500" /></el-form-item>
              <el-form-item label="合成资料（JSON）" :error="caseErrors[c.id]"><el-input aria-label="合成资料 JSON" :model-value="caseInputs[c.id] ?? JSON.stringify(c.inputs, null, 2)" type="textarea" :rows="3" @update:model-value="(v: string) => editCaseInputs(c, v)" /></el-form-item>
              <el-form-item label="预期行为"><el-switch v-model="c.expectInvalid" aria-label="预期拒绝无效资料" active-text="无效资料应在调用前被拒绝" inactive-text="正常回答" /></el-form-item>
              <template v-if="!c.expectInvalid"><el-form-item label="最少输出字数"><el-input-number v-model="c.minChars" aria-label="最低输出字数" :min="20" :max="2000" /></el-form-item><div class="ops-grid"><el-form-item label="必须包含（每行一项，可留空）"><el-input aria-label="必须包含内容" :model-value="c.contains.join('\n')" type="textarea" @update:model-value="(v: string) => c.contains = v.split('\n').filter(t => t.trim())" /></el-form-item><el-form-item label="不得包含（每行一项，可留空）"><el-input aria-label="不得包含内容" :model-value="c.excludes.join('\n')" type="textarea" @update:model-value="(v: string) => c.excludes = v.split('\n').filter(t => t.trim())" /></el-form-item></div></template>
              <el-button type="danger" text @click="removeCase(c.id)">移除此用例</el-button>
            </el-form>
          </el-collapse-item>
        </el-collapse>
        <div class="ops-debug-actions"><el-button type="primary" :loading="evalBusy || evaluation?.status === 'running'" :disabled="dirty || !workspace.draftSaved || !form.evaluation.length || !!Object.keys(caseErrors).length" @click="startEvaluation">运行评测集</el-button><el-button @click="loadEvaluations">刷新记录</el-button><el-button v-if="evaluation" text @click="pollEvaluation(evaluation.id)">获取本次状态</el-button></div>
        <p class="ops-hint">单组最多 100 条；总时限按用例数分配，最长 30 分钟。通过结果在 24 小时内可发布；修改草稿或模型连接后需重新评测。检查长度、关键词、资料拦截与工具调用，不代表专业准确性认证。</p>
        <el-alert v-if="evalError" :title="evalError" type="error" :closable="false" />
        <template v-if="evaluation"><h3>本次评测 · {{ statusText(evaluation.status) }} · {{ evaluation.results.length }}/{{ evaluation.total }}</h3><el-alert v-if="evaluation.error" :title="evaluation.error" type="error" :closable="false" /><el-table :data="evaluation.results"><el-table-column prop="name" label="用例" min-width="160" /><el-table-column label="结果" width="90"><template #default="{ row }"><el-tag :type="row.passed ? 'success' : 'danger'">{{ row.passed ? '通过' : '未通过' }}</el-tag></template></el-table-column><el-table-column label="检查详情" min-width="220"><template #default="{ row }">{{ row.checks.join('；') || '全部断言通过' }}</template></el-table-column><el-table-column label="耗时" width="90"><template #default="{ row }">{{ (row.latencyMs / 1000).toFixed(1) }}s</template></el-table-column></el-table></template>
        <h3>最近评测</h3><el-table :data="evaluations" empty-text="暂无评测记录"><el-table-column label="草稿" width="100"><template #default="{ row }">r{{ row.revision }}</template></el-table-column><el-table-column label="状态" width="120"><template #default="{ row }">{{ statusText(row.status) }}</template></el-table-column><el-table-column label="时间" min-width="180"><template #default="{ row }">{{ timeText(row.startedAt) }}</template></el-table-column><el-table-column label="操作" width="90"><template #default="{ row }"><el-button link @click="evaluation = row; pollEvaluation(row.id)">查看</el-button></template></el-table-column></el-table>
      </section>

      <section v-show="tab === 'runs'" class="ops-card">
        <div class="ops-section-head"><div><h2>执行记录</h2><p>用户问事与管理员调试分别查看，默认隐藏原始资料和对话正文。</p></div><el-button :icon="Refresh" :loading="recordsLoading" @click="loadRecords">刷新</el-button></div>
        <div class="ops-record-filters"><el-radio-group v-model="recordKind"><el-radio-button value="production">用户问事</el-radio-button><el-radio-button value="debug">后台调试</el-radio-button></el-radio-group><el-select v-if="recordKind === 'production'" v-model="status" clearable placeholder="全部状态" aria-label="运行状态" @change="changeStatus"><el-option v-for="s in ['completed', 'failed', 'running']" :key="s" :value="s" :label="statusText(s)" /></el-select></div>
        <el-alert v-if="recordsError" :title="recordsError" type="error" :closable="false" />
        <el-table v-else-if="recordKind === 'production'" :data="records" v-loading="recordsLoading" empty-text="暂无问事执行记录"><el-table-column prop="runNo" label="运行编号" min-width="200" /><el-table-column label="技能 / 版本" min-width="170"><template #default="{ row }">{{ skillName(row.skillCode) }}<small class="ops-cell-sub">{{ row.skillVersion }}</small></template></el-table-column><el-table-column prop="model" label="模型" min-width="160" /><el-table-column label="状态" width="100"><template #default="{ row }">{{ statusText(row.status) }}</template></el-table-column><el-table-column label="耗时" width="100"><template #default="{ row }">{{ row.status === 'running' ? '—' : `${(row.latencyMs / 1000).toFixed(1)}s` }}</template></el-table-column><el-table-column label="输入 / 输出 Token" width="155"><template #default="{ row }">{{ row.promptTokens }} / {{ row.completionTokens }}</template></el-table-column><el-table-column label="操作" width="110" fixed="right"><template #default="{ row }"><el-button link type="primary" @click="showTools(row)">工具轨迹</el-button></template></el-table-column></el-table>
        <el-table v-else :data="debugRecords" v-loading="recordsLoading" empty-text="暂无后台调试记录"><el-table-column label="时间" min-width="180"><template #default="{ row }">{{ timeText(row.startedAt) }}</template></el-table-column><el-table-column label="草稿" width="90"><template #default="{ row }">r{{ row.revision }}</template></el-table-column><el-table-column label="技能" min-width="130"><template #default="{ row }">{{ skillName(row.skillCode) }}</template></el-table-column><el-table-column label="方式" width="120"><template #default="{ row }">{{ row.kind === 'eino' ? 'Eino 验证' : '原问事流程' }}</template></el-table-column><el-table-column label="状态" width="120"><template #default="{ row }">{{ statusText(row.status) }}</template></el-table-column><el-table-column label="操作" width="100"><template #default="{ row }"><el-button link type="primary" @click="showDebug(row)">查看详情</el-button></template></el-table-column></el-table>
        <div v-if="recordKind === 'production'" class="ops-pagination"><el-button :disabled="page === 1 || recordsLoading" @click="page--">上一页</el-button><span>第 {{ page }} 页</span><el-button :disabled="!hasMore || recordsLoading" @click="page++">下一页</el-button></div>
      </section>

      <section v-show="tab === 'versions'" class="ops-card">
        <div class="ops-section-head"><div><h2>发布与回滚</h2><p>每个启用技能至少一条正常用例通过后才能发布。自动断言通过后，仍需人工检查回答质量。</p></div><el-button type="primary" :icon="Check" :disabled="dirty || !workspace.tested || busy" @click="publish">发布当前草稿</el-button></div>
        <el-alert v-if="!workspace.liveEnabled" title="版本配置接管尚未开启；当前执行引擎不受此开关影响" type="info" :closable="false" />
        <div class="ops-fallback"><div><h3>候选版本覆盖 {{ workspace.rollout.percentage }}%</h3><p>其余账号使用{{ workspace.rollout.stableVersion ? `稳定版本 v${workspace.rollout.stableVersion}` : '原始配置' }}。比例按账号固定分配。</p></div><div class="ops-rollout-actions"><el-button v-for="percent in [0, 10, 25, 50, 100]" :key="percent" :type="workspace.rollout.percentage === percent ? 'primary' : 'default'" :disabled="busy || dirty || !workspace.liveEnabled || !workspace.rollout.versionId || workspace.rollout.percentage === percent" @click="setRollout(percent)">{{ percent }}%</el-button></div></div>
        <el-table :data="workspace.versions" empty-text="尚无发布版本。保存草稿并通过评测后即可发布。"><el-table-column label="版本" width="150"><template #default="{ row }"><strong>v{{ row.id }}</strong><el-tag v-if="row.id === workspace.activeVersion" size="small" class="ops-version-tag">{{ '候选版本' }}</el-tag></template></el-table-column><el-table-column prop="note" label="发布说明" min-width="240" /><el-table-column prop="actor" label="操作人" width="100" /><el-table-column prop="createdAt" label="时间" min-width="180" /><el-table-column label="操作" width="190"><template #default="{ row }"><el-button link type="primary" :disabled="busy" @click="showVersion(row.id)">查看配置</el-button><el-button link type="primary" :disabled="row.id === workspace.activeVersion || busy || dirty" @click="rollback(row.id)">回滚到此版</el-button></template></el-table-column></el-table>
        <div class="ops-fallback"><div><h3>原始问事配置</h3><p>恢复到本次运营管理接入前的技能配置来源。</p></div><el-button :disabled="!workspace.activeVersion || busy || dirty" @click="rollback(0)">恢复原配置</el-button></div>
        <h3>最近操作</h3><el-table :data="workspace.audit" empty-text="尚无操作记录"><el-table-column label="操作" width="100"><template #default="{ row }">{{ ({ save: '保存草稿', publish: '发布', rollback: '回滚', rollout: '调整比例' } as Record<string, string>)[row.action] || row.action }}</template></el-table-column><el-table-column prop="note" label="说明" min-width="200" /><el-table-column prop="actor" label="操作人" width="100" /><el-table-column prop="createdAt" label="时间" min-width="180" /></el-table>
      </section>

      <footer v-show="tab === 'config' || tab === 'skills' || tab === 'evaluation'" class="ops-save-bar"><span :class="{ 'is-dirty': dirty }">{{ dirty ? '有未保存的修改' : workspace.draftSaved ? '草稿已同步' : '待首次保存' }}</span><div><el-button :disabled="!dirty || busy" @click="reload">撤销修改</el-button><el-button type="primary" :loading="busy" :disabled="(!dirty && workspace.draftSaved) || busy" @click="save">保存草稿</el-button></div></footer>
    </template>
    <el-dialog v-model="versionDialog" :title="`版本 v${versionNumber} · 已发布配置`" width="min(760px, 94vw)">
      <template v-if="versionConfig"><h3>{{ versionConfig.name }}</h3><p class="ops-hint">{{ versionConfig.model }} · 最多 {{ versionConfig.maxOutputTokens }} Token</p><pre class="ops-answer">{{ versionConfig.instruction }}</pre><el-collapse><el-collapse-item v-for="skill in versionConfig.skills" :key="skill.code" :name="skill.code" :title="`${skillName(skill.code)} · ${skill.enabled ? '启用' : '停用'} · ${skill.useTool ? '使用计算工具' : '不使用工具'}`"><pre class="ops-answer">{{ skill.prompt }}</pre></el-collapse-item></el-collapse></template>
    </el-dialog>
    <el-drawer v-model="drawer" title="工具执行轨迹" size="min(520px, 100vw)"><div v-loading="toolsLoading"><p>{{ detailRun?.runNo }}</p><p class="ops-hint">{{ detailRun?.skillVersion }} · {{ detailRun?.model }}</p><el-alert v-if="toolsError" :title="toolsError" type="error" :closable="false" /><el-empty v-else-if="!toolsLoading && !tools.length" description="本次没有计算工具调用" /><ol v-else class="ops-events"><li v-for="(tool, i) in tools" :key="i"><span class="ops-event-dot" /><div><strong>{{ tool.name }}</strong><p>{{ statusText(tool.status) }} · {{ tool.latencyMs }} ms</p><time>{{ timeText(tool.createdAt) }}</time></div></li></ol></div></el-drawer>
  </div>
</template>

<style scoped>
.ops-capability-meta{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-bottom:20px;color:var(--el-text-color-secondary);font-size:13px}.ops-capability-footer{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;margin-top:24px;padding-top:16px;border-top:1px solid var(--el-border-color-light)}.ops-capability-filters{display:flex;flex-wrap:wrap;margin:16px 0}.ops-library-item{display:flex;align-items:flex-start;gap:16px;padding:20px 0;border-bottom:1px solid var(--el-border-color-light)}.ops-library-item>div{flex:1;min-width:0}.ops-library-item strong{margin-right:10px}.ops-library-item p{font-size:13px;line-height:1.7;color:var(--el-text-color-secondary)}.ops-library-item small{overflow-wrap:anywhere;color:var(--el-text-color-secondary)}.ops-add-capability{margin:8px 0}

.ops-rollout-actions{display:flex;gap:6px;flex-wrap:wrap}.ops-rollout-actions .el-button{margin-left:0}.agent-ops{padding-bottom:24px}.ops-overview{display:flex;align-items:center;gap:28px;padding:22px 26px;border:1px solid var(--el-border-color-light);border-radius:16px;background:var(--el-bg-color);margin-bottom:18px}.ops-identity{display:flex;align-items:center;gap:14px;flex:1}.ops-identity strong{font-size:20px}.ops-identity p,.ops-section-head p,.ops-fallback p{margin:7px 0 0;color:var(--el-text-color-secondary);font-size:13px;line-height:1.6}.ops-symbol{width:46px;height:46px;border-radius:13px;background:var(--el-color-primary-light-9);color:var(--el-color-primary);display:grid;place-items:center}.ops-symbol svg{width:25px}.ops-stat{display:grid;gap:8px;min-width:95px}.ops-stat>span{color:var(--el-text-color-secondary);font-size:12px}.ops-stat strong{font-size:15px}.ready{color:var(--el-color-success)}.ops-tabs{display:flex;gap:4px;overflow-x:auto;margin:0 0 20px;border-bottom:1px solid var(--el-border-color-light)}.ops-tabs button{display:flex;align-items:center;gap:7px;white-space:nowrap;padding:14px 19px;border:0;border-bottom:2px solid transparent;background:transparent;color:var(--el-text-color-secondary);cursor:pointer;font:inherit}.ops-tabs button.active{color:var(--el-color-primary);border-bottom-color:var(--el-color-primary);font-weight:600}.ops-tabs button:focus-visible,.ops-skill-list button:focus-visible{outline:2px solid var(--el-color-primary);outline-offset:-3px}.ops-card{background:var(--el-bg-color);border:1px solid var(--el-border-color-light);border-radius:16px;padding:24px;min-width:0}.ops-card h2{font-size:17px;margin:0 0 8px}.ops-card h3,.ops-fallback h3{font-size:14px;margin:14px 0 8px}.ops-section-head{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;margin-bottom:22px}.ops-section-head a{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--el-color-primary);white-space:nowrap}.ops-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:0 20px}.ops-hint{display:block;color:var(--el-text-color-secondary);font-size:12px;line-height:1.7;margin-top:8px}.ops-skills{display:grid;grid-template-columns:240px minmax(0,1fr);gap:20px}.ops-skill-list{padding:20px 12px;align-self:start}.ops-skill-list h2{padding:0 12px 12px}.ops-skill-list button{display:flex;align-items:center;justify-content:space-between;gap:10px;width:100%;border:0;background:transparent;color:var(--el-text-color-primary);padding:13px 12px;border-radius:9px;cursor:pointer;text-align:left;font:inherit;font-size:13px}.ops-skill-list button.selected{background:var(--el-color-primary-light-9);color:var(--el-color-primary)}.ops-pill{font-size:11px;color:var(--el-color-success);white-space:nowrap}.ops-pill.muted{color:var(--el-text-color-placeholder)}.ops-tool-row{display:flex;align-items:center;gap:12px;flex-wrap:wrap}.ops-debug-grid{display:grid;grid-template-columns:minmax(300px,1fr) minmax(320px,1fr);gap:20px}.ops-debug-result{align-self:start;min-height:360px}.ops-debug-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:20px}.ops-empty{text-align:center;color:var(--el-text-color-secondary);padding:65px 15px}.ops-empty>.el-icon{font-size:34px;color:var(--el-color-primary)}.ops-answer{font-family:inherit;white-space:pre-wrap;overflow-wrap:anywhere;font-size:14px;line-height:1.9;padding:18px;background:var(--el-fill-color-light);border-radius:10px;max-height:460px;overflow:auto}.ops-events{list-style:none;margin:20px 0;padding:0}.ops-events li{display:flex;gap:12px;padding:0 0 20px;position:relative;font-size:13px}.ops-event-dot{width:8px;height:8px;flex-shrink:0;border-radius:50%;background:var(--el-color-primary);margin-top:5px}.ops-events li:not(:last-child):before{content:'';position:absolute;left:3px;top:15px;bottom:3px;width:1px;background:var(--el-border-color-light)}.ops-events time{display:block;color:var(--el-text-color-placeholder);font-size:11px;margin-top:5px}.ops-run-counts{display:flex;gap:14px;flex-wrap:wrap;font-size:12px;color:var(--el-text-color-secondary);border-top:1px solid var(--el-border-color-light);padding-top:14px}.ops-record-filters{display:flex;gap:16px;margin:16px 0 20px;flex-wrap:wrap}.ops-record-filters>.el-select{width:160px}.ops-cell-sub{display:block;color:var(--el-text-color-secondary);font-size:11px}.ops-pagination{display:flex;align-items:center;justify-content:flex-end;gap:14px;margin-top:20px;font-size:13px}.ops-fallback{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:18px 0;margin:16px 0;border-bottom:1px solid var(--el-border-color-light)}.ops-version-tag{margin-left:8px}.ops-save-bar{position:sticky;bottom:12px;z-index:5;display:flex;align-items:center;justify-content:space-between;gap:16px;margin-top:20px;padding:14px 20px;background:var(--el-bg-color);border:1px solid var(--el-border-color-light);border-radius:12px;box-shadow:0 6px 24px #00000008;font-size:13px;color:var(--el-text-color-secondary)}.is-dirty{color:var(--el-color-warning)}.ops-card :deep(.el-select){width:100%}.ops-card :deep(.el-form-item__content > .ops-hint){flex-basis:100%}.ops-card :deep(.el-alert){margin-bottom:16px}.ops-card :deep(.el-input-number){width:180px}.ops-tabs button,.ops-skill-list button{transition:background-color 140ms ease,color 140ms ease}@media(max-width:1000px){.ops-overview{flex-wrap:wrap;gap:18px}.ops-identity{flex-basis:100%}.ops-debug-grid{grid-template-columns:1fr}.ops-skills{grid-template-columns:200px minmax(0,1fr)}}@media(max-width:640px){.ops-skills,.ops-grid{grid-template-columns:1fr}.ops-skill-list{max-height:240px;overflow:auto}.ops-card{padding:18px}.ops-section-head{flex-wrap:wrap}.ops-stat{min-width:80px}.ops-tabs button{padding:12px}.ops-overview{padding:18px}.ops-save-bar{bottom:6px;padding:12px}.ops-debug-actions{gap:4px}}@media(prefers-reduced-motion:reduce){.ops-tabs button,.ops-skill-list button{transition:none}}
</style>

<style scoped>.ops-workspaces{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:24px 0 8px;padding:6px;background:var(--el-fill-color-light);border-radius:14px}.ops-workspaces button{padding:16px;border:0;border-radius:10px;background:transparent;color:var(--el-text-color-regular);font:inherit;cursor:pointer;transition:background-color 160ms,color 160ms}.ops-workspaces button[aria-current=page]{background:var(--el-bg-color);color:var(--el-color-primary);box-shadow:0 2px 8px #0000000a}.ops-workspaces button:focus-visible{outline:2px solid var(--el-color-primary)}@media(prefers-reduced-motion:reduce){.ops-workspaces button{transition:none}}</style>
