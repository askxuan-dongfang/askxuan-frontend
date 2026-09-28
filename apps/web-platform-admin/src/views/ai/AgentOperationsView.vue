<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount, reactive, ref, watch } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Setting, Connection, VideoPlay, List, Clock, Refresh, Check, ArrowRight } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import { agentOperationsApi as api, type AgentWorkspace, type AgentConfig, type DebugRun, type ProductionRun, type ToolTrace } from '@/api/agentOperations'

const workspace = ref<AgentWorkspace>(), loading = ref(true), busy = ref(false), loadError = ref('')
const form = ref<AgentConfig>(), baseline = ref(''), tab = ref('config'), selectedSkill = ref('')
const models = ref<{ id: string; name: string }[]>([])
const sections = [{ id: 'config', name: '智能体配置', icon: Setting }, { id: 'skills', name: '技能与工具', icon: Connection }, { id: 'debug', name: '调试工作台', icon: VideoPlay }, { id: 'runs', name: '运行记录', icon: List }, { id: 'versions', name: '版本发布', icon: Clock }]
const dirty = computed(() => JSON.stringify(form.value) !== baseline.value)
const selectedPolicy = computed(() => form.value?.skills.find(s => s.code === selectedSkill.value))
const selectedInfo = computed(() => workspace.value?.catalog.find(s => s.code === selectedSkill.value))
const enabledSkills = computed(() => form.value?.skills.filter(s => s.enabled) || [])
const skillName = (code: string) => workspace.value?.catalog.find(s => s.code === code)?.name || code
const statuses: Record<string, string> = { running: '执行中', completed: '已完成', failed: '失败', awaiting_input: '待补充资料', expired: '已过期', cancelled: '已结束' }
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
    workspace.value = value; form.value = structuredClone(value.draft); baseline.value = JSON.stringify(form.value)
    if (!selectedSkill.value) selectedSkill.value = value.draft.skills[0]?.code || ''
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
  busy.value = true
  try { await api.save(workspace.value.revision, JSON.parse(JSON.stringify(form.value))); await load(); ElMessage.success('草稿已保存，请先调试后发布') }
  catch { /* keep editable draft on conflict or validation failure */ } finally { busy.value = false }
}
async function publish() {
  if (!workspace.value || dirty.value || !workspace.value.tested) return
  let note: string
  try { const value = await ElMessageBox.prompt(workspace.value.liveEnabled ? '发布后用于新问事请求，正在执行的请求保留原配置。' : '生成发布版本；服务器启用运营配置后才会用于用户问事。', '发布智能体配置', { inputPlaceholder: '说明本次调整内容', inputValidator: value => Boolean(value?.trim()) && value.length <= 500 || '请填写 1 至 500 字说明', confirmButtonText: '确认发布', cancelButtonText: '取消' }); note = value.value } catch { return }
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

const debug = reactive({ kind: 'classic', skillCode: '', question: '请根据这份测试资料，说明可以提供哪些有依据的参考。' })
const inputValues = reactive<Record<string, string>>({}), run = ref<DebugRun>(), debugBusy = ref(false), pollError = ref('')
const debugInfo = computed(() => workspace.value?.catalog.find(s => s.code === debug.skillCode))
const debugFields = computed(() => debugInfo.value?.inputSchema.fields || [])
const einoAvailable = computed(() => debugInfo.value?.einoSupported && form.value?.skills.find(s => s.code === debug.skillCode)?.useTool)
const inProgress = computed(() => run.value?.status === 'running')
const pending = computed(() => run.value?.status === 'awaiting_input')
let timer: ReturnType<typeof setTimeout> | undefined, pollGeneration = 0, disposed = false
watch(() => debug.skillCode, () => { Object.keys(inputValues).forEach(k => delete inputValues[k]); if (!einoAvailable.value) debug.kind = 'classic' })
function sample() {
  const values: Record<string, string> = { birthDate: '1990-01-02', birthTime: '12:30', gender: 'male', name: '测试用户', question: '合成资料验证' }
  for (const field of debugFields.value) if (values[field.key]) inputValues[field.key] = values[field.key]
}
function inputs() {
  const result: Record<string, unknown> = {}
  for (const field of debugFields.value) { const value = inputValues[field.key]?.trim(); if (value) result[field.key] = field.type === 'number' ? Number(value) : value }
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
onMounted(() => { window.addEventListener('beforeunload', beforeUnload); void load(); void api.models().then(v => { models.value = v.list }).catch(() => {}) })
onBeforeUnmount(() => { disposed = true; stopPoll(); recordGeneration++; window.removeEventListener('beforeunload', beforeUnload) })
</script>

<template>
  <div class="dfx-page agent-ops" v-loading="loading">
    <PageHeader title="智能体运营管理" subtitle="配置能力、验证效果，让每一次问事都有迹可循">
      <template #actions><el-button :icon="Refresh" :disabled="busy" @click="reload">重新加载</el-button></template>
    </PageHeader>
    <el-alert v-if="loadError" :title="loadError" type="error" :closable="false" show-icon><el-button text @click="reload">重试</el-button></el-alert>
    <template v-if="workspace && form">
      <section class="ops-overview" aria-label="发布状态">
        <div class="ops-identity"><span class="ops-symbol"><Connection /></span><div><strong>{{ workspace.active?.name || '问事助手' }}</strong><p>{{ workspace.liveEnabled ? (workspace.activeVersion ? `运行版本 v${workspace.activeVersion}` : '使用原始问事配置') : '运营配置尚未接管线上问事' }}</p></div></div>
        <div class="ops-stat"><span>草稿</span><strong>r{{ workspace.revision }}</strong></div>
        <div class="ops-stat"><span>已启用技能</span><strong>{{ enabledSkills.length }}</strong></div>
        <div class="ops-stat"><span>发布检查</span><strong :class="{ ready: workspace.tested && !dirty }">{{ dirty ? '有未保存修改' : workspace.tested ? '已通过基础调试' : '待调试' }}</strong></div>
      </section>
      <nav class="ops-tabs" aria-label="智能体管理模块"><button v-for="item in sections" :key="item.id" type="button" :aria-current="tab === item.id ? 'page' : undefined" :class="{ active: tab === item.id }" @click="tab = item.id"><el-icon><component :is="item.icon" /></el-icon>{{ item.name }}</button></nav>

      <section v-show="tab === 'config'" class="ops-card">
        <div class="ops-section-head"><div><h2>定义问事助手</h2><p>职责与技能共同决定回答方式。保存草稿不会立即改变用户端。</p></div><router-link to="/settings/ai">模型连接设置 <el-icon><ArrowRight /></el-icon></router-link></div>
        <el-form label-position="top" :disabled="busy" @submit.prevent="save">
          <div class="ops-grid"><el-form-item label="名称"><el-input v-model="form.name" maxlength="40" aria-label="智能体名称" /></el-form-item><el-form-item label="默认模型"><el-select v-model="form.model" filterable aria-label="智能体默认模型" placeholder="沿用模型设置中的默认值" clearable><el-option v-if="form.model && !models.some(m => m.id === form?.model)" :value="form.model" :label="form.model" /><el-option v-for="m in models" :key="m.id" :value="m.id" :label="m.name" /></el-select><span class="ops-hint">用于未主动选择模型的文字问事。</span></el-form-item></div>
          <el-form-item label="职责与回答要求"><el-input v-model="form.instruction" type="textarea" :rows="6" maxlength="2500" show-word-limit aria-label="职责与回答要求" /></el-form-item>
          <el-form-item label="单次回答输出上限"><el-input-number v-model="form.maxOutputTokens" :min="64" :max="4096" :step="128" aria-label="回答输出上限" /><span class="ops-hint">Token；同时受全局模型设置限制。Eino 调试最多输出 512 Token。</span></el-form-item>
        </el-form>
      </section>

      <section v-show="tab === 'skills'" class="ops-skills">
        <aside class="ops-card ops-skill-list"><h2>技能目录</h2><button v-for="skill in form.skills" :key="skill.code" type="button" :class="{ selected: selectedSkill === skill.code }" :aria-pressed="selectedSkill === skill.code" @click="selectedSkill = skill.code"><span>{{ skillName(skill.code) }}</span><span class="ops-pill" :class="{ muted: !skill.enabled }">{{ skill.enabled ? '已启用' : '已停用' }}</span></button></aside>
        <div v-if="selectedPolicy && selectedInfo" class="ops-card">
          <div class="ops-section-head"><div><h2>{{ selectedInfo.name }}</h2><p>{{ selectedInfo.description }}</p></div><el-switch v-model="selectedPolicy.enabled" :disabled="busy || selectedPolicy.code === 'general'" :aria-label="`启用${selectedInfo.name}`" /></div>
          <el-form label-position="top" :disabled="busy" @submit.prevent>
            <el-form-item label="技能说明与回答规则"><el-input v-model="selectedPolicy.prompt" type="textarea" :rows="9" maxlength="5000" show-word-limit aria-label="技能回答规则" /></el-form-item>
            <el-form-item label="计算工具"><div class="ops-tool-row"><el-switch v-model="selectedPolicy.useTool" :disabled="!selectedInfo.toolAvailable" aria-label="使用计算工具" /><strong>{{ selectedInfo.toolName || '此技能不需要外部计算工具' }}</strong><el-tag v-if="selectedInfo.einoSupported" size="small" type="info">支持 Eino 调试</el-tag></div></el-form-item>
          </el-form>
          <h3>输入资料要求</h3><p class="ops-hint">随发布版本固定，来自已接入技能的输入契约。</p>
          <el-table :data="selectedInfo.inputSchema.fields || []" empty-text="无需结构化资料"><el-table-column label="资料"><template #default="{ row }">{{ row.label || row.key }}</template></el-table-column><el-table-column prop="type" label="类型" width="120" /><el-table-column label="要求" width="110"><template #default="{ row }">{{ row.required ? '必填' : '按需填写' }}</template></el-table-column></el-table>
        </div>
      </section>

      <section v-show="tab === 'debug'" class="ops-debug-grid">
        <div class="ops-card"><div class="ops-section-head"><div><h2>试一次真实问事</h2><p>仅填写测试资料；调用现有模型与工具，会产生模型费用。</p></div></div>
          <el-alert v-if="dirty || !workspace.draftSaved" title="请先保存草稿，再开始调试" type="info" :closable="false" />
          <el-form label-position="top" @submit.prevent>
            <el-form-item label="技能"><el-select v-model="debug.skillCode" :disabled="inProgress || pending || debugBusy" aria-label="调试技能"><el-option v-for="s in enabledSkills" :key="s.code" :value="s.code" :label="skillName(s.code)" /></el-select></el-form-item>
            <el-form-item label="执行方式"><el-radio-group v-model="debug.kind" :disabled="inProgress || pending || debugBusy"><el-radio-button value="classic">原问事流程</el-radio-button><el-radio-button value="eino" :disabled="!einoAvailable">Eino 多步验证</el-radio-button></el-radio-group><span class="ops-hint">原流程调试用于发布检查；Eino 暂用于多步能力验证。</span></el-form-item>
            <el-form-item label="测试问题"><el-input v-model="debug.question" type="textarea" :rows="3" maxlength="1500" :disabled="inProgress || pending" aria-label="测试问题" /></el-form-item>
            <div class="ops-section-head"><h3>结构化资料</h3><el-button text :disabled="inProgress || debugBusy" @click="sample">填入合成示例</el-button></div>
            <div class="ops-grid"><el-form-item v-for="field in debugFields" :key="field.key" :label="`${field.label || field.key}${field.required ? ' · 必填' : ''}`"><el-select v-if="field.options?.length" v-model="inputValues[field.key]" clearable :disabled="inProgress || debugBusy" :aria-label="field.label || field.key"><el-option v-for="o in field.options" :key="o.value" :value="o.value" :label="o.label || o.value" /></el-select><el-input v-else v-model="inputValues[field.key]" :disabled="inProgress || debugBusy" :aria-label="field.label || field.key" :placeholder="field.type === 'date' ? 'YYYY-MM-DD' : field.type === 'time' ? 'HH:mm' : '填写测试资料'" maxlength="500" /></el-form-item></div>
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

      <section v-show="tab === 'runs'" class="ops-card">
        <div class="ops-section-head"><div><h2>执行记录</h2><p>用户问事与管理员调试分别查看，默认隐藏原始资料和对话正文。</p></div><el-button :icon="Refresh" :loading="recordsLoading" @click="loadRecords">刷新</el-button></div>
        <div class="ops-record-filters"><el-radio-group v-model="recordKind"><el-radio-button value="production">用户问事</el-radio-button><el-radio-button value="debug">后台调试</el-radio-button></el-radio-group><el-select v-if="recordKind === 'production'" v-model="status" clearable placeholder="全部状态" aria-label="运行状态" @change="changeStatus"><el-option v-for="s in ['completed', 'failed', 'running']" :key="s" :value="s" :label="statusText(s)" /></el-select></div>
        <el-alert v-if="recordsError" :title="recordsError" type="error" :closable="false" />
        <el-table v-else-if="recordKind === 'production'" :data="records" v-loading="recordsLoading" empty-text="暂无问事执行记录"><el-table-column prop="runNo" label="运行编号" min-width="200" /><el-table-column label="技能 / 版本" min-width="170"><template #default="{ row }">{{ skillName(row.skillCode) }}<small class="ops-cell-sub">{{ row.skillVersion }}</small></template></el-table-column><el-table-column prop="model" label="模型" min-width="160" /><el-table-column label="状态" width="100"><template #default="{ row }">{{ statusText(row.status) }}</template></el-table-column><el-table-column label="耗时" width="100"><template #default="{ row }">{{ row.status === 'running' ? '—' : `${(row.latencyMs / 1000).toFixed(1)}s` }}</template></el-table-column><el-table-column label="输入 / 输出 Token" width="155"><template #default="{ row }">{{ row.promptTokens }} / {{ row.completionTokens }}</template></el-table-column><el-table-column label="操作" width="110" fixed="right"><template #default="{ row }"><el-button link type="primary" @click="showTools(row)">工具轨迹</el-button></template></el-table-column></el-table>
        <el-table v-else :data="debugRecords" v-loading="recordsLoading" empty-text="暂无后台调试记录"><el-table-column label="时间" min-width="180"><template #default="{ row }">{{ timeText(row.startedAt) }}</template></el-table-column><el-table-column label="草稿" width="90"><template #default="{ row }">r{{ row.revision }}</template></el-table-column><el-table-column label="技能" min-width="130"><template #default="{ row }">{{ skillName(row.skillCode) }}</template></el-table-column><el-table-column label="方式" width="120"><template #default="{ row }">{{ row.kind === 'eino' ? 'Eino 验证' : '原问事流程' }}</template></el-table-column><el-table-column label="状态" width="120"><template #default="{ row }">{{ statusText(row.status) }}</template></el-table-column><el-table-column label="操作" width="100"><template #default="{ row }"><el-button link type="primary" @click="showDebug(row)">查看详情</el-button></template></el-table-column></el-table>
        <div v-if="recordKind === 'production'" class="ops-pagination"><el-button :disabled="page === 1 || recordsLoading" @click="page--">上一页</el-button><span>第 {{ page }} 页</span><el-button :disabled="!hasMore || recordsLoading" @click="page++">下一页</el-button></div>
      </section>

      <section v-show="tab === 'versions'" class="ops-card">
        <div class="ops-section-head"><div><h2>发布与回滚</h2><p>每次发布固定技能契约与提示词。变更只影响新请求，基础调试不等同于完整质量评测。</p></div><el-button type="primary" :icon="Check" :disabled="dirty || !workspace.tested || busy" @click="publish">发布当前草稿</el-button></div>
        <el-alert v-if="!workspace.liveEnabled" title="服务器尚未启用运营配置，发布版本暂不会改变用户端" type="info" :closable="false" />
        <el-table :data="workspace.versions" empty-text="尚无发布版本。保存并调试草稿后即可发布。"><el-table-column label="版本" width="150"><template #default="{ row }"><strong>v{{ row.id }}</strong><el-tag v-if="row.id === workspace.activeVersion" size="small" class="ops-version-tag">{{ workspace.liveEnabled ? '当前运行' : '已选定' }}</el-tag></template></el-table-column><el-table-column prop="note" label="发布说明" min-width="240" /><el-table-column prop="actor" label="操作人" width="100" /><el-table-column prop="createdAt" label="时间" min-width="180" /><el-table-column label="操作" width="190"><template #default="{ row }"><el-button link type="primary" :disabled="busy" @click="showVersion(row.id)">查看配置</el-button><el-button link type="primary" :disabled="row.id === workspace.activeVersion || busy || dirty" @click="rollback(row.id)">回滚到此版</el-button></template></el-table-column></el-table>
        <div class="ops-fallback"><div><h3>原始问事配置</h3><p>恢复到本次运营管理接入前的技能配置来源。</p></div><el-button :disabled="!workspace.activeVersion || busy || dirty" @click="rollback(0)">恢复原配置</el-button></div>
        <h3>最近操作</h3><el-table :data="workspace.audit" empty-text="尚无操作记录"><el-table-column label="操作" width="100"><template #default="{ row }">{{ ({ save: '保存草稿', publish: '发布', rollback: '回滚' } as Record<string, string>)[row.action] || row.action }}</template></el-table-column><el-table-column prop="note" label="说明" min-width="200" /><el-table-column prop="actor" label="操作人" width="100" /><el-table-column prop="createdAt" label="时间" min-width="180" /></el-table>
      </section>

      <footer v-show="tab === 'config' || tab === 'skills'" class="ops-save-bar"><span :class="{ 'is-dirty': dirty }">{{ dirty ? '有未保存的修改' : workspace.draftSaved ? '草稿已同步' : '待首次保存' }}</span><div><el-button :disabled="!dirty || busy" @click="reload">撤销修改</el-button><el-button type="primary" :loading="busy" :disabled="(!dirty && workspace.draftSaved) || busy" @click="save">保存草稿</el-button></div></footer>
    </template>
    <el-dialog v-model="versionDialog" :title="`版本 v${versionNumber} · 已发布配置`" width="min(760px, 94vw)">
      <template v-if="versionConfig"><h3>{{ versionConfig.name }}</h3><p class="ops-hint">{{ versionConfig.model }} · 最多 {{ versionConfig.maxOutputTokens }} Token</p><pre class="ops-answer">{{ versionConfig.instruction }}</pre><el-collapse><el-collapse-item v-for="skill in versionConfig.skills" :key="skill.code" :name="skill.code" :title="`${skillName(skill.code)} · ${skill.enabled ? '启用' : '停用'} · ${skill.useTool ? '使用计算工具' : '不使用工具'}`"><pre class="ops-answer">{{ skill.prompt }}</pre></el-collapse-item></el-collapse></template>
    </el-dialog>
    <el-drawer v-model="drawer" title="工具执行轨迹" size="min(520px, 100vw)"><div v-loading="toolsLoading"><p>{{ detailRun?.runNo }}</p><p class="ops-hint">{{ detailRun?.skillVersion }} · {{ detailRun?.model }}</p><el-alert v-if="toolsError" :title="toolsError" type="error" :closable="false" /><el-empty v-else-if="!toolsLoading && !tools.length" description="本次没有计算工具调用" /><ol v-else class="ops-events"><li v-for="(tool, i) in tools" :key="i"><span class="ops-event-dot" /><div><strong>{{ tool.name }}</strong><p>{{ statusText(tool.status) }} · {{ tool.latencyMs }} ms</p><time>{{ timeText(tool.createdAt) }}</time></div></li></ol></div></el-drawer>
  </div>
</template>

<style scoped>
.agent-ops{padding-bottom:24px}.ops-overview{display:flex;align-items:center;gap:28px;padding:22px 26px;border:1px solid var(--el-border-color-light);border-radius:16px;background:var(--el-bg-color);margin-bottom:18px}.ops-identity{display:flex;align-items:center;gap:14px;flex:1}.ops-identity strong{font-size:20px}.ops-identity p,.ops-section-head p,.ops-fallback p{margin:7px 0 0;color:var(--el-text-color-secondary);font-size:13px;line-height:1.6}.ops-symbol{width:46px;height:46px;border-radius:13px;background:var(--el-color-primary-light-9);color:var(--el-color-primary);display:grid;place-items:center}.ops-symbol svg{width:25px}.ops-stat{display:grid;gap:8px;min-width:95px}.ops-stat>span{color:var(--el-text-color-secondary);font-size:12px}.ops-stat strong{font-size:15px}.ready{color:var(--el-color-success)}.ops-tabs{display:flex;gap:4px;overflow-x:auto;margin:0 0 20px;border-bottom:1px solid var(--el-border-color-light)}.ops-tabs button{display:flex;align-items:center;gap:7px;white-space:nowrap;padding:14px 19px;border:0;border-bottom:2px solid transparent;background:transparent;color:var(--el-text-color-secondary);cursor:pointer;font:inherit}.ops-tabs button.active{color:var(--el-color-primary);border-bottom-color:var(--el-color-primary);font-weight:600}.ops-tabs button:focus-visible,.ops-skill-list button:focus-visible{outline:2px solid var(--el-color-primary);outline-offset:-3px}.ops-card{background:var(--el-bg-color);border:1px solid var(--el-border-color-light);border-radius:16px;padding:24px;min-width:0}.ops-card h2{font-size:17px;margin:0 0 8px}.ops-card h3,.ops-fallback h3{font-size:14px;margin:14px 0 8px}.ops-section-head{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;margin-bottom:22px}.ops-section-head a{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--el-color-primary);white-space:nowrap}.ops-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:0 20px}.ops-hint{display:block;color:var(--el-text-color-secondary);font-size:12px;line-height:1.7;margin-top:8px}.ops-skills{display:grid;grid-template-columns:240px minmax(0,1fr);gap:20px}.ops-skill-list{padding:20px 12px;align-self:start}.ops-skill-list h2{padding:0 12px 12px}.ops-skill-list button{display:flex;align-items:center;justify-content:space-between;gap:10px;width:100%;border:0;background:transparent;color:var(--el-text-color-primary);padding:13px 12px;border-radius:9px;cursor:pointer;text-align:left;font:inherit;font-size:13px}.ops-skill-list button.selected{background:var(--el-color-primary-light-9);color:var(--el-color-primary)}.ops-pill{font-size:11px;color:var(--el-color-success);white-space:nowrap}.ops-pill.muted{color:var(--el-text-color-placeholder)}.ops-tool-row{display:flex;align-items:center;gap:12px;flex-wrap:wrap}.ops-debug-grid{display:grid;grid-template-columns:minmax(300px,1fr) minmax(320px,1fr);gap:20px}.ops-debug-result{align-self:start;min-height:360px}.ops-debug-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:20px}.ops-empty{text-align:center;color:var(--el-text-color-secondary);padding:65px 15px}.ops-empty>.el-icon{font-size:34px;color:var(--el-color-primary)}.ops-answer{font-family:inherit;white-space:pre-wrap;overflow-wrap:anywhere;font-size:14px;line-height:1.9;padding:18px;background:var(--el-fill-color-light);border-radius:10px;max-height:460px;overflow:auto}.ops-events{list-style:none;margin:20px 0;padding:0}.ops-events li{display:flex;gap:12px;padding:0 0 20px;position:relative;font-size:13px}.ops-event-dot{width:8px;height:8px;flex-shrink:0;border-radius:50%;background:var(--el-color-primary);margin-top:5px}.ops-events li:not(:last-child):before{content:'';position:absolute;left:3px;top:15px;bottom:3px;width:1px;background:var(--el-border-color-light)}.ops-events time{display:block;color:var(--el-text-color-placeholder);font-size:11px;margin-top:5px}.ops-run-counts{display:flex;gap:14px;flex-wrap:wrap;font-size:12px;color:var(--el-text-color-secondary);border-top:1px solid var(--el-border-color-light);padding-top:14px}.ops-record-filters{display:flex;gap:16px;margin:16px 0 20px;flex-wrap:wrap}.ops-record-filters>.el-select{width:160px}.ops-cell-sub{display:block;color:var(--el-text-color-secondary);font-size:11px}.ops-pagination{display:flex;align-items:center;justify-content:flex-end;gap:14px;margin-top:20px;font-size:13px}.ops-fallback{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:18px 0;margin:16px 0;border-bottom:1px solid var(--el-border-color-light)}.ops-version-tag{margin-left:8px}.ops-save-bar{position:sticky;bottom:12px;z-index:5;display:flex;align-items:center;justify-content:space-between;gap:16px;margin-top:20px;padding:14px 20px;background:var(--el-bg-color);border:1px solid var(--el-border-color-light);border-radius:12px;box-shadow:0 6px 24px #00000008;font-size:13px;color:var(--el-text-color-secondary)}.is-dirty{color:var(--el-color-warning)}.ops-card :deep(.el-select){width:100%}.ops-card :deep(.el-form-item__content > .ops-hint){flex-basis:100%}.ops-card :deep(.el-alert){margin-bottom:16px}.ops-card :deep(.el-input-number){width:180px}.ops-tabs button,.ops-skill-list button{transition:background-color 140ms ease,color 140ms ease}@media(max-width:1000px){.ops-overview{flex-wrap:wrap;gap:18px}.ops-identity{flex-basis:100%}.ops-debug-grid{grid-template-columns:1fr}.ops-skills{grid-template-columns:200px minmax(0,1fr)}}@media(max-width:640px){.ops-skills,.ops-grid{grid-template-columns:1fr}.ops-skill-list{max-height:240px;overflow:auto}.ops-card{padding:18px}.ops-section-head{flex-wrap:wrap}.ops-stat{min-width:80px}.ops-tabs button{padding:12px}.ops-overview{padding:18px}.ops-save-bar{bottom:6px;padding:12px}.ops-debug-actions{gap:4px}}@media(prefers-reduced-motion:reduce){.ops-tabs button,.ops-skill-list button{transition:none}}
</style>
