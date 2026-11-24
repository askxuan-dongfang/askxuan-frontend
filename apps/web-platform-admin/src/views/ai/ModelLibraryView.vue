<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'

import client from '@/api/client'
import { emptyUses, modelLibraryApi, modelOptions, modelRoles, type DiscoveredLanguageModel, type LibraryModel, type ModelLibrary, type ModelRole } from '@/api/modelLibrary'

const library = ref<ModelLibrary>(), uses = ref(emptyUses())
const customerModelIds = ref<string[]>([])
const selection = computed(() => JSON.stringify({ uses: uses.value, customerModelIds: customerModelIds.value }))
const savedSelection = ref(selection.value)
const busy = ref(false), error = ref(''), query = ref(''), role = ref<ModelRole | ''>(''), dialog = ref(false)
const initial = () => ({ kind: 'language', name: '', model: '', provider: 'volcengine', baseUrl: 'https://ark.cn-beijing.volces.com/api/v3', apiKey: '', reuseConnection: '', supportsVision: false, contextWindow: 0, maxOutputTokens: 0, dimension: 512 })
const form = ref(initial()), formBaseline = ref('')
const openCodeGoBaseUrl = 'https://opencode.ai/inference/go/openai/v1'
const isOpenCodeGo = computed(() => form.value.kind === 'language' && form.value.provider === 'opencode_go')
const discoveredModels = ref<DiscoveredLanguageModel[]>([])
const discoveredModel = computed(() => discoveredModels.value.find(model => model.id === form.value.model))
const canSubmit = computed(() => !!form.value.model && !!form.value.baseUrl &&
  (!isOpenCodeGo.value || (!!discoveredModel.value && !!form.value.apiKey.trim())))
const options = (use: ModelRole) => library.value ? modelOptions(library.value, use) : []
function providerName(provider: string) { return provider === 'opencode_go' ? 'OpenCode Go' : provider }
const visible = computed(() => library.value?.list.filter(m => (!role.value || m.bindings[role.value]) &&
  `${m.name} ${m.model} ${m.provider} ${providerName(m.provider)}`.toLowerCase().includes(query.value.trim().toLowerCase())) || [])
