<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import client from '@/api/client'
import { modelLibraryApi, modelOptions } from '@/api/modelLibrary'
import { computed, inject, onMounted, onBeforeUnmount, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { agentDraftDirtyKey, agentSectionPath } from './centerNavigation'

import { VideoPlay, Refresh, Check, Plus, Delete, Search } from '@element-plus/icons-vue'
import { agentOperationsApi as api, type AgentWorkspace, type AgentConfig, type DebugRun, type ProductionRun, type ToolTrace, type EvaluationRun, type EvaluationCase } from '@/api/agentOperations'

import { addCapability, changeCapability, capabilityKind } from './agentCapabilities'

const workspace = ref<AgentWorkspace>(), loading = ref(true), busy = ref(false), loadError = ref('')
const route = useRoute(), router = useRouter()
const tab = computed({ get: () => String(route.meta.agentSection ?? ''), set: value => { void router.push(agentSectionPath(value)) } })
const editing = computed(() => ['config', 'skills', 'context'].includes(tab.value))
const form = ref<AgentConfig>(), baseline = ref(''), selectedSkill = ref('')
const models = ref<{ id: string; name: string }[]>([])
const knowledgeBases=ref<{id:string;name:string;enabled:boolean}[]>([])
async function loadKnowledgeBases(){try{const v=await client.get<{list:typeof knowledgeBases.value}>("/ai/admin/knowledge-bases");knowledgeBases.value=v.list||[]}catch{knowledgeBases.value=[]}}
const rerankModels = ref<{ id: string; name: string }[]>([])
async function loadModelOptions() {
  try {
    const library = await modelLibraryApi.list()
    models.value = modelOptions(library, 'chat')
    rerankModels.value = modelOptions(library, 'rerank')
  } catch { rerankModels.value = [] }
}
const savedChatModel = computed(() => {
  const id = workspace.value?.draft.model
  return models.value.find(model => model.id === id)?.name || id || '平台聊天默认模型'
})
const dirty = computed(() => JSON.stringify(form.value) !== baseline.value || Object.keys(caseErrors).length > 0)
const workspaceDirty = inject(agentDraftDirtyKey)
watch(() => !!workspace.value && dirty.value, changed => {
  if (workspaceDirty) workspaceDirty.value = changed
}, { immediate: true })
const draftNeedsSave = computed(() => dirty.value || !workspace.value?.draftSaved)
const nextStep = computed(() => {
  if (draftNeedsSave.value) return undefined
  if (editing.value) return { title: '进入单次调试', section: 'debug' }
  if (tab.value === 'evaluation' && workspace.value?.tested) return { title: '前往发布', section: 'versions' }
})
const publishBlock = computed(() => {
  if (draftNeedsSave.value) return '请先保存当前草稿'
  return workspace.value?.tested ? '' : '当前草稿尚未通过质量评测'
})
const onlineVersion = computed(() => {
  const current = workspace.value
  if (!current?.liveEnabled) return
  const { versionId, stableVersion, percentage } = current.rollout
  return {
    stable: versionId && percentage === 100 ? versionId : stableVersion,
    candidate: percentage > 0 && percentage < 100 ? versionId : 0,
    percentage,
  }
})
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
  ElMessage.success((uiText("") + String(info.name) + uiText("已加入草稿")))
}
async function changeSkill(code: string, action: 'remove' | 'disable' | 'enable') {
  if (!form.value || busy.value || (code === 'general' && action !== 'enable')) return
  const info = workspace.value?.catalog.find(s => s.code === code)
  if (action === 'enable' && info?.sourceStatus === 'disabled') { ElMessage.warning(uiText('源技能已停用，当前无法启用')); return }
  const related = form.value.evaluation.filter(c => c.skillCode === code)
  if (action === 'remove' || (action === 'disable' && related.length)) {
    const verb = action === 'remove' ? '移除' : '停用'
    try { await ElMessageBox.confirm((uiText("") + String(verb) + uiText("“") + String(skillName(code)) + uiText("”") + String((related.length ? (uiText("会同时移除草稿中关联的 ") + String(related.length) + uiText(" 条评测用例")) : uiText('只修改当前草稿'))) + uiText("。") + String((action === 'remove' ? uiText('之后可从能力库重新添加；源技能和历史记录保留。') : uiText('技能配置保留，之后可以重新启用。'))) + uiText("发布后才会影响用户端。")), (uiText("") + String(verb) + uiText("能力")), { confirmButtonText: uiText(verb), cancelButtonText: uiText('取消'), type: 'warning' }) } catch { return }
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
    if (!workspace.value) debug.kind = value.runtimeMode === "harness" ? "harness" : "classic"
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
  if (dirty.value) { try { await ElMessageBox.confirm(uiText('重新加载将丢弃尚未保存的修改。'), uiText('重新加载'), { confirmButtonText: uiText('重新加载'), cancelButtonText: uiText('继续编辑') }) } catch { return } }
  await load()
}
async function save() {
  if (!workspace.value || !form.value) return
  if (Object.keys(caseErrors).length) { ElMessage.warning(uiText("请先修正评测资料格式")); return }
  busy.value = true
  try { await api.save(workspace.value.revision, JSON.parse(JSON.stringify(form.value))); await load(); ElMessage.success(uiText('草稿已保存')) }
  catch { /* keep editable draft on conflict or validation failure */ } finally { busy.value = false }
}
async function publish() {
  if (!workspace.value || publishBlock.value) return
  let note: string
  try { const value = await ElMessageBox.prompt(uiText('生成固定版本，初始发布比例为 0%。请在版本页逐步扩大范围；原稳定版本继续服务。'), uiText('发布智能体配置'), { inputPlaceholder: uiText('说明本次调整内容'), inputValidator: value => Boolean(value?.trim()) && value.length <= 500 || '请填写 1 至 500 字说明', confirmButtonText: uiText('确认发布'), cancelButtonText: uiText('取消') }); note = value.value } catch { return }
  busy.value = true
  try { await api.publish(workspace.value.revision, note); await load(); ElMessage.success(uiText('版本已发布')) } catch { /* retain state */ } finally { busy.value = false }
}
async function rollback(version: number) {
  if (!workspace.value) return
  let note: string
  try { const value = await ElMessageBox.prompt((uiText("新请求将使用") + String((version ? (uiText("版本 v") + String(version) + uiText("")) : uiText('原始问事配置'))) + uiText("，当前草稿保持不变。")), uiText('回滚配置'), { inputPlaceholder: uiText('填写回滚原因'), inputValidator: value => Boolean(value?.trim()) && value.length <= 500 || '请填写 1 至 500 字原因', confirmButtonText: uiText('确认回滚'), cancelButtonText: uiText('取消') }); note = value.value } catch { return }
  busy.value = true
  try { await api.rollback(workspace.value.revision, version, note); await load(true); ElMessage.success(uiText('已回滚')) } catch { /* client displays error */ } finally { busy.value = false }
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
  try { const result = await ElMessageBox.prompt((uiText("候选版本 v") + String(workspace.value.rollout.versionId) + uiText(" 将覆盖 ") + String(percentage) + uiText("% 的账号，其余继续使用稳定版本。")), uiText('调整发布比例'), { inputPlaceholder: uiText('填写变更原因'), inputValidator: v => Boolean(v?.trim()) && v.length <= 450 || '请填写 1 至 450 字原因', confirmButtonText: uiText('应用比例'), cancelButtonText: uiText('取消') }); note = result.value } catch { return }
  busy.value = true
  try { await api.setRollout(workspace.value.rollout.revision, percentage, note); await load(true); ElMessage.success(uiText('发布比例已更新')) } catch { /* retain state */ } finally { busy.value = false }
}
watch(tab, (value, previous) => {
  if (value === 'versions' || (value && !previous)) void load(true)
  if (value === 'evaluation') void loadEvaluations()
  if (['config', 'context', 'versions'].includes(value)) void loadModelOptions()
  if (value === 'context') void loadKnowledgeBases()
})

const debug = reactive({ kind: 'classic', skillCode: '', question: '请根据这份测试资料，说明可以提供哪些有依据的参考。' })
const inputValues = reactive<Record<string, string>>({}), run = ref<DebugRun>(), debugBusy = ref(false), pollError = ref('')
const debugInfo = computed(() => workspace.value?.catalog.find(s => s.code === debug.skillCode))
const debugFields = computed(() => (debugInfo.value?.inputSchema.fields || []).filter(f => !f.visibleWhen || inputValues[f.visibleWhen.key] === f.visibleWhen.value))
const einoAvailable = computed(() => debugInfo.value?.einoSupported && form.value?.skills.find(s => s.code === debug.skillCode)?.useTool)
const inProgress = computed(() => run.value?.status === 'running')
const pending = computed(() => run.value?.status === 'awaiting_input')
let timer: ReturnType<typeof setTimeout> | undefined, pollGeneration = 0, disposed = false
watch(() => debug.skillCode, () => { Object.keys(inputValues).forEach(k => delete inputValues[k]); if (debug.kind === "eino" && !einoAvailable.value) debug.kind = 'classic' })
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
function beforeUnload(e: BeforeUnloadEvent) { if (dirty.value && workspace.value) { e.preventDefault(); e.returnValue = '' } }
onMounted(() => {
  window.addEventListener('beforeunload', beforeUnload)
  void load()
  if (tab.value === 'evaluation') void loadEvaluations()
  if (tab.value === 'runs') void loadRecords()
  if (['config', 'context', 'versions'].includes(tab.value)) void loadModelOptions()
  if (tab.value === 'context') void loadKnowledgeBases()
})
onBeforeUnmount(() => { disposed = true; if (evalTimer) clearTimeout(evalTimer); stopPoll(); recordGeneration++; window.removeEventListener('beforeunload', beforeUnload) })
</script>

<template>
  <div class="dfx-page agent-ops" v-loading="loading">
    <header class="ops-page-head">
      <h1>{{ $t(String(route.meta.title)) }}</h1>
      <section v-if="workspace && form" class="ops-context" :aria-label='$t("智能体状态")'>
        <dl>
          <div v-if="workspace.runtimeMode">
            <dt>{{ $t("执行引擎") }}</dt>
            <dd>{{ $t(workspace.runtimeMode === 'harness' ? 'Eino Harness' : '原问事流程') }}</dd>
          </div>
          <div><dt>{{ $t("草稿") }}</dt><dd :class="{ 'is-dirty': draftNeedsSave }">
            r{{ workspace.revision }}<span v-if="draftNeedsSave"> · {{ $t("未保存") }}</span>
          </dd></div>
          <div><dt>{{ $t("评测") }}</dt><dd :class="{ ready: workspace.tested && !draftNeedsSave }">
            {{ $t(workspace.tested && !draftNeedsSave ? '已通过' : '待评测') }}
          </dd></div>
          <div><dt>{{ $t("线上") }}</dt><dd>
            {{ onlineVersion?.stable ? `v${onlineVersion.stable}` : $t("原始配置") }}
            <span v-if="onlineVersion?.candidate"> · {{ $t("候选") }} v{{ onlineVersion.candidate }} {{ onlineVersion.percentage }}%</span>
          </dd></div>
        </dl>
        <div class="ops-heading-actions">
          <el-button text :icon="Refresh" :disabled="busy" :title='$t("重新加载")' :aria-label='$t("重新加载")' @click="reload" />
          <template v-if="draftNeedsSave && tab && tab !== 'runs'">
            <el-button v-if="dirty" text :disabled="busy" @click="reload">{{ $t("撤销修改") }}</el-button>
            <el-button type="primary" :loading="busy" :disabled="busy" @click="save">{{ $t("保存草稿") }}</el-button>
          </template>
          <RouterLink v-else-if="nextStep" class="ops-heading-link" :to="agentSectionPath(nextStep.section)">{{ $t(nextStep.title) }}</RouterLink>
        </div>
      </section>
    </header>
    <el-alert v-if="loadError" :title="$t(loadError)" type="error" :closable="false" show-icon><el-button text @click="reload">{{ $t("重试") }}</el-button></el-alert>
    <template v-if="workspace && form">

      <div v-if="editing || tab === 'debug'" class="ops-workspace" :class="{ 'has-preview': editing }">
        <div v-if="editing" class="ops-editor">
          <section v-if="tab === 'config'" class="ops-card ops-config">
            <el-form label-position="top" :disabled="busy" @submit.prevent="save">
              <el-form-item class="ops-prompt" :label='$t("职责与回答要求")'>
                <el-input v-model="form.instruction" type="textarea" :rows="10" maxlength="2500" show-word-limit :aria-label='$t("职责与回答要求")' />
              </el-form-item>
              <div class="ops-grid">
                <el-form-item :label='$t("名称")'>
                  <el-input v-model="form.name" maxlength="40" :aria-label='$t("智能体名称")' />
                </el-form-item>
                <el-form-item class="ops-model-field">
                  <template #label>
                    <span>{{ $t("问事聊天模型") }}</span>
                    <RouterLink class="ops-field-link" to="/ai/connections/models">{{ $t("管理模型") }}</RouterLink>
                  </template>
                  <el-select v-model="form.model" filterable clearable :aria-label='$t("问事聊天模型")' :placeholder='$t("保存时采用平台聊天默认模型")'>
                    <el-option v-if="form.model && !models.some(m => m.id === form?.model)" :value="form.model" :label="$t(form.model)" />
                    <el-option v-for="model in models" :key="model.id" :value="model.id" :label="$t(model.name)" />
                  </el-select>
                </el-form-item>
              </div>
              <details class="ops-advanced">
                <summary>{{ $t("生成参数") }}</summary>
                <el-form-item :label='$t("回答输出上限")'>
                  <el-input-number v-model="form.maxOutputTokens" :min="64" :max="32768" :step="1024" :aria-label='$t("回答输出上限")' />
                  <span class="ops-hint">{{ $t("Token，同时受全局模型设置限制。") }}</span>
                </el-form-item>
              </details>
            </el-form>
          </section>

          <section v-if="tab === 'context'" class="ops-card">
            <el-form label-position="top" :disabled="busy" @submit.prevent="save">
              <el-form-item :label='$t("知识检索")'>
                <el-switch v-model="form.knowledgeEnabled" :active-text='$t("检索已审核知识")' />
              </el-form-item>
              <el-form-item :label='$t("绑定知识库")'>
                <el-select v-model="form.knowledgeBaseIds" multiple filterable :aria-label='$t("绑定知识库")'
                  :placeholder='$t("选择已审核知识库（不选则不检索）")' @visible-change="(open: boolean) => open && loadKnowledgeBases()">
                  <el-option v-for="base in knowledgeBases" :key="base.id" :label="$t(base.name + (base.enabled ? '' : $t('（停用）')))" :value="base.id" :disabled="!base.enabled" />
                </el-select>
                <RouterLink class="ops-field-link" to="/ai/knowledge">{{ $t("管理知识库") }}</RouterLink>
              </el-form-item>
              <el-form-item :label='$t("用户记忆")'>
                <el-switch v-model="form.memoryEnabled" :active-text='$t("读取用户明确保存的记忆")' />
              </el-form-item>
              <el-form-item :label='$t("联网搜索")'>
                <el-switch v-model="form.webSearchEnabled" :active-text='$t("允许用户在提问时开启联网")' />
                <RouterLink class="ops-field-link" to="/ai/connections/search">{{ $t("配置搜索服务") }}</RouterLink>
                <span v-if="form.webSearchEnabled" class="ops-hint">{{ $t("搜索服务配置完成后，用户才能调用联网工具。") }}</span>
              </el-form-item>
              <details v-if="form.retrieval" class="ops-advanced">
                <summary>{{ $t("高级检索设置") }}</summary>
                <div class="ops-grid">
                  <el-form-item :label='$t("候选片段数量")'>
                    <el-input-number v-model="form.retrieval.candidateCount" :min="5" :max="40" />
                  </el-form-item>
                  <el-form-item :label='$t("最终引用片段数量")'>
                    <el-input-number v-model="form.retrieval.resultCount" :min="1" :max="Math.min(10, form.retrieval.candidateCount)" />
                  </el-form-item>
                </div>
                <el-form-item :label='$t("重排模型")'>
                  <el-select v-model="form.retrieval.rerankModel" filterable clearable :placeholder='$t("关闭专用重排")'
                    @change="!form.retrieval.rerankModel && (form.retrieval.rerankRequired = false)">
                    <el-option v-if="form.retrieval.rerankModel && !rerankModels.some(m => m.id === form?.retrieval?.rerankModel)"
                      :value="form.retrieval.rerankModel" :label="$t(form.retrieval.rerankModel)" />
                    <el-option v-for="model in rerankModels" :key="model.id" :value="model.id" :label="$t(model.name)" />
                  </el-select>
                </el-form-item>
                <el-form-item :label='$t("重排不可用时")'>
                  <el-switch v-model="form.retrieval.rerankRequired" :disabled="!form.retrieval.rerankModel"
                    :active-text='$t("停止本次检索")' :inactive-text='$t("回退混合检索并记录降级")' />
                </el-form-item>
                <el-form-item :label='$t("实体图谱")'>
                  <el-switch v-model="form.retrieval.graphEnabled" :active-text='$t("检索已审核原文关联的实体关系")' />
                  <p class="ops-hint">{{ $t("需先完成 Neo4j 抽取。图谱内容作为检索参考。") }}</p>
                </el-form-item>
              </details>
            </el-form>
          </section>

          <section v-if="tab === 'skills'" class="ops-skills">
            <aside class="ops-card ops-skill-list"><h2>{{ $t("已添加的能力") }}</h2><p class="ops-hint">{{ $t(form.skills.length) }}{{ $t(" 项已添加 · ") }}{{ $t(enabledSkills.length) }}{{ $t(" 项启用") }}</p><el-button class="ops-add-capability" :icon="Plus" :disabled="busy || !missingSkills.length" @click="capabilityPicker = true">{{ $t("添加能力") }}{{ $t((missingSkills.length ? ($t("（") + String(missingSkills.length) + $t("）")) : '')) }}</el-button><button v-for="skill in form.skills" :key="skill.code" type="button" :class="{ selected: selectedSkill === skill.code }" :aria-pressed="selectedSkill === skill.code" @click="selectedSkill = skill.code"><span>{{ $t(skillName(skill.code)) }}</span><span class="ops-pill" :class="{ muted: !skill.enabled }">{{ $t((skill.enabled ? $t('已启用') : $t('已停用'))) }}</span></button><p class="ops-hint">{{ $t("从能力库逐项添加。停用保留配置，移除后仍可重新添加。") }}</p></aside>
            <div v-if="selectedPolicy && selectedInfo" class="ops-card">
              <div class="ops-section-head"><div><h2>{{ $t(selectedInfo.name) }}</h2><p>{{ $t(selectedInfo.description) }}</p></div><el-switch :model-value="selectedPolicy.enabled" @change="changeSkill(selectedPolicy!.code, $event ? 'enable' : 'disable')" :disabled="busy || selectedPolicy.code === 'general' || (!selectedPolicy.enabled && selectedInfo.sourceStatus === 'disabled')" :aria-label="$t(($t('启用') + String(selectedInfo.name) + $t('')))" /></div>
              <div class="ops-capability-meta"><el-tag>{{ $t(kindLabel(selectedInfo)) }}</el-tag><span>{{ $t(selectedInfo.version) }}</span><span v-if="selectedInfo.toolServer">{{ $t("服务：") }}{{ $t(selectedInfo.toolServer) }}</span></div>
              <el-alert v-if="selectedInfo.sourceStatus === 'disabled'" :title='$t("源技能已停用，请停用或移除当前草稿中的这项能力")' type="warning" :closable="false" />
              <el-form label-position="top" :disabled="busy" @submit.prevent>
                <el-form-item :label='$t("技能说明与回答规则")'><el-input v-model="selectedPolicy.prompt" type="textarea" :rows="9" maxlength="5000" show-word-limit :aria-label='$t("技能回答规则")' /></el-form-item>
                <el-form-item :label='$t("允许此智能体调用工具")'><div class="ops-tool-row"><el-switch v-model="selectedPolicy.useTool" :disabled="!selectedInfo.toolAvailable || !selectedPolicy.enabled" :aria-label='$t("使用计算工具")' /><strong>{{ $t((selectedInfo.toolName || $t('此技能不需要外部计算工具'))) }}</strong><el-tag v-if="selectedInfo.einoSupported" size="small" type="info">{{ $t("支持 Harness 调用") }}</el-tag></div><span class="ops-hint">{{ $t("关闭后，此智能体不再调用该技能的计算工具；需要计算依据的专题将无法生成。请在单次调试中验证工具连通性。") }}</span></el-form-item>
              </el-form>
              <p v-if="selectedInfo.sourceRef" class="ops-hint">{{ $t("来源：") }}{{ $t(selectedInfo.sourceRef) }}</p>
              <h3>{{ $t("输入资料要求") }}</h3><p class="ops-hint">{{ $t("随发布版本固定，来自已接入技能的输入契约。") }}</p>
              <el-table :data="selectedInfo.inputSchema.fields || []" :empty-text='$t("无需结构化资料")'><el-table-column :label='$t("资料")'><template #default="{ row }">{{ $t((row.label || row.key)) }}</template></el-table-column><el-table-column prop="type" :label='$t("类型")' width="120" /><el-table-column :label='$t("要求")' width="110"><template #default="{ row }">{{ $t((row.required ? $t('必填') : $t('按需填写'))) }}</template></el-table-column></el-table>
              <div class="ops-capability-footer"><span class="ops-hint">{{ $t((selectedPolicy.code === 'general' ? $t('日常问事是必要的兜底能力，保持启用。') : $t('移除只影响当前智能体草稿，源能力与历史报告保留。'))) }}</span><el-button v-if="selectedPolicy.code !== 'general'" type="danger" plain :icon="Delete" :disabled="busy" @click="changeSkill(selectedPolicy!.code, 'remove')">{{ $t("移除能力") }}</el-button></div>
            </div>
            <el-empty v-else class="ops-card" :description='$t("选择一项能力查看配置")' />
          </section>

          <el-drawer v-model="capabilityPicker" :title='$t("添加能力")' size="min(580px, 100vw)" append-to-body>
            <p class="ops-hint">{{ $t("从已接入能力库添加到当前智能体。添加后保存草稿、完成评测并发布。") }}</p>
            <el-input v-model="capabilitySearch" :prefix-icon="Search" clearable :placeholder='$t("搜索名称、工具或服务")' :aria-label='$t("搜索能力")' />
            <el-radio-group v-model="capabilityFilter" class="ops-capability-filters" :aria-label='$t("能力类型")'><el-radio-button value="all">{{ $t("全部") }}</el-radio-button><el-radio-button value="mcp">{{ $t("MCP 工具") }}</el-radio-button><el-radio-button value="builtin">{{ $t("内置工具") }}</el-radio-button><el-radio-button value="skill">{{ $t("业务技能") }}</el-radio-button></el-radio-group>
            <el-empty v-if="!availableCapabilities.length" :description="$t((missingSkills.length ? $t('没有匹配的能力') : $t('能力库中的项目均已添加')))" />
            <article v-for="info in availableCapabilities" :key="info.code" class="ops-library-item"><div><strong>{{ $t(info.name) }}</strong><el-tag size="small">{{ $t(kindLabel(info)) }}</el-tag><p>{{ $t(info.description) }}</p><small>{{ $t((info.toolServer ? ($t("") + String(info.toolServer) + $t(" / ")) : '')) }}{{ $t((info.toolName || info.code)) }} · {{ $t(info.version) }}</small></div><el-button :disabled="busy || info.sourceStatus === 'disabled'" :aria-label="$t(($t('添加') + String(info.name) + $t('')))" @click="addSkill(info)">{{ $t((info.sourceStatus === 'disabled' ? $t('源已停用') : $t('添加'))) }}</el-button></article>
          </el-drawer>
        </div>

        <section class="ops-debug-grid" :class="{ 'is-preview': editing }" :aria-label='$t(editing ? "调试预览" : "调试输入")'>
          <div class="ops-card ops-debug-input">
            <div class="ops-preview-head">
              <el-icon aria-hidden="true"><VideoPlay /></el-icon>
              <div>
                <h2>{{ $t(editing ? "调试预览" : "调试输入") }}</h2>
                <p>{{ $t("使用已保存的草稿，试跑可能产生模型费用。") }}</p>
              </div>
            </div>
            <el-alert v-if="draftNeedsSave && !pending" :title='$t("请先保存草稿，再开始调试")' type="info" :closable="false" />
            <el-form label-position="top" @submit.prevent>
              <div class="ops-grid ops-debug-selects">
                <el-form-item :label='$t("技能")'>
                  <el-select v-model="debug.skillCode" :disabled="inProgress || pending || debugBusy" :aria-label='$t("调试技能")'>
                    <el-option v-for="s in enabledSkills" :key="s.code" :value="s.code" :label="$t(skillName(s.code))" />
                  </el-select>
                </el-form-item>
                <el-form-item :label='$t("执行方式")'>
                  <el-select v-model="debug.kind" :disabled="inProgress || pending || debugBusy" :aria-label='$t("执行方式")'>
                    <el-option value="harness" :label='$t("用户端 Harness")' />
                    <el-option value="classic" :label='$t("原问事流程")' />
                    <el-option value="eino" :label='$t("Eino 多步验证")' :disabled="!einoAvailable" />
                  </el-select>
                </el-form-item>
              </div>
              <el-form-item :label='$t("测试问题")'>
                <el-input v-model="debug.question" type="textarea" :rows="3" maxlength="1500"
                  :disabled="inProgress || pending" :aria-label='$t("测试问题")' />
              </el-form-item>
              <div v-if="debugFields.length" class="ops-debug-data">
                <div class="ops-data-head">
                  <h3>{{ $t("结构化资料") }}</h3>
                  <el-button text :disabled="inProgress || debugBusy" @click="sample">{{ $t("填入合成示例") }}</el-button>
                </div>
                <div class="ops-grid">
                  <el-form-item v-for="field in debugFields" :key="field.key" :label="$t(field.label || field.key)" :required="field.required">
                    <el-select v-if="field.options?.length" v-model="inputValues[field.key]" clearable
                      :disabled="inProgress || debugBusy" :aria-label="$t(field.label || field.key)">
                      <el-option v-for="o in field.options" :key="o.value" :value="o.value" :label="$t(o.label || o.value)" />
                    </el-select>
                    <el-input v-else v-model="inputValues[field.key]" :disabled="inProgress || debugBusy" :aria-label="$t(field.label || field.key)"
                      :type="field.type === 'floorplan' ? 'textarea' : field.type === 'datetime' ? 'datetime-local' : field.type === 'date' && inputValues.calendarType === 'lunar' ? 'text' : field.type"
                      :min="field.min" :max="field.max" :step="field.validation === 'integer' ? 1 : 'any'"
                      :placeholder="$t(field.type === 'date' ? 'YYYY-MM-DD' : field.type === 'time' ? 'HH:mm' : '填写测试资料')"
                      :maxlength="field.type === 'floorplan' ? 20000 : 500" />
                    <span v-if="field.helpText" class="ops-hint">{{ $t(field.helpText) }}</span>
                  </el-form-item>
                </div>
              </div>
              <template v-if="pending">
                <el-alert :title="$t(run?.clarification || '请补充资料后继续')" type="warning" :closable="false" />
                <p class="ops-hint">{{ $t(workspace.persistentRecovery ? '待补充任务加密保存 24 小时，可从运行记录恢复。' : '未配置恢复密钥；服务重启后需重新开始调试。') }}</p>
              </template>
              <div class="ops-debug-actions">
                <template v-if="pending">
                  <el-button type="primary" :loading="debugBusy" @click="resumeDebug">{{ $t("补充并继续") }}</el-button>
                  <el-button :disabled="debugBusy" @click="cancelDebug">{{ $t("结束本次调试") }}</el-button>
                </template>
                <el-button v-else type="primary" :icon="VideoPlay" :loading="debugBusy || inProgress"
                  :disabled="draftNeedsSave || !debug.skillCode || !debug.question.trim() || busy" @click="startDebug">
                  {{ $t(inProgress ? '正在执行' : '开始调试') }}
                </el-button>
                <el-button v-if="run" text :icon="Refresh" @click="refreshRun">{{ $t("获取状态") }}</el-button>
              </div>
            </el-form>
          </div>
          <div class="ops-card ops-debug-result" aria-live="polite">
            <div class="ops-result-head">
              <h2>{{ $t("执行结果") }}</h2>
              <el-tag v-if="run" :type="run.status === 'completed' ? 'success' : run.status === 'failed' ? 'danger' : 'info'">
                {{ $t(statusText(run.status)) }}
              </el-tag>
            </div>
            <el-alert v-if="pollError" :title="$t(pollError)" type="error" :closable="false" />
            <template v-if="run">
              <p class="ops-result-meta">{{ $t("草稿 r") }}{{ run.revision }} · {{ run.model }}</p>
              <el-alert v-if="run.error" :title="$t(run.error)" type="error" :closable="false" />
              <pre v-if="run.result" class="ops-answer">{{ run.result }}</pre>
              <details v-if="run.events.length" class="ops-advanced ops-trace" :open="!editing">
                <summary>{{ $t("执行轨迹") }} · {{ run.events.length }}</summary>
                <ol class="ops-events">
                  <li v-for="(event, index) in run.events" :key="index">
                    <span class="ops-event-dot" />
                    <div>{{ $t(event.label) }}<time>{{ timeText(event.at) }}</time></div>
                  </li>
                </ol>
              </details>
              <div class="ops-run-counts">
                <span>{{ $t("模型尝试 ") }}{{ run.modelAttempts }}</span>
                <span>{{ $t("工具尝试 ") }}{{ run.toolAttempts }}</span>
                <span v-if="run.promptTokens == null">{{ $t("Token 用量暂未采集") }}</span>
                <span v-else>{{ $t("输入 ") }}{{ run.promptTokens }}{{ $t(" / 输出 ") }}{{ run.completionTokens }} Token</span>
              </div>
            </template>
            <p v-else class="ops-result-empty">{{ $t("暂无调试结果") }}</p>
            <RouterLink v-if="run?.status === 'completed' && run.revision === workspace.revision && !draftNeedsSave"
              class="ops-field-link" :to="agentSectionPath('evaluation')">{{ $t("去评测") }}</RouterLink>
          </div>
        </section>
      </div>

      <section v-if="tab === 'evaluation'" class="ops-card">
        <div class="ops-section-head"><div><h2>{{ $t("可重复的质量检查") }}</h2><p>{{ $t("每个启用技能至少配置一条正常回答用例。仅填写合成资料，用例随版本保存；执行会调用模型和计算工具。") }}</p></div><el-button :disabled="busy || form.evaluation.length >= 100" @click="addCase">{{ $t("添加用例") }}</el-button></div>
        <p v-if="!form.evaluation.length" class="ops-empty">{{ $t("暂无评测用例") }}</p>
        <el-collapse>
          <el-collapse-item v-for="c in form.evaluation" :key="c.id" :name="c.id" :title="$t(($t('') + String(c.name) + $t(' · ') + String(skillName(c.skillCode)) + $t('')))">
            <el-form label-position="top" :disabled="busy" @submit.prevent>
              <div class="ops-grid"><el-form-item :label='$t("用例名称")'><el-input v-model="c.name" :aria-label='$t("用例名称")' maxlength="50" /></el-form-item><el-form-item :label='$t("验证技能")'><el-select v-model="c.skillCode" :aria-label='$t("评测技能")'><el-option v-for="s in enabledSkills" :key="s.code" :value="s.code" :label="$t(skillName(s.code))" /></el-select></el-form-item></div>
              <el-form-item :label='$t("测试问题")'><el-input v-model="c.question" :aria-label='$t("评测问题")' type="textarea" :rows="2" maxlength="1500" /></el-form-item>
              <el-form-item :label='$t("合成资料（JSON）")' :error="caseErrors[c.id]"><el-input :aria-label='$t("合成资料 JSON")' :model-value="caseInputs[c.id] ?? JSON.stringify(c.inputs, null, 2)" type="textarea" :rows="3" @update:model-value="(v: string) => editCaseInputs(c, v)" /></el-form-item>
              <el-form-item :label='$t("预期行为")'><el-switch v-model="c.expectInvalid" :aria-label='$t("预期拒绝无效资料")' active-text="无效资料应在调用前被拒绝" inactive-text="正常回答" /></el-form-item>
              <template v-if="!c.expectInvalid"><el-form-item :label='$t("最少输出字数")'><el-input-number v-model="c.minChars" :aria-label='$t("最低输出字数")' :min="20" :max="2000" /></el-form-item><div class="ops-grid"><el-form-item :label='$t("必须包含（每行一项，可留空）")'><el-input :aria-label='$t("必须包含内容")' :model-value="c.contains.join('\n')" type="textarea" @update:model-value="(v: string) => c.contains = v.split('\n').filter(t => t.trim())" /></el-form-item><el-form-item :label='$t("不得包含（每行一项，可留空）")'><el-input :aria-label='$t("不得包含内容")' :model-value="c.excludes.join('\n')" type="textarea" @update:model-value="(v: string) => c.excludes = v.split('\n').filter(t => t.trim())" /></el-form-item></div></template>
              <el-button type="danger" text @click="removeCase(c.id)">{{ $t("移除此用例") }}</el-button>
            </el-form>
          </el-collapse-item>
        </el-collapse>
        <div class="ops-debug-actions"><el-button type="primary" :loading="evalBusy || evaluation?.status === 'running'" :disabled="dirty || !workspace.draftSaved || !form.evaluation.length || !!Object.keys(caseErrors).length" @click="startEvaluation">{{ $t("运行评测集") }}</el-button><el-button @click="loadEvaluations">{{ $t("刷新记录") }}</el-button><el-button v-if="evaluation" text @click="pollEvaluation(evaluation.id)">{{ $t("获取本次状态") }}</el-button></div>
        <p v-if="draftNeedsSave" class="ops-hint">{{ $t("保存当前草稿后才能运行评测。") }}</p>
        <p class="ops-hint">{{ $t("通过结果在 24 小时内可发布。修改草稿或模型连接后需重新评测。单组最多 100 条，最长 30 分钟。") }}</p>
        <el-alert v-if="evalError" :title="$t(evalError)" type="error" :closable="false" />
        <template v-if="evaluation"><h3>{{ $t("本次评测 · ") }}{{ $t(statusText(evaluation.status)) }} · {{ $t(evaluation.results.length) }}/{{ $t(evaluation.total) }}</h3><el-alert v-if="evaluation.error" :title="$t(evaluation.error)" type="error" :closable="false" /><el-table :data="evaluation.results"><el-table-column prop="name" :label='$t("用例")' min-width="160" /><el-table-column :label='$t("结果")' width="90"><template #default="{ row }"><el-tag :type="row.passed ? 'success' : 'danger'">{{ $t((row.passed ? $t('通过') : $t('未通过'))) }}</el-tag></template></el-table-column><el-table-column :label='$t("检查详情")' min-width="220"><template #default="{ row }">{{ $t((row.checks.join('；') || $t('全部断言通过'))) }}</template></el-table-column><el-table-column :label='$t("耗时")' width="90"><template #default="{ row }">{{ $t((row.latencyMs / 1000).toFixed(1)) }}s</template></el-table-column></el-table></template>
        <h3>{{ $t("最近评测") }}</h3><el-table :data="evaluations" :empty-text='$t("暂无评测记录")'><el-table-column :label='$t("草稿")' width="100"><template #default="{ row }">r{{ $t(row.revision) }}</template></el-table-column><el-table-column :label='$t("状态")' width="120"><template #default="{ row }">{{ $t(statusText(row.status)) }}</template></el-table-column><el-table-column :label='$t("时间")' min-width="180"><template #default="{ row }">{{ $t(timeText(row.startedAt)) }}</template></el-table-column><el-table-column :label='$t("操作")' width="90"><template #default="{ row }"><el-button link @click="evaluation = row; pollEvaluation(row.id)">{{ $t("查看") }}</el-button></template></el-table-column></el-table>
      </section>

      <section v-if="tab === 'runs'" class="ops-card">
        <div class="ops-section-head"><div><h2>{{ $t("执行记录") }}</h2><p>{{ $t("用户问事与管理员调试分别查看，默认隐藏原始资料和对话正文。") }}</p></div><el-button :icon="Refresh" :loading="recordsLoading" @click="loadRecords">{{ $t("刷新") }}</el-button></div>
        <div class="ops-record-filters"><el-radio-group v-model="recordKind"><el-radio-button value="production">{{ $t("用户问事") }}</el-radio-button><el-radio-button value="debug">{{ $t("后台调试") }}</el-radio-button></el-radio-group><el-select v-if="recordKind === 'production'" v-model="status" clearable :placeholder='$t("全部状态")' :aria-label='$t("运行状态")' @change="changeStatus"><el-option v-for="s in ['completed', 'failed', 'running']" :key="s" :value="s" :label="$t(statusText(s))" /></el-select></div>
        <el-alert v-if="recordsError" :title="$t(recordsError)" type="error" :closable="false" />
        <el-table v-else-if="recordKind === 'production'" :data="records" v-loading="recordsLoading" :empty-text='$t("暂无问事执行记录")'><el-table-column prop="runNo" :label='$t("运行编号")' min-width="200" /><el-table-column :label='$t("技能 / 版本")' min-width="170"><template #default="{ row }">{{ $t(skillName(row.skillCode)) }}<small class="ops-cell-sub">{{ $t(row.skillVersion) }}</small></template></el-table-column><el-table-column prop="model" :label='$t("模型")' min-width="160" /><el-table-column :label='$t("状态")' width="100"><template #default="{ row }">{{ $t(statusText(row.status)) }}</template></el-table-column><el-table-column :label='$t("耗时")' width="100"><template #default="{ row }">{{ $t((row.status === 'running' ? '—' : ($t("") + String((row.latencyMs / 1000).toFixed(1)) + $t("s")))) }}</template></el-table-column><el-table-column :label='$t("输入 / 输出 Token")' width="155"><template #default="{ row }">{{ $t(row.promptTokens) }} / {{ $t(row.completionTokens) }}</template></el-table-column><el-table-column :label='$t("操作")' width="110" fixed="right"><template #default="{ row }"><el-button link type="primary" @click="showTools(row)">{{ $t("工具轨迹") }}</el-button></template></el-table-column></el-table>
        <el-table v-else :data="debugRecords" v-loading="recordsLoading" :empty-text='$t("暂无后台调试记录")'><el-table-column :label='$t("时间")' min-width="180"><template #default="{ row }">{{ $t(timeText(row.startedAt)) }}</template></el-table-column><el-table-column :label='$t("草稿")' width="90"><template #default="{ row }">r{{ $t(row.revision) }}</template></el-table-column><el-table-column :label='$t("技能")' min-width="130"><template #default="{ row }">{{ $t(skillName(row.skillCode)) }}</template></el-table-column><el-table-column :label='$t("方式")' width="120"><template #default="{ row }">{{ $t((row.kind === 'harness' ? $t('用户端 Harness') : (row.kind === 'eino' ? $t('Eino 验证') : $t('原问事流程')))) }}</template></el-table-column><el-table-column :label='$t("状态")' width="120"><template #default="{ row }">{{ $t(statusText(row.status)) }}</template></el-table-column><el-table-column :label='$t("操作")' width="100"><template #default="{ row }"><el-button link type="primary" @click="showDebug(row)">{{ $t("查看详情") }}</el-button></template></el-table-column></el-table>
        <div v-if="recordKind === 'production'" class="ops-pagination"><el-button :disabled="page === 1 || recordsLoading" @click="page--">{{ $t("上一页") }}</el-button><span>{{ $t("第 ") }}{{ $t(page) }}{{ $t(" 页") }}</span><el-button :disabled="!hasMore || recordsLoading" @click="page++">{{ $t("下一页") }}</el-button></div>
      </section>

      <section v-if="tab === 'versions'" class="ops-release">
        <div class="ops-release-summary">
          <section class="ops-card ops-release-check">
            <h2>{{ $t("发布问事智能体") }}</h2>
            <p class="ops-hint">{{ $t("将通过评测的草稿发布为新版本，初始覆盖 0%。") }}</p>
            <dl v-if="workspace.draftSaved" class="ops-release-model">
              <dt>{{ $t("已保存草稿的聊天模型") }}</dt>
              <dd>{{ $t(savedChatModel) }}</dd>
            </dl>
            <p v-if="publishBlock" class="ops-publish-block" role="status">
              {{ $t(publishBlock) }}
              <RouterLink v-if="!draftNeedsSave" :to="agentSectionPath('evaluation')">{{ $t("去评测") }}</RouterLink>
            </p>
            <el-button type="primary" :icon="Check" :disabled="!!publishBlock || busy" @click="publish">{{ $t("发布当前草稿") }}</el-button>
          </section>
          <section class="ops-card ops-traffic">
            <h2>{{ $t("版本覆盖") }}</h2>
            <el-alert v-if="!workspace.liveEnabled" :title='$t("版本配置接管尚未开启；当前执行引擎不受此开关影响")' type="info" :closable="false" />
            <div v-if="workspace.rollout.versionId" class="ops-traffic-state">
              <strong>{{ workspace.rollout.percentage }}<small>%</small></strong>
              <div>
                <span>{{ $t("候选版本") }} v{{ workspace.rollout.versionId }}</span>
                <p v-if="workspace.rollout.percentage === 100">{{ $t("当前覆盖全部账号") }}</p>
                <p v-else>{{ $t("其余账号使用") }}{{ workspace.rollout.stableVersion ? $t("稳定版本 v") + workspace.rollout.stableVersion : $t("原始配置") }}{{ $t("。比例按账号固定分配。") }}</p>
              </div>
            </div>
            <p v-else class="ops-hint">{{ $t("暂无候选版本") }}</p>
            <div class="ops-rollout-actions">
              <el-button v-for="percent in [0, 10, 25, 50, 100]" :key="percent"
                :type="workspace.rollout.percentage === percent ? 'primary' : 'default'"
                :disabled="busy || dirty || !workspace.liveEnabled || !workspace.rollout.versionId || workspace.rollout.percentage === percent"
                @click="setRollout(percent)">{{ percent }}%</el-button>
            </div>
          </section>
        </div>
        <section class="ops-card ops-release-history">
          <h2>{{ $t("历史版本") }}</h2>
          <el-table :data="workspace.versions" :empty-text='$t("尚无发布版本")'><el-table-column :label='$t("版本")' width="150"><template #default="{ row }"><strong>v{{ $t(row.id) }}</strong><el-tag v-if="row.id === workspace.activeVersion" size="small" class="ops-version-tag">{{ $t('候选版本') }}</el-tag></template></el-table-column><el-table-column prop="note" :label='$t("发布说明")' min-width="240" /><el-table-column prop="actor" :label='$t("操作人")' width="100" /><el-table-column prop="createdAt" :label='$t("时间")' min-width="180" /><el-table-column :label='$t("操作")' width="190"><template #default="{ row }"><el-button link type="primary" :disabled="busy" @click="showVersion(row.id)">{{ $t("查看配置") }}</el-button><el-button link type="primary" :disabled="row.id === workspace.activeVersion || busy || dirty" @click="rollback(row.id)">{{ $t("回滚到此版") }}</el-button></template></el-table-column></el-table>
          <div class="ops-fallback"><div><h3>{{ $t("原始问事配置") }}</h3><p>{{ $t("恢复到本次运营管理接入前的技能配置来源。") }}</p></div><el-button :disabled="!workspace.activeVersion || busy || dirty" @click="rollback(0)">{{ $t("恢复原配置") }}</el-button></div>
          <h3>{{ $t("最近操作") }}</h3><el-table :data="workspace.audit" :empty-text='$t("尚无操作记录")'><el-table-column :label='$t("操作")' width="100"><template #default="{ row }">{{ $t((({ save: '保存草稿', publish: '发布', rollback: '回滚', rollout: '调整比例' } as Record<string, string>)[row.action] || row.action)) }}</template></el-table-column><el-table-column prop="note" :label='$t("说明")' min-width="200" /><el-table-column prop="actor" :label='$t("操作人")' width="100" /><el-table-column prop="createdAt" :label='$t("时间")' min-width="180" /></el-table>
        </section>
      </section>

    </template>
    <el-dialog v-model="versionDialog" :title="$t(($t('版本 v') + String(versionNumber) + $t(' · 已发布配置')))" width="min(760px, 94vw)" append-to-body>
      <template v-if="versionConfig"><h3>{{ $t(versionConfig.name) }}</h3><p class="ops-hint">{{ $t(versionConfig.model) }}{{ $t(" · 最多 ") }}{{ $t(versionConfig.maxOutputTokens) }} Token</p><pre class="ops-answer">{{ $t(versionConfig.instruction) }}</pre><el-collapse><el-collapse-item v-for="skill in versionConfig.skills" :key="skill.code" :name="skill.code" :title="$t(($t('') + String(skillName(skill.code)) + $t(' · ') + String((skill.enabled ? $t('启用') : $t('停用'))) + $t(' · ') + String((skill.useTool ? $t('使用计算工具') : $t('不使用工具'))) + $t('')))"><pre class="ops-answer">{{ $t(skill.prompt) }}</pre></el-collapse-item></el-collapse></template>
    </el-dialog>
    <el-drawer v-model="drawer" :title='$t("工具执行轨迹")' size="min(520px, 100vw)" append-to-body><div v-loading="toolsLoading"><p>{{ $t(detailRun?.runNo) }}</p><p class="ops-hint">{{ $t(detailRun?.skillVersion) }} · {{ $t(detailRun?.model) }}</p><el-alert v-if="toolsError" :title="$t(toolsError)" type="error" :closable="false" /><el-empty v-else-if="!toolsLoading && !tools.length" :description='$t("本次没有计算工具调用")' /><ol v-else class="ops-events"><li v-for="(tool, i) in tools" :key="i"><span class="ops-event-dot" /><div><strong>{{ $t(tool.name) }}</strong><p>{{ $t(statusText(tool.status)) }} · {{ $t(tool.latencyMs) }} ms</p><time>{{ $t(timeText(tool.createdAt)) }}</time></div></li></ol></div></el-drawer>
  </div>
</template>

<style scoped>
.ops-capability-meta{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-bottom:20px;color:var(--el-text-color-secondary);font-size:13px}.ops-capability-footer{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;margin-top:24px;padding-top:16px;border-top:1px solid var(--el-border-color-light)}.ops-capability-filters{display:flex;flex-wrap:wrap;margin:16px 0}.ops-library-item{display:flex;align-items:flex-start;gap:16px;padding:20px 0;border-bottom:1px solid var(--el-border-color-light)}.ops-library-item>div{flex:1;min-width:0}.ops-library-item strong{margin-right:10px}.ops-library-item p{font-size:13px;line-height:1.7;color:var(--el-text-color-secondary)}.ops-library-item small{overflow-wrap:anywhere;color:var(--el-text-color-secondary)}.ops-add-capability{margin:8px 0}

.ops-rollout-actions{display:flex;gap:6px;flex-wrap:wrap}.ops-rollout-actions .el-button{margin-left:0}.ops-section-head p,.ops-fallback p{margin:7px 0 0;color:var(--el-text-color-secondary);font-size:13px;line-height:1.6}.ready{color:var(--el-color-success)}.ops-skill-list button:focus-visible{outline:2px solid var(--el-color-primary);outline-offset:-3px}.ops-card{background:var(--el-bg-color);border:1px solid var(--studio-line);border-radius:12px;padding:22px;min-width:0}.ops-card h2{font-size:17px;margin:0 0 8px}.ops-card h3,.ops-fallback h3{font-size:14px;margin:14px 0 8px}.ops-section-head{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;margin-bottom:22px}.ops-section-head a{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--el-color-primary);white-space:nowrap}.ops-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:0 20px}.ops-hint{display:block;color:var(--el-text-color-secondary);font-size:12px;line-height:1.7;margin-top:8px}.ops-skills{display:grid;grid-template-columns:240px minmax(0,1fr);gap:20px}.ops-skill-list{padding:20px 12px;align-self:start}.ops-skill-list h2{padding:0 12px 12px}.ops-skill-list button{display:flex;align-items:center;justify-content:space-between;gap:10px;width:100%;border:0;background:transparent;color:var(--el-text-color-primary);padding:13px 12px;border-radius:9px;cursor:pointer;text-align:left;font:inherit;font-size:13px}.ops-skill-list button.selected{background:var(--el-color-primary-light-9);color:var(--el-color-primary)}.ops-pill{font-size:11px;color:var(--el-color-success);white-space:nowrap}.ops-pill.muted{color:var(--el-text-color-placeholder)}.ops-tool-row{display:flex;align-items:center;gap:12px;flex-wrap:wrap}.ops-empty{text-align:center;color:var(--el-text-color-secondary);padding:32px 12px}.ops-answer{font-family:inherit;white-space:pre-wrap;overflow-wrap:anywhere;font-size:14px;line-height:1.9;padding:18px;background:var(--el-fill-color-light);border-radius:10px;max-height:460px;overflow:auto}.ops-events{list-style:none;margin:20px 0;padding:0}.ops-events li{display:flex;gap:12px;padding:0 0 20px;position:relative;font-size:13px}.ops-event-dot{width:8px;height:8px;flex-shrink:0;border-radius:50%;background:var(--el-color-primary);margin-top:5px}.ops-events li:not(:last-child):before{content:'';position:absolute;left:3px;top:15px;bottom:3px;width:1px;background:var(--el-border-color-light)}.ops-events time{display:block;color:var(--el-text-color-placeholder);font-size:11px;margin-top:5px}.ops-run-counts{display:flex;gap:14px;flex-wrap:wrap;font-size:12px;color:var(--el-text-color-secondary);border-top:1px solid var(--el-border-color-light);padding-top:14px}.ops-record-filters{display:flex;gap:16px;margin:16px 0 20px;flex-wrap:wrap}.ops-record-filters>.el-select{width:160px}.ops-cell-sub{display:block;color:var(--el-text-color-secondary);font-size:11px}.ops-pagination{display:flex;align-items:center;justify-content:flex-end;gap:14px;margin-top:20px;font-size:13px}.ops-fallback{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:18px 0;margin:16px 0;border-bottom:1px solid var(--el-border-color-light)}.ops-version-tag{margin-left:8px}.is-dirty{color:var(--el-color-warning)}.ops-card :deep(.el-select){width:100%}.ops-card :deep(.el-form-item__content > .ops-hint){flex-basis:100%}.ops-card :deep(.el-alert){margin-bottom:16px}.ops-card :deep(.el-input-number){width:180px}.ops-skill-list button{transition:background-color 140ms ease,color 140ms ease}@media(max-width:1000px){.ops-skills{grid-template-columns:200px minmax(0,1fr)}}@media(max-width:640px){.ops-skills,.ops-grid{grid-template-columns:1fr}.ops-skill-list{max-height:240px;overflow:auto}.ops-card{padding:18px}.ops-section-head{flex-wrap:wrap}}@media(prefers-reduced-motion:reduce){.ops-skill-list button{transition:none}}

