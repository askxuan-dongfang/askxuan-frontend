<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import client from '@/api/client'
import { emptyUses, modelLibraryApi, modelOptions, modelRoles, type LibraryModel, type ModelLibrary, type ModelRole } from '@/api/modelLibrary'

const library = ref<ModelLibrary>(), uses = ref(emptyUses()), savedUses = ref(JSON.stringify(emptyUses()))
const busy = ref(false), error = ref(''), query = ref(''), role = ref<ModelRole | ''>(''), dialog = ref(false)
const initial = () => ({ kind: 'language', name: '', model: '', provider: 'volcengine', baseUrl: 'https://ark.cn-beijing.volces.com/api/v3', apiKey: '', reuseConnection: '', supportsVision: false, contextWindow: 0, maxOutputTokens: 0, dimension: 512 })
const form = ref(initial()), formBaseline = ref('')
const options = (use: ModelRole) => library.value ? modelOptions(library.value, use) : []
const visible = computed(() => library.value?.list.filter(m => (!role.value || m.bindings[role.value]) && `${m.name} ${m.model} ${m.provider}`.toLowerCase().includes(query.value.trim().toLowerCase())) || [])
const connections = computed(() => library.value?.list.filter(m => m.kind === 'language') || [])
const dirty = computed(() => JSON.stringify(uses.value) !== savedUses.value || (dialog.value && JSON.stringify(form.value) !== formBaseline.value))
async function run(fn: () => Promise<void>) { if (busy.value) return; busy.value = true; error.value = ''; try { await fn() } catch (e) { error.value = e instanceof Error ? e.message : '模型操作失败' } finally { busy.value = false } }
async function load() { library.value = await modelLibraryApi.list(); uses.value = { ...emptyUses(), ...library.value.uses }; savedUses.value = JSON.stringify(uses.value) }
async function refresh() { if (dirty.value) { try { await ElMessageBox.confirm('刷新将丢弃尚未保存的选择。', '刷新模型库', { confirmButtonText: '刷新', cancelButtonText: '继续编辑' }) } catch { return } } await run(load) }
function add() { form.value = initial(); formBaseline.value = JSON.stringify(form.value); dialog.value = true }
watch(() => form.value.kind, kind => { form.value.apiKey = ''; form.value.reuseConnection = ''; form.value.provider = kind === 'language' ? 'volcengine' : kind === 'Rerank' ? 'generic' : 'openai'; form.value.baseUrl = kind === 'language' ? 'https://ark.cn-beijing.volces.com/api/v3' : '' })
watch(() => form.value.provider, provider => { if (form.value.reuseConnection) return; if (provider === 'deepseek') form.value.baseUrl = 'https://api.deepseek.com'; if (provider === 'volcengine') form.value.baseUrl = 'https://ark.cn-beijing.volces.com/api/v3' })
watch(() => form.value.reuseConnection, id => { const m = connections.value.find(m => m.id === id); if (m) { form.value.provider = m.provider; form.value.baseUrl = m.baseUrl; form.value.apiKey = '' } })
function languageInput() { const f = form.value; return { name: f.name, model: f.model, provider: f.provider, baseUrl: f.baseUrl, apiKey: f.apiKey, reuseConnection: f.reuseConnection, supportsVision: f.supportsVision, contextWindow: f.contextWindow || 0, maxOutputTokens: f.maxOutputTokens || 0, revision: library.value?.revision } }
async function probe() { await run(async () => { await client.post('/ai/admin/model-library/language/test', languageInput(), { timeout: 35000 }); ElMessage.success('模型连接成功') }) }
async function saveModel() { await run(async () => {
  if (form.value.kind === 'language') await client.post('/ai/admin/model-library/language', languageInput(), { timeout: 35000 })
  else { const f = form.value; await client.post('/ai/admin/knowledge-models', { name: f.model, displayName: f.name, type: f.kind, baseUrl: f.baseUrl, apiKey: f.apiKey, provider: f.provider, dimension: f.dimension }) }
  form.value.apiKey = ''; dialog.value = false; await load(); ElMessage.success('模型已加入模型库，可按用途选择')
}) }
async function saveUses() { if (!library.value) return; await run(async () => { await modelLibraryApi.saveUses(uses.value, library.value!.revision); await load(); ElMessage.success('默认模型选择已保存') }) }
async function test(m: LibraryModel) { await run(async () => { const root = m.kind === 'language' ? '/ai/admin/model-library/' : '/ai/admin/knowledge-models/'; await client.post(root + encodeURIComponent(m.id) + '/test', {}, { timeout: 45000 }); ElMessage.success(`${m.name} 连接成功`) }) }
async function remove(m: LibraryModel) { try { await ElMessageBox.confirm(`删除“${m.name}”？已绑定或发布使用的模型会保留。`, '删除模型', { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' }) } catch { return }
  await run(async () => { if (m.kind === 'language') await client.delete('/ai/admin/model-library/' + encodeURIComponent(m.id), { data: { revision: library.value?.revision } }); else await client.delete('/ai/admin/knowledge-models/' + encodeURIComponent(m.id)); await load() })
}
onBeforeRouteLeave(async () => { if (!dirty.value) return true; try { await ElMessageBox.confirm('尚有未保存的模型资料或用途选择。', '离开模型库', { confirmButtonText: '离开', cancelButtonText: '继续编辑' }); return true } catch { return false } })
onBeforeUnmount(() => { form.value.apiKey = '' })
onMounted(() => run(load))
</script>

<template>
  <section class="model-library" v-loading="busy">
    <header><div><h2>模型库</h2><p>模型添加一次，聊天、建索引、重排和文档理解按用途选择。</p></div><el-button @click="refresh">刷新</el-button><el-button type="primary" :disabled="!library?.writable" @click="add">添加模型</el-button></header>
    <el-alert v-if="error" :title="error" type="error" :closable="false" />
    <el-alert v-for="warning in library?.warnings" :key="warning" :title="warning" type="warning" :closable="false" />
    <el-tabs>
      <el-tab-pane label="已添加模型">
        <div class="filters"><el-input v-model="query" clearable placeholder="搜索模型名称或供应商" aria-label="搜索模型" /><el-select v-model="role" clearable placeholder="全部用途" aria-label="筛选模型用途"><el-option v-for="use in modelRoles" :key="use.key" :value="use.key" :label="use.label" /></el-select></div>
        <el-table :data="visible" empty-text="尚无匹配模型，请添加模型或调整筛选">
          <el-table-column label="模型" min-width="240"><template #default="{row}"><strong>{{ row.name }}</strong><small>{{ row.model }}</small><small>{{ row.provider }}</small></template></el-table-column>
          <el-table-column label="可用用途" min-width="240"><template #default="{row}"><el-tag v-for="use in modelRoles.filter(use => row.bindings[use.key])" :key="use.key" size="small">{{ use.label }}</el-tag></template></el-table-column>
          <el-table-column label="容量" width="160"><template #default="{row}"><span v-if="row.dimension">{{ row.dimension }} 维</span><span v-else-if="row.contextWindow">{{ row.contextWindow.toLocaleString() }} 上下文</span><span v-else>由模型服务决定</span></template></el-table-column>
          <el-table-column label="操作" width="180"><template #default="{row}"><el-button link @click="test(row)">测试连接</el-button><el-button v-if="['registered','knowledge'].includes(row.source)" link type="danger" @click="remove(row)">删除</el-button><small v-else>{{ row.source === 'builtin' ? '部署预置' : '原有连接' }}</small></template></el-table-column>
        </el-table>
      </el-tab-pane>
      <el-tab-pane label="默认用途">
        <p>为各用途指定默认模型。已有知识库和已发布智能体保留各自的模型选择。</p>
        <el-form label-position="top" class="uses"><el-form-item v-for="use in modelRoles" :key="use.key" :label="use.label"><el-select v-model="uses[use.key]" filterable clearable :aria-label="use.label + '默认模型'" :placeholder="use.key === 'chat' ? (library?.defaultChat || '沿用原有连接') : '不指定默认模型'"><el-option v-for="m in options(use.key)" :key="m.id" :value="m.id" :label="m.name" /></el-select><small>{{ use.hint }}</small></el-form-item></el-form>
        <el-button type="primary" :disabled="!library?.writable || JSON.stringify(uses) === savedUses" @click="saveUses">保存默认选择</el-button>
      </el-tab-pane>
    </el-tabs>
    <p class="note">模型需支持对应接口：聊天大模型不能代替 Embedding 或 Rerank。更换向量模型需要新建索引。<router-link to="/ai/connections/legacy">原有连接与运行参数</router-link></p>
    <el-dialog v-model="dialog" title="添加模型" width="min(640px,94vw)" append-to-body @closed="form.apiKey = ''">
      <el-form label-position="top">
        <el-form-item label="模型类型"><el-select v-model="form.kind" aria-label="模型类型"><el-option label="大模型 · 聊天 / 文档理解" value="language" /><el-option label="Embedding · 建索引" value="Embedding" /><el-option label="Rerank · 检索重排" value="Rerank" /></el-select></el-form-item>
        <el-form-item label="显示名称"><el-input v-model="form.name" maxlength="120" aria-label="模型显示名称" /></el-form-item>
        <el-form-item label="服务商模型 ID / Endpoint ID"><el-input v-model="form.model" maxlength="100" aria-label="服务商模型 ID" placeholder="例如 ark-code-latest 或 ep-…" /></el-form-item>
        <el-form-item v-if="form.kind === 'language'" label="复用已保存的连接"><el-select v-model="form.reuseConnection" filterable clearable placeholder="新建连接" aria-label="复用连接"><el-option v-for="m in connections" :key="m.id" :value="m.id" :label="m.name + ' · ' + m.provider" /></el-select></el-form-item>
        <el-form-item :label="form.kind === 'language' ? '供应商' : '接口协议'"><el-select v-model="form.provider" :disabled="!!form.reuseConnection" aria-label="模型供应商"><template v-if="form.kind === 'language'"><el-option label="火山引擎 / 方舟" value="volcengine" /><el-option label="DeepSeek" value="deepseek" /><el-option label="OpenAI 兼容" value="openai_compatible" /></template><template v-else><el-option label="OpenAI 兼容" value="openai" :disabled="form.kind === 'Rerank'" /><el-option label="通用 / Jina 重排" value="generic" /><el-option label="阿里云" value="aliyun" /></template></el-select></el-form-item>
        <el-form-item label="HTTPS 接口地址"><el-input v-model="form.baseUrl" :disabled="!!form.reuseConnection" aria-label="模型接口地址" /><small v-if="form.provider === 'volcengine'">Agent Plan 使用 https://ark.cn-beijing.volces.com/api/plan/v3</small><small v-else-if="form.kind !== 'language'">使用对应的向量或重排接口；服务域名需在知识引擎的出站许可范围内。</small></el-form-item>
        <el-form-item v-if="!form.reuseConnection" label="API Key"><el-input v-model="form.apiKey" type="password" show-password autocomplete="new-password" aria-label="模型 API Key" /></el-form-item>
        <template v-if="form.kind === 'language'"><el-form-item label="图片输入"><el-switch v-model="form.supportsVision" active-text="支持图片理解" /></el-form-item><div class="capacity"><el-form-item label="上下文容量（0 为自动）"><el-input-number v-model="form.contextWindow" :min="0" :max="1048576" :step="32768" /></el-form-item><el-form-item label="输出上限（0 为自动）"><el-input-number v-model="form.maxOutputTokens" :min="0" :max="32768" :step="1024" /></el-form-item></div></template>
        <el-form-item v-if="form.kind === 'Embedding'" label="向量维度"><el-input-number v-model="form.dimension" :min="1" :max="8192" /></el-form-item>
      </el-form><el-alert v-if="error" :title="error" type="error" :closable="false" />
      <template #footer><el-button @click="dialog = false">取消</el-button><el-button v-if="form.kind === 'language'" :disabled="busy || !form.model || !form.baseUrl" @click="probe">测试连接</el-button><el-button type="primary" :loading="busy" :disabled="!form.model || !form.baseUrl" @click="saveModel">添加模型</el-button></template>
    </el-dialog>
  </section>
</template>
<style scoped>
.model-library{min-width:0;padding:24px;border:1px solid var(--el-border-color-lighter);border-radius:12px;background:var(--el-bg-color)}header,.filters,.capacity{display:flex;gap:12px}header{align-items:flex-start;margin-bottom:20px}header>div{flex:1}h2{margin:0 0 8px}p,small{font-size:13px;line-height:1.7;color:var(--el-text-color-secondary)}p{margin:0 0 16px}small{display:block;overflow-wrap:anywhere}.filters{margin:8px 0 18px}.filters .el-input{max-width:440px}.filters .el-select{max-width:240px}.el-tag{margin:3px 6px 3px 0}.el-alert{margin:12px 0}.uses{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px 24px;max-width:900px}.uses .el-form-item{display:block}.note{margin:22px 0 0}.note a{margin-left:12px}.capacity{flex-wrap:wrap}@media(max-width:680px){.model-library{padding:16px}header,.filters{flex-wrap:wrap}header>div{flex-basis:100%}.uses{grid-template-columns:1fr}.filters .el-input,.filters .el-select{max-width:none}}
</style>