const connections = computed(() => library.value?.list.filter(m => m.kind === 'language' && m.provider !== 'opencode_go') || [])
const dirty = computed(() => selection.value !== savedSelection.value || (dialog.value && JSON.stringify(form.value) !== formBaseline.value))
async function run(fn: () => Promise<void>) { if (busy.value) return; busy.value = true; error.value = ''; try { await fn() } catch (e) { error.value = e instanceof Error ? e.message : '模型操作失败' } finally { busy.value = false } }
async function load() {
  const data = await modelLibraryApi.list()
  library.value = data
  uses.value = { ...emptyUses(), ...data.uses }
  customerModelIds.value = [...(data.customerModelIds ?? [])]
  savedSelection.value = selection.value
}
async function refresh() { if (dirty.value) { try { await ElMessageBox.confirm(uiText('刷新将丢弃尚未保存的选择。'), uiText('刷新模型库'), { confirmButtonText: uiText('刷新'), cancelButtonText: uiText('继续编辑') }) } catch { return } } await run(load) }
function add() { form.value = initial(); formBaseline.value = JSON.stringify(form.value); dialog.value = true }
watch(() => form.value.kind, kind => { form.value.apiKey = ''; form.value.reuseConnection = ''; form.value.provider = kind === 'language' ? 'volcengine' : kind === 'Rerank' ? 'generic' : 'openai'; form.value.baseUrl = kind === 'language' ? 'https://ark.cn-beijing.volces.com/api/v3' : '' })
watch(() => form.value.provider, (provider, previous) => {
  if (provider === 'opencode_go' || previous === 'opencode_go') form.value.apiKey = ''
  if (form.value.reuseConnection) return
  if (provider === 'opencode_go') form.value.baseUrl = openCodeGoBaseUrl
  else if (provider === 'deepseek') form.value.baseUrl = 'https://api.deepseek.com'
  else if (provider === 'volcengine') form.value.baseUrl = 'https://ark.cn-beijing.volces.com/api/v3'
  else if (form.value.baseUrl === openCodeGoBaseUrl) form.value.baseUrl = ''
})
watch(() => form.value.reuseConnection, id => { const m = connections.value.find(m => m.id === id); if (m) { form.value.provider = m.provider; form.value.baseUrl = m.baseUrl; form.value.apiKey = '' } })
watch([isOpenCodeGo, () => form.value.apiKey], ([active], [wasActive]) => {
  if (!active && !wasActive) return
  discoveredModels.value = []
  form.value.model = ''
})
watch(discoveredModel, (model, previous) => {
  if (model) form.value.name = model.name
  else if (previous && form.value.name === previous.name) form.value.name = ''
})
async function discoverModels() {
  await run(async () => {
    discoveredModels.value = []
    form.value.model = ''
    const { list } = await modelLibraryApi.discoverOpenCodeGo(form.value.apiKey.trim())
    discoveredModels.value = list
    if (!list.length) error.value = '当前没有可用模型'
  })
}
function languageInput() {
  const f = form.value
  const details = isOpenCodeGo.value ? discoveredModel.value : f
  return {
    name: f.name, model: f.model, provider: f.provider, baseUrl: f.baseUrl,
    apiKey: isOpenCodeGo.value ? f.apiKey.trim() : f.apiKey, reuseConnection: f.reuseConnection,
    supportsVision: details?.supportsVision ?? false, contextWindow: details?.contextWindow || 0,
    maxOutputTokens: details?.maxOutputTokens || 0, revision: library.value?.revision,
  }
}
async function probe() { await run(async () => { await client.post('/ai/admin/model-library/language/test', languageInput(), { timeout: 35000 }); ElMessage.success(uiText('模型连接成功')) }) }
async function saveModel() { await run(async () => {
  if (form.value.kind === 'language') await client.post('/ai/admin/model-library/language', languageInput(), { timeout: 35000 })
  else { const f = form.value; await client.post('/ai/admin/knowledge-models', { name: f.model, displayName: f.name, type: f.kind, baseUrl: f.baseUrl, apiKey: f.apiKey, provider: f.provider, dimension: f.dimension }) }
  form.value.apiKey = ''; dialog.value = false; await load(); ElMessage.success(uiText('模型已加入模型库，可按用途选择'))
}) }
async function saveUses() {
  const data = library.value
  if (!data) return
  await run(async () => {
    await modelLibraryApi.saveUses(uses.value, data.revision, data.customerModelIds ? customerModelIds.value : undefined)
    await load()
    ElMessage.success(uiText(data.customerModelIds ? '模型用途配置已保存' : '默认模型选择已保存'))
  })
}
async function test(m: LibraryModel) { await run(async () => { const root = m.kind === 'language' ? '/ai/admin/model-library/' : '/ai/admin/knowledge-models/'; await client.post(root + encodeURIComponent(m.id) + '/test', {}, { timeout: 45000 }); ElMessage.success((uiText("") + String(m.name) + uiText(" 连接成功"))) }) }
async function remove(m: LibraryModel) { try { await ElMessageBox.confirm((uiText("删除“") + String(m.name) + uiText("”？已绑定或发布使用的模型会保留。")), uiText('删除模型'), { type: 'warning', confirmButtonText: uiText('删除'), cancelButtonText: uiText('取消') }) } catch { return }
  await run(async () => { if (m.kind === 'language') await client.delete('/ai/admin/model-library/' + encodeURIComponent(m.id), { data: { revision: library.value?.revision } }); else await client.delete('/ai/admin/knowledge-models/' + encodeURIComponent(m.id)); await load() })
}
onBeforeRouteLeave(async () => { if (!dirty.value) return true; try { await ElMessageBox.confirm(uiText('尚有未保存的模型资料或用途选择。'), uiText('离开模型库'), { confirmButtonText: uiText('离开'), cancelButtonText: uiText('继续编辑') }); return true } catch { return false } })
onBeforeUnmount(() => { form.value.apiKey = '' })
onMounted(() => run(load))
</script>