.agent-ops.dfx-page {
  container: agent-workspace / inline-size;
  padding-block-start: 6px !important;
}
.ops-page-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px 18px;
  flex-wrap: wrap;
  margin: 10px 0 16px;
}
.ops-page-head h1 {
  margin: 0;
  color: var(--el-text-color-primary);
  font-family: var(--font-sans, inherit);
  font-size: clamp(20px, 1.7vw, 26px);
  font-weight: 650;
  line-height: 1.35;
}
.ops-context, .ops-context dl, .ops-heading-actions {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  min-width: 0;
}
.ops-context { gap: 6px 14px }
.ops-context dl { gap: 6px 14px; margin: 0; font-size: 12px }
.ops-context dl > div { display: flex; align-items: baseline; gap: 5px }
.ops-context dt { color: var(--studio-muted); white-space: nowrap }
.ops-context dd { margin: 0; font-weight: 600; overflow-wrap: anywhere }
.ops-heading-actions { gap: 6px; min-height: 36px }
.ops-heading-actions .el-button { margin-inline-start: 0 }
.ops-heading-link {
  display: inline-flex;
  align-items: center;
  min-height: 36px;
  padding-inline: 10px;
  border: 1px solid var(--studio-line);
  border-radius: 7px;
  background: var(--studio-surface);
  color: var(--el-color-primary);
  font-size: 13px;
  font-weight: 600;
  text-decoration: none;
}
.ops-heading-link:hover { background: var(--studio-tint) }
.ops-heading-link:focus-visible {
  outline: 2px solid var(--el-color-primary);
  outline-offset: 2px;
}
.ops-workspace, .ops-editor { min-width: 0 }
.ops-config .ops-prompt :deep(.el-textarea__inner) {
  padding: 14px 15px 26px;
  font: inherit;
  line-height: 1.85;
  background: color-mix(in srgb, var(--studio-surface) 78%, var(--el-fill-color-light));
}
.ops-config .ops-prompt :deep(.el-form-item__label) {
  color: var(--el-text-color-primary);
  font-weight: 650;
}
.ops-model-field :deep(.el-form-item__label) {
  display: flex;
  justify-content: space-between;
  gap: 8px;
}
.ops-model-field .ops-field-link {
  min-height: 22px;
  text-decoration: none;
}
.ops-debug-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 16px;
  align-items: start;
  min-width: 0;
}
.ops-debug-grid.is-preview { display: none }
.ops-preview-head, .ops-data-head, .ops-result-head {
  display: flex;
  align-items: center;
  gap: 10px;
}
.ops-preview-head { margin-bottom: 18px }
.ops-preview-head > .el-icon {
  flex: none;
  width: 34px;
  height: 34px;
  border-radius: 8px;
  background: var(--studio-tint);
  color: var(--el-color-primary);
  font-size: 19px;
}
.ops-preview-head h2, .ops-result-head h2, .ops-data-head h3 { margin: 0 }
.ops-preview-head p, .ops-result-meta, .ops-result-empty {
  color: var(--studio-muted);
  font-size: 13px;
  line-height: 1.55;
}
.ops-preview-head p { margin: 4px 0 0 }
.ops-data-head, .ops-result-head { justify-content: space-between }
.ops-debug-data { border-top: 1px solid var(--studio-line); padding-top: 8px }
.ops-debug-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 4px;
}
.ops-debug-actions .el-button { margin-inline-start: 0 }
.ops-debug-input :deep(.el-form-item) { margin-bottom: 16px }
.ops-debug-input .ops-debug-selects { gap: 0 12px }
.ops-result-meta { margin: 8px 0 12px; overflow-wrap: anywhere }
.ops-result-empty { margin: 26px 0; text-align: center }
.ops-debug-result .ops-answer { margin: 12px 0; padding: 12px 14px }
.ops-trace[open] .ops-events { margin-top: 6px }
.ops-trace .ops-events li { padding-bottom: 13px }
.ops-trace .ops-events li:last-child { padding-bottom: 0 }

@container agent-workspace (min-width: 760px) {
  .ops-debug-grid { grid-template-columns: repeat(2, minmax(0, 1fr)) }
}
@container agent-workspace (min-width: 965px) {
  .ops-workspace.has-preview {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(345px, .64fr);
    gap: 16px;
    align-items: start;
  }
  .ops-workspace.has-preview .ops-skills { grid-template-columns: minmax(146px, .38fr) minmax(0, 1fr); gap: 12px }
  .ops-debug-grid.is-preview {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: 0;
    border: 1px solid var(--studio-line);
    border-radius: 12px;
    background: var(--studio-surface);
  }
  .ops-debug-grid.is-preview .ops-card { padding: 18px; border: 0; border-radius: 0; background: transparent }
  .ops-debug-grid.is-preview .ops-debug-result {
    border-top: 1px solid var(--studio-line);
    border-radius: 0 0 11px 11px;
    background: color-mix(in srgb, var(--studio-surface) 68%, var(--el-fill-color-lighter));
  }
  .ops-debug-grid.is-preview .ops-result-head h2 { font-size: 15px }
  .ops-debug-grid.is-preview .ops-result-empty { margin-block: 18px }
}
.ops-release-model {
  display: grid;
  gap: 5px;
  margin: 18px 0 14px;
  font-size: 13px;
}
.ops-release-model dt { color: var(--studio-muted) }
.ops-release-model dd { margin: 0; font-weight: 650; overflow-wrap: anywhere }
.ops-release, .ops-release-summary { display: grid; gap: 14px; min-width: 0 }
.ops-release-summary > section { min-width: 0 }
.ops-traffic-state { display: flex; align-items: center; gap: 14px; margin: 16px 0 }
.ops-traffic-state > strong {
  color: var(--el-color-primary);
  font-size: 32px;
  font-variant-numeric: tabular-nums;
  line-height: 1;
}
.ops-traffic-state small { font-size: 16px; margin-inline-start: 2px }
.ops-traffic-state span { font-size: 13px; font-weight: 650 }
.ops-traffic-state p { margin: 4px 0 0; color: var(--studio-muted); font-size: 12px; line-height: 1.6 }
.ops-release-history > h2 { margin-bottom: 16px }
@container agent-workspace (min-width: 760px) {
  .ops-release-summary { grid-template-columns: minmax(0, 1.18fr) minmax(0, 1fr) }
}
.ops-field-link, .ops-publish-block a {
  color: var(--el-color-primary);
  font-size: 13px;
  font-weight: 600;
  text-decoration: underline;
  text-underline-offset: 3px;
}
.ops-field-link { display: inline-flex; align-items: center; min-height: 32px }
.ops-field-link + .ops-hint { margin-top: 0 }
.ops-card :deep(.el-switch + .ops-field-link) { margin-left: 12px }
.ops-advanced { padding: 6px 0; border-top: 1px solid var(--el-border-color-light) }
.ops-advanced summary { padding: 12px 0; cursor: pointer; font-size: 14px; font-weight: 600 }
.ops-publish-block {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 8px 16px;
  margin: 0 0 16px;
  padding: 12px 14px;
  border-radius: 8px;
  background: var(--el-color-warning-light-9);
  font-size: 13px;
}
@media (max-width: 640px) {
  .ops-context { width: 100%; justify-content: space-between }
  .ops-context dl { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); width: 100% }
  .ops-heading-actions { margin-inline-start: auto }
  .ops-debug-input .ops-debug-selects { grid-template-columns: repeat(2, minmax(0, 1fr)) }
  .ops-context dd { overflow-wrap: anywhere }
  .ops-card :deep(.el-radio-group) { row-gap: 4px }
}
</style>