<template>
  <section class="model-library" v-loading="busy">
    <header><div><h2>{{ $t("模型库") }}</h2></div><el-button @click="refresh">{{ $t("刷新") }}</el-button><el-button type="primary" :disabled="!library?.writable" @click="add">{{ $t("添加模型") }}</el-button></header>
    <el-alert v-if="error" :title="$t(error)" type="error" :closable="false" />
    <el-alert v-for="warning in library?.warnings" :key="warning" :title="$t(warning)" type="warning" :closable="false" />
    <el-tabs>
      <el-tab-pane :label='$t("已添加模型")'>
        <div class="filters"><el-input v-model="query" clearable :placeholder='$t("搜索模型名称或供应商")' :aria-label='$t("搜索模型")' /><el-select v-model="role" clearable :placeholder='$t("全部用途")' :aria-label='$t("筛选模型用途")'><el-option v-for="use in modelRoles" :key="use.key" :value="use.key" :label="$t(use.label)" /></el-select></div>
        <el-table :data="visible" :empty-text='$t("尚无匹配模型，请添加模型或调整筛选")'>
          <el-table-column :label='$t("模型")' min-width="240"><template #default="{row}"><strong>{{ $t(row.name) }}</strong><small>{{ $t(row.model) }}</small><small>{{ $t(providerName(row.provider)) }}</small></template></el-table-column>
          <el-table-column :label='$t("可用用途")' min-width="240"><template #default="{row}"><el-tag v-for="use in modelRoles.filter(use => row.bindings[use.key])" :key="use.key" size="small">{{ $t(use.label) }}</el-tag></template></el-table-column>
          <el-table-column :label='$t("容量")' width="160"><template #default="{row}"><span v-if="row.dimension">{{ $t(row.dimension) }}{{ $t(" 维") }}</span><span v-else-if="row.contextWindow">{{ $t(row.contextWindow.toLocaleString()) }}{{ $t(" 上下文") }}</span><span v-else>{{ $t("由模型服务决定") }}</span></template></el-table-column>
          <el-table-column :label='$t("操作")' width="180"><template #default="{row}"><el-button link @click="test(row)">{{ $t("测试连接") }}</el-button><el-button v-if="['registered','knowledge'].includes(row.source)" link type="danger" @click="remove(row)">{{ $t("删除") }}</el-button><small v-else>{{ $t((row.source === 'builtin' ? $t('部署预置') : $t('原有连接'))) }}</small></template></el-table-column>
        </el-table>
      </el-tab-pane>
      <el-tab-pane :label='$t("默认用途")'>
        <el-form label-position="top" class="uses">
          <el-form-item v-for="use in modelRoles" :key="use.key" :label="$t(use.label)">
            <el-select v-model="uses[use.key]" filterable clearable :value-on-clear="''" :aria-label="$t(use.label) + $t('默认模型')"
              :placeholder="$t(use.key === 'chat' ? (library?.defaultChat || '沿用原有连接') : use.key === 'catalogTranslation' ? '沿用默认文本模型' : '不指定默认模型')">
              <el-option v-for="m in options(use.key)" :key="m.id" :value="m.id" :label="$t(m.name)" />
            </el-select>
            <small>{{ $t(use.hint) }}</small>
          </el-form-item>
          <el-form-item v-if="library?.customerModelIds" :label='$t("信众可选模型")'>
            <el-select v-model="customerModelIds" multiple filterable clearable
              :aria-label='$t("信众可选模型")' :placeholder='$t("沿用原有开放规则")'>
              <el-option v-for="model in options('chat')" :key="model.id" :value="model.id" :label="$t(model.name)" />
            </el-select>
            <small>{{ $t("选中后仅开放这些模型。留空时，OpenCode Go 需设为聊天或图片理解的默认模型才会显示。") }}</small>
          </el-form-item>
        </el-form>
        <el-button type="primary" :disabled="!library?.writable || selection === savedSelection" @click="saveUses">{{ $t(library?.customerModelIds ? "保存用途配置" : "保存默认选择") }}</el-button>
      </el-tab-pane>
    </el-tabs>
    <p class="note">{{ $t("模型需支持对应接口：聊天大模型不能代替 Embedding 或 Rerank。更换向量模型需要新建索引。") }}<router-link to="/ai/connections/legacy">{{ $t("原有连接与运行参数") }}</router-link></p>
    <el-dialog v-model="dialog" :title='$t("添加模型")' width="min(640px,94vw)" append-to-body
      :close-on-click-modal="!busy" :close-on-press-escape="!busy" :show-close="!busy" @closed="form.apiKey = ''">
      <el-form label-position="top" :disabled="busy" v-loading="busy">
        <el-form-item :label='$t("模型类型")'><el-select v-model="form.kind" :aria-label='$t("模型类型")'><el-option :label='$t("大模型 · 聊天 / 文档理解")' value="language" /><el-option :label='$t("Embedding · 建索引")' value="Embedding" /><el-option :label='$t("Rerank · 检索重排")' value="Rerank" /></el-select></el-form-item>
        <template v-if="!isOpenCodeGo">
          <el-form-item :label='$t("显示名称")'><el-input v-model="form.name" maxlength="120" :aria-label='$t("模型显示名称")' /></el-form-item>
          <el-form-item :label='$t("服务商模型 ID / Endpoint ID")'><el-input v-model="form.model" maxlength="100" :aria-label='$t("服务商模型 ID")' :placeholder='$t("例如 ark-code-latest 或 ep-…")' /></el-form-item>
        </template>
        <el-form-item v-if="form.kind === 'language'" :label='$t("复用已保存的连接")'><el-select v-model="form.reuseConnection" filterable clearable :placeholder='$t("新建连接")' :aria-label='$t("复用连接")'><el-option v-for="m in connections" :key="m.id" :value="m.id" :label="$t(((m.name + ' · ') + m.provider))" /></el-select></el-form-item>
        <el-form-item :label="$t(form.kind === 'language' ? '供应商' : '接口协议')">
          <el-select v-model="form.provider" :disabled="!!form.reuseConnection" :aria-label='$t("模型供应商")'>
            <template v-if="form.kind === 'language'">
              <el-option :label='$t("火山引擎 / 方舟")' value="volcengine" /><el-option label="DeepSeek" value="deepseek" />
              <el-option label="OpenCode Go" value="opencode_go" /><el-option :label='$t("OpenAI 兼容")' value="openai_compatible" />
            </template>
            <template v-else><el-option :label='$t("OpenAI 兼容")' value="openai" :disabled="form.kind === 'Rerank'" /><el-option :label='$t("通用 / Jina 重排")' value="generic" /><el-option :label='$t("阿里云")' value="aliyun" /></template>
          </el-select>
        </el-form-item>
        <el-form-item :label='$t("HTTPS 接口地址")'><el-input v-model="form.baseUrl" :disabled="!!form.reuseConnection || isOpenCodeGo" :aria-label='$t("模型接口地址")' /><small v-if="form.provider === 'volcengine'">{{ $t("Agent Plan 使用 https://ark.cn-beijing.volces.com/api/plan/v3") }}</small><small v-else-if="form.kind !== 'language'">{{ $t("使用对应的向量或重排接口；服务域名需在知识引擎的出站许可范围内。") }}</small></el-form-item>
        <el-form-item v-if="!form.reuseConnection" label="API Key">
          <el-input v-model="form.apiKey" type="password" :show-password="!isOpenCodeGo" autocomplete="new-password" :aria-label='$t("模型 API Key")'>
            <template v-if="isOpenCodeGo" #append>
              <el-button :disabled="busy || !form.apiKey.trim()" @click="discoverModels">{{ $t('获取模型列表') }}</el-button>
            </template>
          </el-input>
        </el-form-item>
        <template v-if="isOpenCodeGo">
          <el-form-item :label='$t("服务商模型 ID / Endpoint ID")'>
            <el-select v-model="form.model" filterable :disabled="!discoveredModels.length" :aria-label='$t("服务商模型 ID")'
              :placeholder="$t('从模型列表选择')">
              <el-option v-for="model in discoveredModels" :key="model.id" :value="model.id"
                :label="model.id === model.name ? model.id : model.name + ' · ' + model.id" />
            </el-select>
          </el-form-item>
          <el-form-item :label='$t("显示名称")'><el-input v-model="form.name" maxlength="120" :aria-label='$t("模型显示名称")' /></el-form-item>
        </template>
        <template v-else-if="form.kind === 'language'"><el-form-item :label='$t("图片输入")'><el-switch v-model="form.supportsVision" active-text="支持图片理解" /></el-form-item><div class="capacity"><el-form-item :label='$t("上下文容量（0 为自动）")'><el-input-number v-model="form.contextWindow" :min="0" :max="1048576" :step="32768" /></el-form-item><el-form-item :label='$t("输出上限（0 为自动）")'><el-input-number v-model="form.maxOutputTokens" :min="0" :max="32768" :step="1024" /></el-form-item></div></template>
        <el-form-item v-if="form.kind === 'Embedding'" :label='$t("向量维度")'><el-input-number v-model="form.dimension" :min="1" :max="8192" /></el-form-item>
      </el-form><el-alert v-if="error" :title="$t(error)" type="error" :closable="false" />
      <template #footer><el-button :disabled="busy" @click="dialog = false" data-quiet-action="cancel">{{ $t("取消") }}</el-button><el-button v-if="form.kind === 'language'" :disabled="busy || !canSubmit" @click="probe">{{ $t("测试连接") }}</el-button><el-button type="primary" :loading="busy" :disabled="!canSubmit" @click="saveModel">{{ $t("添加模型") }}</el-button></template>
    </el-dialog>
  </section>
</template>
<style scoped>
.model-library{min-width:0;padding:24px;border: 0;border-radius:12px;background:var(--el-bg-color)}header,.filters,.capacity{display:flex;gap:12px}header{align-items:flex-start;margin-bottom:20px}header>div{flex:1}h2{margin:0 0 8px}p,small{font-size:13px;line-height:1.7;color:var(--el-text-color-secondary)}p{margin:0 0 16px}small{display:block;overflow-wrap:anywhere}.filters{margin:8px 0 18px}.filters .el-input{max-width:440px}.filters .el-select{max-width:240px}.el-tag{margin:3px 6px 3px 0}.el-alert{margin:12px 0}.uses{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px 24px;max-width:900px}.uses .el-form-item{display:block}.note{margin:22px 0 0}.note a{margin-left:12px}.capacity{flex-wrap:wrap}@media(max-width:680px){.model-library{padding:16px}header,.filters{flex-wrap:wrap}header>div{flex-basis:100%}.uses{grid-template-columns:1fr}.filters .el-input,.filters .el-select{max-width:none}}
</style>
